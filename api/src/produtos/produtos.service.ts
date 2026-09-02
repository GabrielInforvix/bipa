import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { OrigemProduto, Prisma, TipoVenda } from '@prisma/client';
import { minhaLista } from '../comum/acesso';
import { novoId } from '../comum/ids';
import { PrismaService } from '../prisma/prisma.service';
import {
  EtiquetaBalanca,
  FormatoBalanca,
  LayoutBalanca,
  ehEtiquetaBalanca,
  lerEtiquetaBalanca,
  normalizarEan,
} from './balanca.util';
import { CATALOGOS_EXTERNOS, CatalogoExterno } from './externo/catalogo-externo';
import { CreateProdutoDto } from './dto/create-produto.dto';
import { UpdateProdutoDto } from './dto/update-produto.dto';

/** Como o produto foi resolvido — o app usa isso para decidir qual tela abrir. */
export type OrigemBusca =
  | 'CATALOGO'
  | 'BALANCA'
  | 'EXTERNO'
  | 'NAO_ENCONTRADO';

export interface ResultadoBusca {
  origem: OrigemBusca;
  produto: unknown | null;
  /** Preenchido só quando o código é etiqueta de balança. */
  etiqueta?: EtiquetaBalanca;
  /** Último preço pago pelo usuário — é a sugestão de um toque no scanner. */
  ultimoPreco?: number | null;
}

