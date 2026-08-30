import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { OperacaoDto, SincronizarDto } from './dto/sincronizar.dto';

/** Operação que nunca vai dar certo por mais que se tente: aponta para algo
 *  que não existe, ou para dado de outro usuário. O app precisa saber a
 *  diferença — senão essas operações voltam para a fila a cada sincronização
 *  e o contador de pendentes nunca zera. */
export class FalhaPermanente extends Error {}

export interface ResultadoSincronizacao {
  aplicadas: string[];
  ignoradas: string[];
  falhas: Array<{ id: string; motivo: string; permanente: boolean }>;
  /** Relógio do servidor no fim do lote — vira o cursor do próximo pull. */
  servidorEm: string;
  alteracoes: Alteracoes;
}

export interface Alteracoes {
  listas: unknown[];
  itens: unknown[];
  produtos: unknown[];
  categorias: unknown[];
  mercados: unknown[];
}

/**
 * Sincronização offline-first.
 *
 * Três garantias sustentam tudo:
 *
 * 1. **Idempotência.** Cada operação carrega um id gerado no aparelho e fica
 *    registrada em `operacoes_sincronizacao`. Se a resposta se perder e o app
 *    reenviar o lote, a operação repetida é ignorada em vez de duplicar dados.
 *
 * 2. **Último a escrever vence, por registro.** Se o servidor já tem uma versão
 *    mais nova que a alteração que chegou, a alteração é descartada — exceto
 *    pela regra de mesclagem abaixo.
 *
 * 3. **Comprado vence não-comprado.** É a única mesclagem especial, e existe
 *    porque perder um item já colocado no carrinho é o pior erro possível
 *    para o usuário: ele passaria no caixa com o total errado.
 */
@Injectable()
export class SincronizacaoService {
  private readonly log = new Logger(SincronizacaoService.name);

  constructor(private readonly prisma: PrismaService) {}

  async sincronizar(
    usuarioId: string,
    dto: SincronizarDto,
  ): Promise<ResultadoSincronizacao> {
    const aplicadas: string[] = [];
    const ignoradas: string[] = [];
    const falhas: Array<{ id: string; motivo: string; permanente: boolean }> =
      [];

    // Uma consulta só para saber o que já foi aplicado antes.
    const jaAplicadas = await this.prisma.operacaoSincronizacao.findMany({
      where: { usuarioId, id: { in: dto.operacoes.map((o) => o.id) } },
      select: { id: true },
    });
    const conhecidas = new Set(jaAplicadas.map((o) => o.id));

    // Ordem cronológica: criar a lista antes dos itens dela.
    const pendentes = dto.operacoes
      .filter((o) => !conhecidas.has(o.id))
      .sort((a, b) => a.ocorridoEm.localeCompare(b.ocorridoEm));

    for (const op of dto.operacoes) {
      if (conhecidas.has(op.id)) ignoradas.push(op.id);
    }

    for (const op of pendentes) {
      try {
        await this.aplicar(usuarioId, op);
        await this.prisma.operacaoSincronizacao.create({
          data: {
            id: op.id,
            usuarioId,
            entidade: op.entidade,
            entidadeId: op.entidadeId,
            acao: op.acao,
          },
        });
        aplicadas.push(op.id);
      } catch (erro) {
        // Uma operação inválida não pode travar a fila inteira: o app
        // precisa conseguir enviar as outras 7 alterações da compra.
        const motivo = (erro as Error).message ?? 'Falha ao aplicar';
        const permanente = erro instanceof FalhaPermanente;
        this.log.warn(
          `Operação ${op.id} (${op.entidade}) falhou${permanente ? ' de vez' : ''}: ${motivo}`,
        );
        falhas.push({ id: op.id, motivo, permanente });

        // Falha permanente também vira registro: reenviar não muda o
        // resultado, e sem isso o app tentaria para sempre.
        if (permanente) {
          await this.prisma.operacaoSincronizacao.create({
            data: {
              id: op.id,
              usuarioId,
              entidade: op.entidade,
              entidadeId: op.entidadeId,
              acao: `${op.acao}:recusada`,
            },
          });
        }
      }
    }

    const servidorEm = new Date();
    return {
      aplicadas,
      ignoradas,
      falhas,
      servidorEm: servidorEm.toISOString(),
      alteracoes: await this.puxar(usuarioId, dto.desde),
    };
  }

