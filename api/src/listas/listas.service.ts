import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { OrigemItem, Prisma, StatusLista, TipoVenda } from '@prisma/client';
import { novoId } from '../comum/ids';
import { PrismaService } from '../prisma/prisma.service';
import { CreateItemDto } from './dto/create-item.dto';
import { CreateListaDto } from './dto/create-lista.dto';
import { UpdateItemDto } from './dto/update-item.dto';
import { UpdateListaDto } from './dto/update-lista.dto';

const INCLUDE_ITENS = {
  itens: {
    where: { excluidoEm: null },
    orderBy: [{ ordem: 'asc' }, { criadoEm: 'asc' }],
    include: {
      produto: { select: { id: true, nome: true, marca: true, ean: true, imagemUrl: true, tipoVenda: true } },
      categoria: { select: { id: true, nome: true, icone: true, ordem: true } },
    },
  },
  mercado: { select: { id: true, nome: true } },
} satisfies Prisma.ListaInclude;

export interface TotaisLista {
  totalPago: number;
  totalEstimado: number;
  economia: number;
  totalPlanejados: number;
  totalExtras: number;
  itensComprados: number;
  itensPendentes: number;
  itensExtras: number;
  orcamento: number | null;
  saldoOrcamento: number | null;
}

@Injectable()
export class ListasService {
  constructor(private readonly prisma: PrismaService) {}

  async listar(usuarioId: string, status?: StatusLista) {
    const listas = await this.prisma.lista.findMany({
      where: { usuarioId, excluidoEm: null, status },
      include: INCLUDE_ITENS,
      orderBy: [{ data: 'desc' }, { criadoEm: 'desc' }],
    });
    return listas.map((l) => this.comTotais(l));
  }

  async porId(usuarioId: string, id: string) {
    const lista = await this.prisma.lista.findFirst({
      where: { id, usuarioId, excluidoEm: null },
      include: INCLUDE_ITENS,
    });
    if (!lista) throw new NotFoundException('Lista não encontrada.');
    return this.comTotais(lista);
  }

  async criar(usuarioId: string, dto: CreateListaDto) {
    const id = dto.id ?? novoId();
    await this.prisma.lista.create({
      data: {
        id,
        usuarioId,
        nome: dto.nome.trim(),
        data: dto.data ? new Date(dto.data) : new Date(),
        observacao: dto.observacao,
        orcamento: dto.orcamento,
        mercadoId: dto.mercadoId,
      },
    });

    if (dto.copiarDeListaId) {
      await this.copiarItens(usuarioId, dto.copiarDeListaId, id);
    }
    return this.porId(usuarioId, id);
  }

  async atualizar(usuarioId: string, id: string, dto: UpdateListaDto) {
    await this.exigir(usuarioId, id);
    await this.prisma.lista.update({
      where: { id },
      data: {
        nome: dto.nome?.trim(),
        data: dto.data ? new Date(dto.data) : undefined,
        observacao: dto.observacao,
        orcamento: dto.orcamento,
        mercadoId: dto.mercadoId,
        status: dto.status,
      },
    });
    return this.porId(usuarioId, id);
  }

  /** Exclusão lógica (tombstone): sem isso a lista apagada offline
   *  ressuscitaria na próxima sincronização. */
  async remover(usuarioId: string, id: string) {
    await this.exigir(usuarioId, id);
    const agora = new Date();
    await this.prisma.$transaction([
      this.prisma.lista.update({
        where: { id },
        data: { excluidoEm: agora },
      }),
      this.prisma.listaItem.updateMany({
        where: { listaId: id, excluidoEm: null },
        data: { excluidoEm: agora },
      }),
    ]);
    return { ok: true };
  }

  // ── Itens ──────────────────────────────────────────────────────────

  async adicionarItem(usuarioId: string, listaId: string, dto: CreateItemDto) {
    await this.exigir(usuarioId, listaId);
    if (!dto.produtoId && !dto.nomeLivre?.trim()) {
      throw new BadRequestException('Informe o produto ou um nome para o item.');
    }

    const ultimo = await this.prisma.listaItem.findFirst({
      where: { listaId },
      orderBy: { ordem: 'desc' },
      select: { ordem: true },
    });

    await this.prisma.listaItem.create({
      data: {
        id: dto.id ?? novoId(),
        listaId,
        produtoId: dto.produtoId,
        nomeLivre: dto.nomeLivre?.trim(),
        categoriaId: dto.categoriaId,
        origem: dto.origem ?? OrigemItem.PLANEJADO,
        unidade: dto.unidade ?? (dto.tipoVenda === TipoVenda.PESO ? 'kg' : 'un'),
        ordem: dto.ordem ?? (ultimo ? ultimo.ordem + 1 : 0),
        quantidadePlanejada: dto.quantidadePlanejada ?? 1,
        precoEstimado: dto.precoEstimado,
        ...this.camposDeCompra(dto),
      },
    });
    return this.porId(usuarioId, listaId);
  }