@Injectable()
export class ProdutosService {
  private readonly formatoBalanca: FormatoBalanca;
  private readonly layoutBalanca: LayoutBalanca;

  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
    @Inject(CATALOGOS_EXTERNOS)
    private readonly catalogos: CatalogoExterno[],
  ) {
    this.formatoBalanca = this.config.get<FormatoBalanca>(
      'BALANCA_FORMATO',
      'PRECO',
    );
    this.layoutBalanca = this.config.get<LayoutBalanca>(
      'BALANCA_LAYOUT',
      'C6V5',
    );
  }

  /**
   * Cascata de resolução de um código bipado:
   *   1. catálogo (global + personalização do usuário)
   *   2. etiqueta de balança, decodificada localmente
   *   3. fontes externas (Open Food Facts)
   *   4. nada — o app abre o cadastro rápido
   *
   * A ordem não é arbitrária: o passo 1 é instantâneo e cobre o caso comum
   * (o usuário compra as mesmas coisas todo mês), enquanto o passo 3 custa
   * uma ida à rede e falha com frequência para EAN brasileiro.
   */
  async buscarPorEan(usuarioId: string, eanBruto: string): Promise<ResultadoBusca> {
    const ean = normalizarEan(eanBruto);

    const local = await this.prisma.produto.findUnique({
      where: { ean },
      include: { categoria: true },
    });
    if (local) {
      return {
        origem: 'CATALOGO',
        produto: await this.comPersonalizacao(usuarioId, local),
        ultimoPreco: await this.ultimoPreco(usuarioId, local.id),
      };
    }

    // Balança antes do externo: nenhuma API do mundo conhece o código
    // interno de uma loja, então consultar a rede aqui é tempo jogado fora.
    if (ehEtiquetaBalanca(ean)) {
      const etiqueta = lerEtiquetaBalanca(
        ean,
        this.formatoBalanca,
        this.layoutBalanca,
      );
      if (etiqueta) {
        const conhecido = await this.prisma.produto.findFirst({
          where: {
            ean: { endsWith: etiqueta.codigoInterno },
            tipoVenda: TipoVenda.PESO,
          },
          include: { categoria: true },
        });
        return {
          origem: 'BALANCA',
          produto: conhecido
            ? await this.comPersonalizacao(usuarioId, conhecido)
            : null,
          etiqueta,
          ultimoPreco: conhecido
            ? await this.ultimoPreco(usuarioId, conhecido.id)
            : null,
        };
      }
    }

    for (const catalogo of this.catalogos) {
      const externo = await catalogo.buscarPorEan(ean);
      if (!externo) continue;

      // Cadastro vindo de fonte externa entra no catálogo global na hora:
      // a próxima pessoa que bipar esse código não paga a ida à rede.
      const criado = await this.prisma.produto.create({
        data: {
          id: novoId(),
          ean,
          nome: externo.nome,
          marca: externo.marca,
          imagemUrl: externo.imagemUrl,
          tipoVenda: externo.tipoVenda ?? TipoVenda.UNIDADE,
          origem: OrigemProduto.OPEN_FOOD_FACTS,
          criadoPorId: usuarioId,
        },
        include: { categoria: true },
      });
      return {
        origem: 'EXTERNO',
        produto: await this.comPersonalizacao(usuarioId, criado),
        ultimoPreco: null,
      };
    }

    return { origem: 'NAO_ENCONTRADO', produto: null, ultimoPreco: null };
  }

  /** Busca por texto — em casa é assim que a lista é montada, não bipando. */
  async listar(usuarioId: string, termo?: string, limite = 40) {
    const where: Prisma.ProdutoWhereInput = { ativo: true };
    if (termo?.trim()) {
      where.OR = [
        { nome: { contains: termo.trim(), mode: 'insensitive' } },
        { marca: { contains: termo.trim(), mode: 'insensitive' } },
        { ean: { startsWith: normalizarEan(termo) || undefined } },
      ];
    }

    const produtos = await this.prisma.produto.findMany({
      where,
      include: { categoria: true },
      orderBy: [{ confirmacoes: 'desc' }, { nome: 'asc' }],
      take: Math.min(limite, 100),
    });
    return Promise.all(
      produtos.map((p) => this.comPersonalizacao(usuarioId, p)),
    );
  }

  async porId(usuarioId: string, id: string) {
    const produto = await this.prisma.produto.findUnique({
      where: { id },
      include: { categoria: true },
    });
    if (!produto) throw new NotFoundException('Produto não encontrado.');
    return this.comPersonalizacao(usuarioId, produto);
  }

  /**
   * Cadastro manual. Regra 9: um mesmo EAN nunca gera produto duplicado —
   * se o código já existe, o cadastro vira uma confirmação do que está lá.
   * Regra 10: produto sem código de barras é permitido.
   */
  async criar(usuarioId: string, dto: CreateProdutoDto) {
    const ean = dto.ean ? normalizarEan(dto.ean) : null;

    if (ean) {
      const existente = await this.prisma.produto.findUnique({ where: { ean } });
      if (existente) {
        const atualizado = await this.prisma.produto.update({
          where: { id: existente.id },
          data: { confirmacoes: { increment: 1 } },
          include: { categoria: true },
        });
        await this.personalizar(usuarioId, atualizado.id, dto);
        return this.comPersonalizacao(usuarioId, atualizado);
      }
    }

    const produto = await this.prisma.produto.create({
      data: {
        id: dto.id ?? novoId(),
        ean,
        nome: dto.nome.trim(),
        marca: dto.marca?.trim(),
        tipoVenda: dto.tipoVenda ?? TipoVenda.UNIDADE,
        unidade: dto.unidade ?? (dto.tipoVenda === TipoVenda.PESO ? 'kg' : 'un'),
        categoriaId: dto.categoriaId,
        origem: ean ? OrigemProduto.MANUAL : OrigemProduto.MANUAL,
        criadoPorId: usuarioId,
      },
      include: { categoria: true },
    });
    return this.comPersonalizacao(usuarioId, produto);
  }

  /** Só quem criou (ou um admin) edita o produto global; os demais
   *  personalizam a própria cópia, sem mexer no catálogo de todo mundo. */
  async atualizar(usuarioId: string, id: string, dto: UpdateProdutoDto) {
    const produto = await this.prisma.produto.findUnique({ where: { id } });
    if (!produto) throw new NotFoundException('Produto não encontrado.');

    if (produto.criadoPorId === usuarioId) {
      const atualizado = await this.prisma.produto.update({
        where: { id },
        data: {
          nome: dto.nome?.trim(),
          marca: dto.marca?.trim(),
          tipoVenda: dto.tipoVenda,
          unidade: dto.unidade,
          categoriaId: dto.categoriaId,
        },
        include: { categoria: true },
      });
      return this.comPersonalizacao(usuarioId, atualizado);
    }

    await this.personalizar(usuarioId, id, dto);
    return this.porId(usuarioId, id);
  }

  /** Histórico de preços do produto, com as estatísticas da tela. */
  async historicoPrecos(usuarioId: string, produtoId: string) {
    const registros = await this.prisma.historicoPreco.findMany({
      // A memoria de precos e da casa: o que alguem pagou numa lista de que
      // voce participa vira sugestao no SEU teclado (decisao aprovada).
      where: {
        produtoId,
        OR: [
          { usuarioId },
          { listaItem: { lista: minhaLista(usuarioId) } },
        ],
      },
      include: { mercado: { select: { id: true, nome: true } } },
      orderBy: { data: 'desc' },
      take: 60,
    });

    if (registros.length === 0) {
      return { registros: [], ultimo: null, menor: null, maior: null, medio: null };
    }

    const precos = registros.map((r) => Number(r.preco));
    const soma = precos.reduce((a, b) => a + b, 0);
    return {
      registros,
      ultimo: precos[0],
      menor: Math.min(...precos),
      maior: Math.max(...precos),
      medio: Math.round((soma / precos.length) * 100) / 100,
    };
  }

  /** Último preço pago pelo usuário — vira a sugestão de um toque no scanner. */
  async ultimoPreco(usuarioId: string, produtoId: string) {
    const ultimo = await this.prisma.historicoPreco.findFirst({
      where: {
        produtoId,
        OR: [
          { usuarioId },
          { listaItem: { lista: minhaLista(usuarioId) } },
        ],
      },
      orderBy: { data: 'desc' },
      select: { preco: true },
    });
    return ultimo ? Number(ultimo.preco) : null;
  }

  /** Aplica o apelido/categoria do usuário por cima do produto global. */
  private async comPersonalizacao(
    usuarioId: string,
    produto: Prisma.ProdutoGetPayload<{ include: { categoria: true } }>,
  ) {
    const meu = await this.prisma.produtoUsuario.findUnique({
      where: { usuarioId_produtoId: { usuarioId, produtoId: produto.id } },
      include: { categoria: true },
    });
    return {
      ...produto,
      nome: meu?.apelido ?? produto.nome,
      nomeCatalogo: produto.nome,
      unidade: meu?.unidadePreferida ?? produto.unidade,
      categoriaId: meu?.categoriaId ?? produto.categoriaId,
      categoria: meu?.categoria ?? produto.categoria,
      favorito: meu?.favorito ?? false,
    };
  }

  private async personalizar(
    usuarioId: string,
    produtoId: string,
    dto: UpdateProdutoDto,
  ) {
    if (!dto.apelido && !dto.categoriaId && !dto.unidade) return;
    await this.prisma.produtoUsuario.upsert({
      where: { usuarioId_produtoId: { usuarioId, produtoId } },
      create: {
        id: novoId(),
        usuarioId,
        produtoId,
        apelido: dto.apelido?.trim(),
        categoriaId: dto.categoriaId,
        unidadePreferida: dto.unidade,
      },
      update: {
        apelido: dto.apelido?.trim(),
        categoriaId: dto.categoriaId,
        unidadePreferida: dto.unidade,
      },
    });
  }
}