  /** Delta por cursor. Traz também os tombstones, senão o registro apagado
   *  em outro aparelho continuaria vivo neste. */
  async puxar(usuarioId: string, desde?: string): Promise<Alteracoes> {
    const corte = desde ? new Date(desde) : undefined;
    const depois = corte ? { gt: corte } : undefined;

    const [listas, itens, categorias, mercados, produtosUsuario] =
      await Promise.all([
        this.prisma.lista.findMany({
          where: { usuarioId, atualizadoEm: depois },
          orderBy: { atualizadoEm: 'asc' },
        }),
        this.prisma.listaItem.findMany({
          where: { lista: { usuarioId }, atualizadoEm: depois },
          orderBy: { atualizadoEm: 'asc' },
        }),
        this.prisma.categoria.findMany({
          where: { usuarioId, atualizadoEm: depois },
          orderBy: { atualizadoEm: 'asc' },
        }),
        this.prisma.mercado.findMany({
          where: { usuarioId, atualizadoEm: depois },
          orderBy: { atualizadoEm: 'asc' },
        }),
        // Do catálogo global só interessam os produtos que este usuário
        // realmente usa — baixar o catálogo inteiro seria desperdício.
        this.prisma.produto.findMany({
          where: {
            atualizadoEm: depois,
            OR: [
              { criadoPorId: usuarioId },
              { produtosUsuario: { some: { usuarioId } } },
              { itens: { some: { lista: { usuarioId } } } },
            ],
          },
          orderBy: { atualizadoEm: 'asc' },
          take: 500,
        }),
      ]);

    return {
      listas,
      itens,
      produtos: produtosUsuario,
      categorias,
      mercados,
    };
  }

  // ── Aplicação de uma operação ──────────────────────────────────────

  private async aplicar(usuarioId: string, op: OperacaoDto) {
    const ocorridoEm = new Date(op.ocorridoEm);
    switch (op.entidade) {
      case 'lista':
        return this.aplicarLista(usuarioId, op, ocorridoEm);
      case 'lista_item':
        return this.aplicarItem(usuarioId, op, ocorridoEm);
      case 'categoria':
        return this.aplicarCategoria(usuarioId, op, ocorridoEm);
      case 'mercado':
        return this.aplicarMercado(usuarioId, op, ocorridoEm);
      case 'produto':
        return this.aplicarProduto(usuarioId, op);
    }
  }

  private async aplicarLista(
    usuarioId: string,
    op: OperacaoDto,
    ocorridoEm: Date,
  ) {
    const atual = await this.prisma.lista.findFirst({
      where: { id: op.entidadeId, usuarioId },
    });

    if (op.acao === 'excluir') {
      if (!atual) return;
      await this.prisma.lista.update({
        where: { id: atual.id },
        data: { excluidoEm: ocorridoEm },
      });
      await this.prisma.listaItem.updateMany({
        where: { listaId: atual.id, excluidoEm: null },
        data: { excluidoEm: ocorridoEm },
      });
      return;
    }

    const d = op.dados ?? {};
    const dados = {
      nome: texto(d.nome),
      data: data(d.data),
      observacao: texto(d.observacao),
      orcamento: decimal(d.orcamento),
      mercadoId: uuid(d.mercadoId),
      status: texto(d.status) as never,
      finalizadaEm: data(d.finalizadaEm),
    };

    if (!atual) {
      // O id pode existir e ser de outra pessoa. Sem esta checagem a criação
      // seria barrada pela chave primária — o dado ficaria seguro, mas por
      // acidente, e com uma mensagem que não explica nada.
      await this.recusarSePertenceAOutro('lista', op.entidadeId);

      await this.prisma.lista.create({
        data: {
          id: op.entidadeId,
          usuarioId,
          nome: dados.nome ?? 'Lista',
          data: dados.data ?? ocorridoEm,
          observacao: dados.observacao,
          orcamento: dados.orcamento,
          mercadoId: dados.mercadoId,
          status: dados.status,
          finalizadaEm: dados.finalizadaEm,
        },
      });
      return;
    }

    if (atual.atualizadoEm > ocorridoEm) return; // servidor está mais novo
    await this.prisma.lista.update({
      where: { id: atual.id },
      data: limpar(dados),
    });
  }