  async atualizarItem(
    usuarioId: string,
    listaId: string,
    itemId: string,
    dto: UpdateItemDto,
  ) {
    await this.exigir(usuarioId, listaId);
    const item = await this.prisma.listaItem.findFirst({
      where: { id: itemId, listaId, excluidoEm: null },
    });
    if (!item) throw new NotFoundException('Item não encontrado.');

    await this.prisma.listaItem.update({
      where: { id: itemId },
      data: {
        produtoId: dto.produtoId,
        nomeLivre: dto.nomeLivre?.trim(),
        categoriaId: dto.categoriaId,
        origem: dto.origem,
        unidade: dto.unidade,
        ordem: dto.ordem,
        quantidadePlanejada: dto.quantidadePlanejada,
        precoEstimado: dto.precoEstimado,
        observacao: dto.observacao,
        ...this.camposDeCompra(dto, item),
      },
    });
    return this.porId(usuarioId, listaId);
  }

  async removerItem(usuarioId: string, listaId: string, itemId: string) {
    await this.exigir(usuarioId, listaId);
    const item = await this.prisma.listaItem.findFirst({
      where: { id: itemId, listaId },
    });
    if (!item) throw new NotFoundException('Item não encontrado.');
    await this.prisma.listaItem.update({
      where: { id: itemId },
      data: { excluidoEm: new Date() },
    });
    return this.porId(usuarioId, listaId);
  }

  // ── Ciclo da compra ────────────────────────────────────────────────

  async iniciarCompra(usuarioId: string, id: string) {
    await this.exigir(usuarioId, id);
    await this.prisma.lista.update({
      where: { id },
      data: { status: StatusLista.EM_COMPRA },
    });
    return this.porId(usuarioId, id);
  }

  /**
   * Fecha a compra e grava o histórico de preços.
   *
   * O upsert por `listaItemId` é o que torna a operação idempotente: se o app
   * reenviar a finalização porque a resposta se perdeu no caminho, o histórico
   * não duplica nem distorce a média do produto.
   */
  async finalizar(usuarioId: string, id: string) {
    const lista = await this.prisma.lista.findFirst({
      where: { id, usuarioId, excluidoEm: null },
      include: { itens: { where: { excluidoEm: null, comprado: true } } },
    });
    if (!lista) throw new NotFoundException('Lista não encontrada.');

    // flatMap em vez de filter: o filter não estreita o tipo, e aqui os três
    // campos precisam chegar não-nulos no histórico.
    const registraveis = lista.itens.flatMap((i) =>
      i.produtoId && i.precoUnitario != null && i.quantidade != null
        ? [
            {
              id: i.id,
              produtoId: i.produtoId,
              precoUnitario: i.precoUnitario,
              quantidade: i.quantidade,
              total: i.total,
            },
          ]
        : [],
    );

    await this.prisma.$transaction([
      ...registraveis.map((item) =>
        this.prisma.historicoPreco.upsert({
          where: { listaItemId: item.id },
          create: {
            id: novoId(),
            usuarioId,
            produtoId: item.produtoId,
            mercadoId: lista.mercadoId,
            listaItemId: item.id,
            preco: item.precoUnitario,
            quantidade: item.quantidade,
            total: item.total ?? 0,
            data: lista.data,
          },
          update: {
            mercadoId: lista.mercadoId,
            preco: item.precoUnitario,
            quantidade: item.quantidade,
            total: item.total ?? 0,
            data: lista.data,
          },
        }),
      ),
      this.prisma.lista.update({
        where: { id },
        data: { status: StatusLista.FINALIZADA, finalizadaEm: new Date() },
      }),
    ]);

    return this.porId(usuarioId, id);
  }

  /**
   * Repetir lista: cria uma nova com os mesmos produtos. Quantidades e preços
   * da compra anterior NÃO viram valores atuais — o preço pago antes entra
   * apenas como estimativa de referência.
   */
  async repetir(usuarioId: string, id: string, nome?: string) {
    const origem = await this.exigir(usuarioId, id);
    const novaId = novoId();
    await this.prisma.lista.create({
      data: {
        id: novaId,
        usuarioId,
        nome: nome?.trim() || `${origem.nome} (novo)`,
        data: new Date(),
        orcamento: origem.orcamento,
        mercadoId: origem.mercadoId,
      },
    });
    await this.copiarItens(usuarioId, id, novaId);
    return this.porId(usuarioId, novaId);
  }

  // ── Internos ───────────────────────────────────────────────────────