  private async aplicarItem(
    usuarioId: string,
    op: OperacaoDto,
    ocorridoEm: Date,
  ) {
    const atual = await this.prisma.listaItem.findFirst({
      where: { id: op.entidadeId, lista: { usuarioId } },
    });

    if (op.acao === 'excluir') {
      if (!atual) return;
      await this.prisma.listaItem.update({
        where: { id: atual.id },
        data: { excluidoEm: ocorridoEm },
      });
      return;
    }

    const d = op.dados ?? {};
    const quantidade = decimal(d.quantidade);
    const precoUnitario = decimal(d.precoUnitario);
    const comprado = booleano(d.comprado);

    const dados = {
      produtoId: uuid(d.produtoId),
      nomeLivre: texto(d.nomeLivre),
      categoriaId: uuid(d.categoriaId),
      origem: texto(d.origem) as never,
      unidade: texto(d.unidade),
      ordem: inteiro(d.ordem),
      quantidadePlanejada: decimal(d.quantidadePlanejada),
      precoEstimado: decimal(d.precoEstimado),
      comprado,
      quantidade,
      precoUnitario,
      total:
        quantidade != null && precoUnitario != null
          ? Math.round(quantidade * precoUnitario * 100) / 100
          : undefined,
      compradoEm: comprado ? (data(d.compradoEm) ?? ocorridoEm) : undefined,
      observacao: texto(d.observacao),
    };

    if (!atual) {
      const listaId = uuid(d.listaId);
      if (!listaId) {
        throw new FalhaPermanente('Item sem lista de origem.');
      }
      const lista = await this.prisma.lista.findFirst({
        where: { id: listaId, usuarioId },
      });
      if (!lista) {
        throw new FalhaPermanente('Lista do item não existe neste usuário.');
      }
      await this.recusarSePertenceAOutro('lista_item', op.entidadeId);

      await this.prisma.listaItem.create({
        data: {
          id: op.entidadeId,
          listaId,
          produtoId: dados.produtoId,
          nomeLivre: dados.nomeLivre,
          categoriaId: dados.categoriaId,
          origem: dados.origem,
          unidade: dados.unidade ?? 'un',
          ordem: dados.ordem ?? 0,
          quantidadePlanejada: dados.quantidadePlanejada ?? 1,
          precoEstimado: dados.precoEstimado,
          comprado: dados.comprado ?? false,
          quantidade: dados.quantidade,
          precoUnitario: dados.precoUnitario,
          total: dados.total,
          compradoEm: dados.compradoEm,
          observacao: dados.observacao,
        },
      });
      return;
    }

    if (atual.atualizadoEm > ocorridoEm) {
      // O servidor está mais novo — mas se lá o item ainda não estava
      // comprado e aqui está, a compra vence. Perder um item já no carrinho
      // faria o usuário passar no caixa com o total errado.
      if (comprado === true && !atual.comprado) {
        await this.prisma.listaItem.update({
          where: { id: atual.id },
          data: limpar({
            comprado: true,
            quantidade: dados.quantidade,
            precoUnitario: dados.precoUnitario,
            total: dados.total,
            compradoEm: dados.compradoEm,
          }),
        });
      }
      return;
    }

    await this.prisma.listaItem.update({
      where: { id: atual.id },
      data: limpar(dados),
    });
  }

  private async aplicarCategoria(
    usuarioId: string,
    op: OperacaoDto,
    ocorridoEm: Date,
  ) {
    const d = op.dados ?? {};
    const atual = await this.prisma.categoria.findFirst({
      where: { id: op.entidadeId, usuarioId },
    });

    if (op.acao === 'excluir') {
      if (atual) {
        await this.prisma.categoria.update({
          where: { id: atual.id },
          data: { ativo: false },
        });
      }
      return;
    }

    if (!atual) {
      await this.prisma.categoria.create({
        data: {
          id: op.entidadeId,
          usuarioId,
          nome: texto(d.nome) ?? 'Categoria',
          icone: texto(d.icone),
          ordem: inteiro(d.ordem) ?? 0,
        },
      });
      return;
    }
    if (atual.atualizadoEm > ocorridoEm) return;
    await this.prisma.categoria.update({
      where: { id: atual.id },
      data: limpar({
        nome: texto(d.nome),
        icone: texto(d.icone),
        ordem: inteiro(d.ordem),
        ativo: booleano(d.ativo),
      }),
    });
  }