  /** Copia os itens planejados, usando o preço pago antes como referência. */
  private async copiarItens(usuarioId: string, deId: string, paraId: string) {
    const origem = await this.prisma.lista.findFirst({
      where: { id: deId, usuarioId, excluidoEm: null },
      include: { itens: { where: { excluidoEm: null }, orderBy: { ordem: 'asc' } } },
    });
    if (!origem) throw new NotFoundException('Lista de origem não encontrada.');

    const itens = origem.itens.map((item, i) => ({
      id: novoId(),
      listaId: paraId,
      produtoId: item.produtoId,
      nomeLivre: item.nomeLivre,
      categoriaId: item.categoriaId,
      // Compra extra da lista anterior entra como item planejado na nova:
      // se foi comprado de novo, já era parte da rotina.
      origem: OrigemItem.PLANEJADO,
      unidade: item.unidade,
      ordem: i,
      quantidadePlanejada: item.quantidadePlanejada,
      // Só o preço vira referência. Quantidade e preço pagos ficam para trás.
      precoEstimado: item.precoUnitario ?? item.precoEstimado,
    }));

    if (itens.length > 0) {
      await this.prisma.listaItem.createMany({ data: itens });
    }
  }

  /**
   * Total do item = quantidade × preço unitário, calculado no servidor.
   * Regra 6/7: o valor fica congelado no item; mexer no produto depois nunca
   * altera uma compra já feita.
   */
  private camposDeCompra(
    dto: CreateItemDto | UpdateItemDto,
    atual?: { quantidade: Prisma.Decimal | null; precoUnitario: Prisma.Decimal | null },
  ) {
    if (
      dto.comprado === undefined &&
      dto.quantidade === undefined &&
      dto.precoUnitario === undefined
    ) {
      return {};
    }

    // Desmarcar como comprado limpa os valores realizados — senão o total
    // continuaria somando um item que não está mais no carrinho.
    if (dto.comprado === false) {
      return {
        comprado: false,
        quantidade: null,
        precoUnitario: null,
        total: null,
        compradoEm: null,
      };
    }

    const quantidade =
      dto.quantidade ?? (atual?.quantidade ? Number(atual.quantidade) : null);
    const preco =
      dto.precoUnitario ??
      (atual?.precoUnitario ? Number(atual.precoUnitario) : null);
    const comprado = dto.comprado ?? (quantidade != null && preco != null);

    return {
      comprado,
      quantidade,
      precoUnitario: preco,
      total:
        quantidade != null && preco != null
          ? Math.round(quantidade * preco * 100) / 100
          : null,
      compradoEm: comprado ? new Date() : null,
    };
  }

  /** Totais da compra. Planejados e extras somam junto no total geral, mas
   *  aparecem separados — é o número que revela o impulso (regra 12). */
  private comTotais(
    lista: Prisma.ListaGetPayload<{ include: typeof INCLUDE_ITENS }>,
  ) {
    let totalPlanejados = 0;
    let totalExtras = 0;
    let totalEstimado = 0;
    let itensComprados = 0;
    let itensPendentes = 0;
    let itensExtras = 0;

    for (const item of lista.itens) {
      const total = item.total ? Number(item.total) : 0;
      const estimado =
        Number(item.precoEstimado ?? 0) * Number(item.quantidadePlanejada ?? 1);

      if (item.origem === OrigemItem.EXTRA) {
        itensExtras += 1;
        totalExtras += total;
      } else {
        totalEstimado += estimado;
        if (item.comprado) totalPlanejados += total;
      }

      if (item.comprado) itensComprados += 1;
      else if (item.origem !== OrigemItem.EXTRA) itensPendentes += 1;
    }

    const totalPago = arredondar(totalPlanejados + totalExtras);
    const orcamento = lista.orcamento ? Number(lista.orcamento) : null;

    const totais: TotaisLista = {
      totalPago,
      totalEstimado: arredondar(totalEstimado),
      // Comparação só faz sentido sobre o que já foi comprado — economia
      // calculada contra a lista inteira mentiria no meio da compra.
      economia: arredondar(this.estimadoDosComprados(lista) - totalPlanejados),
      totalPlanejados: arredondar(totalPlanejados),
      totalExtras: arredondar(totalExtras),
      itensComprados,
      itensPendentes,
      itensExtras,
      orcamento,
      saldoOrcamento: orcamento != null ? arredondar(orcamento - totalPago) : null,
    };

    return { ...lista, totais };
  }

  private estimadoDosComprados(
    lista: Prisma.ListaGetPayload<{ include: typeof INCLUDE_ITENS }>,
  ) {
    return lista.itens
      .filter((i) => i.comprado && i.origem !== OrigemItem.EXTRA)
      .reduce(
        (soma, i) =>
          soma +
          Number(i.precoEstimado ?? 0) * Number(i.quantidade ?? i.quantidadePlanejada ?? 1),
        0,
      );
  }

  private async exigir(usuarioId: string, id: string) {
    const lista = await this.prisma.lista.findFirst({
      where: { id, usuarioId, excluidoEm: null },
    });
    if (!lista) throw new NotFoundException('Lista não encontrada.');
    return lista;
  }
}

function arredondar(valor: number) {
  return Math.round(valor * 100) / 100;
}