  private async aplicarMercado(
    usuarioId: string,
    op: OperacaoDto,
    ocorridoEm: Date,
  ) {
    const d = op.dados ?? {};
    const atual = await this.prisma.mercado.findFirst({
      where: { id: op.entidadeId, usuarioId },
    });

    if (op.acao === 'excluir') {
      if (atual) {
        await this.prisma.mercado.update({
          where: { id: atual.id },
          data: { ativo: false },
        });
      }
      return;
    }

    if (!atual) {
      await this.prisma.mercado.create({
        data: {
          id: op.entidadeId,
          usuarioId,
          nome: texto(d.nome) ?? 'Mercado',
          cidade: texto(d.cidade),
        },
      });
      return;
    }
    if (atual.atualizadoEm > ocorridoEm) return;
    await this.prisma.mercado.update({
      where: { id: atual.id },
      data: limpar({ nome: texto(d.nome), cidade: texto(d.cidade) }),
    });
  }

  /** Produto é catálogo global: a sincronização só acrescenta, nunca sobrescreve
   *  o cadastro de outra pessoa. Regra 9: um EAN não vira produto duplicado. */
  private async aplicarProduto(usuarioId: string, op: OperacaoDto) {
    if (op.acao === 'excluir') return;

    const d = op.dados ?? {};
    const ean = texto(d.ean)?.replace(/\D/g, '') || null;

    if (ean) {
      const porEan = await this.prisma.produto.findUnique({ where: { ean } });
      if (porEan) {
        await this.prisma.produto.update({
          where: { id: porEan.id },
          data: { confirmacoes: { increment: 1 } },
        });
        return;
      }
    }

    const existente = await this.prisma.produto.findUnique({
      where: { id: op.entidadeId },
    });
    if (existente) return;

    await this.prisma.produto.create({
      data: {
        id: op.entidadeId,
        ean,
        nome: texto(d.nome) ?? 'Produto',
        marca: texto(d.marca),
        tipoVenda: (texto(d.tipoVenda) as never) ?? undefined,
        unidade: texto(d.unidade) ?? 'un',
        categoriaId: uuid(d.categoriaId),
        origem: 'MANUAL',
        criadoPorId: usuarioId,
      },
    });
  }

  /** Recusa a operação quando o id já existe e é de outra pessoa. */
  private async recusarSePertenceAOutro(
    entidade: 'lista' | 'lista_item',
    entidadeId: string,
  ) {
    const existe =
      entidade === 'lista'
        ? await this.prisma.lista.findUnique({ where: { id: entidadeId } })
        : await this.prisma.listaItem.findUnique({ where: { id: entidadeId } });
    if (existe) {
      throw new FalhaPermanente('Este registro pertence a outro usuário.');
    }
  }
}

// ── Conversores tolerantes ────────────────────────────────────────────
// O app manda JSON; nada aqui pode explodir por causa de um campo ausente.

function texto(v: unknown): string | undefined {
  if (v === null) return null as never;
  return typeof v === 'string' && v.length > 0 ? v : undefined;
}

function uuid(v: unknown): string | undefined {
  return typeof v === 'string' && v.length === 36 ? v : undefined;
}

function decimal(v: unknown): number | undefined {
  if (v === null) return null as never;
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string' && v.trim() !== '') {
    const n = Number(v);
    return Number.isFinite(n) ? n : undefined;
  }
  return undefined;
}

function inteiro(v: unknown): number | undefined {
  const n = decimal(v);
  return n == null ? undefined : Math.trunc(n);
}

function booleano(v: unknown): boolean | undefined {
  return typeof v === 'boolean' ? v : undefined;
}

function data(v: unknown): Date | undefined {
  if (typeof v !== 'string' || !v) return undefined;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? undefined : d;
}

/** Remove os `undefined` para não sobrescrever campo que o app não mandou. */
function limpar<T extends Record<string, unknown>>(obj: T): Prisma.InputJsonObject {
  return Object.fromEntries(
    Object.entries(obj).filter(([, v]) => v !== undefined),
  ) as Prisma.InputJsonObject;
}
