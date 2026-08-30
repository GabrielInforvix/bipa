import { OrigemItem, OrigemProduto, PrismaClient, StatusLista, TipoVenda } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { v7 as uuidv7 } from 'uuid';

const prisma = new PrismaClient();

const id = () => uuidv7();

/** Completa 12 dígitos com o verificador — assim todo EAN do seed é válido
 *  de verdade e o leitor de código de barras aceita. */
function ean13(base12: string): string {
  const d = base12.padStart(12, '0').slice(0, 12).split('').map(Number);
  const soma = d.reduce((acc, n, i) => acc + n * (i % 2 === 0 ? 1 : 3), 0);
  return base12 + String((10 - (soma % 10)) % 10);
}

const CATEGORIAS = [
  { nome: 'Hortifrúti', icone: '🥬' },
  { nome: 'Padaria', icone: '🥖' },
  { nome: 'Açougue', icone: '🥩' },
  { nome: 'Frios e Laticínios', icone: '🧀' },
  { nome: 'Mercearia', icone: '🍚' },
  { nome: 'Bebidas', icone: '🥤' },
  { nome: 'Congelados', icone: '🧊' },
  { nome: 'Limpeza', icone: '🧴' },
  { nome: 'Higiene', icone: '🪥' },
  { nome: 'Outros', icone: '📦' },
];

interface SeedProduto {
  nome: string;
  marca?: string;
  base?: string;
  categoria: string;
  tipoVenda?: TipoVenda;
  preco: number;
}

const PRODUTOS: SeedProduto[] = [
  { nome: 'Arroz branco tipo 1 5kg', marca: 'Tio João', base: '789603609826', categoria: 'Mercearia', preco: 29.9 },
  { nome: 'Feijão carioca 1kg', marca: 'Camil', base: '789004510022', categoria: 'Mercearia', preco: 8.99 },
  { nome: 'Açúcar refinado 1kg', marca: 'União', base: '789101210014', categoria: 'Mercearia', preco: 4.79 },
  { nome: 'Café torrado e moído 500g', marca: 'Pilão', base: '789156100234', categoria: 'Mercearia', preco: 21.9 },
  { nome: 'Óleo de soja 900ml', marca: 'Liza', base: '789200300145', categoria: 'Mercearia', preco: 7.49 },
  { nome: 'Macarrão espaguete 500g', marca: 'Renata', base: '789030410088', categoria: 'Mercearia', preco: 4.29 },
  { nome: 'Molho de tomate 340g', marca: 'Quero', base: '789031200567', categoria: 'Mercearia', preco: 3.19 },
  { nome: 'Sal refinado 1kg', marca: 'Cisne', base: '789060700123', categoria: 'Mercearia', preco: 2.79 },
  { nome: 'Leite integral 1L', marca: 'Italac', base: '789123456789', categoria: 'Frios e Laticínios', preco: 5.99 },
  { nome: 'Queijo mussarela fatiado', marca: 'Tirolez', categoria: 'Frios e Laticínios', tipoVenda: TipoVenda.PESO, preco: 49.9 },
  { nome: 'Manteiga com sal 200g', marca: 'Aviação', base: '789040100256', categoria: 'Frios e Laticínios', preco: 14.9 },
  { nome: 'Iogurte natural 170g', marca: 'Vigor', base: '789045600789', categoria: 'Frios e Laticínios', preco: 3.49 },
  { nome: 'Banana prata', categoria: 'Hortifrúti', tipoVenda: TipoVenda.PESO, preco: 7.9 },
  { nome: 'Tomate italiano', categoria: 'Hortifrúti', tipoVenda: TipoVenda.PESO, preco: 9.49 },
  { nome: 'Batata inglesa', categoria: 'Hortifrúti', tipoVenda: TipoVenda.PESO, preco: 5.99 },
  { nome: 'Cebola branca', categoria: 'Hortifrúti', tipoVenda: TipoVenda.PESO, preco: 6.49 },
  { nome: 'Alface crespa', categoria: 'Hortifrúti', preco: 3.99 },
  { nome: 'Patinho bovino', categoria: 'Açougue', tipoVenda: TipoVenda.PESO, preco: 34.9 },
  { nome: 'Peito de frango', categoria: 'Açougue', tipoVenda: TipoVenda.PESO, preco: 18.9 },
  { nome: 'Linguiça toscana', categoria: 'Açougue', tipoVenda: TipoVenda.PESO, preco: 22.9 },
  { nome: 'Pão francês', categoria: 'Padaria', tipoVenda: TipoVenda.PESO, preco: 16.9 },
  { nome: 'Pão de forma integral 450g', marca: 'Pullman', base: '789007800334', categoria: 'Padaria', preco: 9.9 },
  { nome: 'Refrigerante cola 2L', marca: 'Coca-Cola', base: '789489300121', categoria: 'Bebidas', preco: 9.49 },
  { nome: 'Suco de laranja 1L', marca: 'Del Valle', base: '789489301234', categoria: 'Bebidas', preco: 8.79 },
  { nome: 'Água mineral 1,5L', marca: 'Crystal', base: '789489302345', categoria: 'Bebidas', preco: 3.29 },
  { nome: 'Detergente neutro 500ml', marca: 'Ypê', base: '789162700456', categoria: 'Limpeza', preco: 2.59 },
  { nome: 'Sabão em pó 1,6kg', marca: 'Omo', base: '789132400567', categoria: 'Limpeza', preco: 24.9 },
  { nome: 'Amaciante 2L', marca: 'Downy', base: '789132401678', categoria: 'Limpeza', preco: 18.9 },
  { nome: 'Papel higiênico 12 rolos', marca: 'Neve', base: '789132402789', categoria: 'Higiene', preco: 27.9 },
  { nome: 'Creme dental 90g', marca: 'Colgate', base: '789020800890', categoria: 'Higiene', preco: 6.49 },
  { nome: 'Sabonete 85g', marca: 'Dove', base: '789132403890', categoria: 'Higiene', preco: 4.29 },
  { nome: 'Chocolate ao leite 90g', marca: 'Lacta', base: '762221056789', categoria: 'Outros', preco: 7.49 },
  { nome: 'Biscoito água e sal 200g', marca: 'Piraquê', base: '789802439051', categoria: 'Mercearia', preco: 5.29 },
];

async function main() {
  console.log('Semeando o banco do Bipa...');

  const email = 'gabriel@bipa.local';
  const usuarioId = id();
  const usuario = await prisma.usuario.upsert({
    where: { email },
    update: {},
    create: {
      id: usuarioId,
      nome: 'Gabriel',
      email,
      senhaHash: await bcrypt.hash('bipa123', 10),
      perfil: 'ADMIN',
    },
  });

  // Recomeça do zero para o seed poder rodar quantas vezes for preciso.
  await prisma.historicoPreco.deleteMany({ where: { usuarioId: usuario.id } });
  await prisma.listaItem.deleteMany({ where: { lista: { usuarioId: usuario.id } } });
  await prisma.lista.deleteMany({ where: { usuarioId: usuario.id } });
  await prisma.operacaoSincronizacao.deleteMany({ where: { usuarioId: usuario.id } });

  // ── Categorias ─────────────────────────────────────────────────────
  const categorias = new Map<string, string>();
  for (const [ordem, c] of CATEGORIAS.entries()) {
    const existente = await prisma.categoria.findFirst({
      where: { usuarioId: usuario.id, nome: c.nome },
    });
    const cat =
      existente ??
      (await prisma.categoria.create({
        data: { id: id(), nome: c.nome, icone: c.icone, ordem, usuarioId: usuario.id },
      }));
    categorias.set(c.nome, cat.id);
  }

  // ── Mercados ───────────────────────────────────────────────────────
  const mercados = new Map<string, string>();
  for (const nome of ['Atacadão', 'Pão de Açúcar', 'Mercado do bairro']) {
    const existente = await prisma.mercado.findFirst({
      where: { usuarioId: usuario.id, nome },
    });
    const m =
      existente ??
      (await prisma.mercado.create({
        data: { id: id(), usuarioId: usuario.id, nome, cidade: 'São Paulo' },
      }));
    mercados.set(nome, m.id);
  }

  // ── Catálogo ───────────────────────────────────────────────────────
  const produtos = new Map<string, { id: string; preco: number; tipoVenda: TipoVenda }>();
  for (const p of PRODUTOS) {
    const ean = p.base ? ean13(p.base) : null;
    const existente = ean
      ? await prisma.produto.findUnique({ where: { ean } })
      : await prisma.produto.findFirst({ where: { nome: p.nome, ean: null } });

    const produto =
      existente ??
      (await prisma.produto.create({
        data: {
          id: id(),
          ean,
          nome: p.nome,
          marca: p.marca,
          tipoVenda: p.tipoVenda ?? TipoVenda.UNIDADE,
          unidade: p.tipoVenda === TipoVenda.PESO ? 'kg' : 'un',
          categoriaId: categorias.get(p.categoria),
          origem: OrigemProduto.CATALOGO,
          confirmacoes: 3,
          criadoPorId: usuario.id,
        },
      }));
    produtos.set(p.nome, {
      id: produto.id,
      preco: p.preco,
      tipoVenda: p.tipoVenda ?? TipoVenda.UNIDADE,
    });
  }

  const pega = (nome: string) => {
    const p = produtos.get(nome);
    if (!p) throw new Error(`Produto ausente no seed: ${nome}`);
    return p;
  };

  // ── Histórico de preços do arroz (alimenta o gráfico da tela) ───────
  const arroz = pega('Arroz branco tipo 1 5kg');
  const serie: Array<[string, number, string]> = [
    ['2026-03-28', 32.9, 'Pão de Açúcar'],
    ['2026-04-25', 31.9, 'Pão de Açúcar'],
    ['2026-05-29', 30.5, 'Atacadão'],
    ['2026-06-27', 27.9, 'Atacadão'],
    ['2026-07-31', 31.9, 'Pão de Açúcar'],
  ];
  for (const [data, preco, mercado] of serie) {
    await prisma.historicoPreco.create({
      data: {
        id: id(),
        usuarioId: usuario.id,
        produtoId: arroz.id,
        mercadoId: mercados.get(mercado),
        preco,
        quantidade: 1,
        total: preco,
        data: new Date(data),
      },
    });
  }

  // ── Compra finalizada de julho ─────────────────────────────────────
  const julhoId = id();
  await prisma.lista.create({
    data: {
      id: julhoId,
      usuarioId: usuario.id,
      nome: 'Compras do mês · julho',
      data: new Date('2026-07-31'),
      orcamento: 400,
      mercadoId: mercados.get('Atacadão'),
      status: StatusLista.FINALIZADA,
      finalizadaEm: new Date('2026-07-31T11:07:00'),
    },
  });

  const comprasJulho: Array<[string, number, number]> = [
    ['Feijão carioca 1kg', 2, 8.79],
    ['Açúcar refinado 1kg', 2, 4.69],
    ['Café torrado e moído 500g', 1, 21.5],
    ['Leite integral 1L', 6, 5.79],
    ['Óleo de soja 900ml', 2, 7.29],
    ['Detergente neutro 500ml', 4, 2.49],
    ['Papel higiênico 12 rolos', 1, 26.9],
    ['Banana prata', 1.2, 7.5],
    ['Patinho bovino', 1.1, 33.9],
  ];
  for (const [ordem, [nome, qtd, preco]] of comprasJulho.entries()) {
    const p = pega(nome);
    const itemId = id();
    const total = Math.round(qtd * preco * 100) / 100;
    await prisma.listaItem.create({
      data: {
        id: itemId,
        listaId: julhoId,
        produtoId: p.id,
        ordem,
        unidade: p.tipoVenda === TipoVenda.PESO ? 'kg' : 'un',
        quantidadePlanejada: qtd,
        precoEstimado: p.preco,
        comprado: true,
        quantidade: qtd,
        precoUnitario: preco,
        total,
        compradoEm: new Date('2026-07-31T10:40:00'),
      },
    });
    await prisma.historicoPreco.create({
      data: {
        id: id(),
        usuarioId: usuario.id,
        produtoId: p.id,
        mercadoId: mercados.get('Atacadão'),
        listaItemId: itemId,
        preco,
        quantidade: qtd,
        total,
        data: new Date('2026-07-31'),
      },
    });
  }

  // ── Compra em andamento (é o estado que a tela de início mostra) ────
  const agostoId = id();
  await prisma.lista.create({
    data: {
      id: agostoId,
      usuarioId: usuario.id,
      nome: 'Compras do mês',
      data: new Date('2026-08-28'),
      orcamento: 400,
      mercadoId: mercados.get('Atacadão'),
      status: StatusLista.EM_COMPRA,
    },
  });

  // [nome, quantidade planejada, já comprado?, preço pago]
  const itensAgosto: Array<[string, number, boolean, number?]> = [
    ['Arroz branco tipo 1 5kg', 1, true, 27.8],
    ['Leite integral 1L', 3, true, 5.99],
    ['Feijão carioca 1kg', 2, true, 8.49],
    ['Banana prata', 1.3, true, 7.9],
    ['Patinho bovino', 1.238, true, 34.9],
    ['Açúcar refinado 1kg', 2, false],
    ['Café torrado e moído 500g', 1, false],
    ['Óleo de soja 900ml', 2, false],
    ['Macarrão espaguete 500g', 3, false],
    ['Molho de tomate 340g', 4, false],
    ['Tomate italiano', 1, false],
    ['Batata inglesa', 2, false],
    ['Peito de frango', 1.5, false],
    ['Queijo mussarela fatiado', 0.3, false],
    ['Pão de forma integral 450g', 1, false],
    ['Refrigerante cola 2L', 2, false],
    ['Detergente neutro 500ml', 4, false],
    ['Sabão em pó 1,6kg', 1, false],
    ['Papel higiênico 12 rolos', 1, false],
    ['Creme dental 90g', 3, false],
  ];

  for (const [ordem, [nome, qtd, comprado, precoPago]] of itensAgosto.entries()) {
    const p = pega(nome);
    const preco = precoPago ?? null;
    await prisma.listaItem.create({
      data: {
        id: id(),
        listaId: agostoId,
        produtoId: p.id,
        ordem,
        unidade: p.tipoVenda === TipoVenda.PESO ? 'kg' : 'un',
        quantidadePlanejada: qtd,
        precoEstimado: p.preco,
        comprado,
        quantidade: comprado ? qtd : null,
        precoUnitario: preco,
        total: comprado && preco ? Math.round(qtd * preco * 100) / 100 : null,
        compradoEm: comprado ? new Date('2026-08-28T10:20:00') : null,
      },
    });
  }

  // Compra extra: entra no total geral, mas separada no resumo (regra 12).
  const chocolate = pega('Chocolate ao leite 90g');
  await prisma.listaItem.create({
    data: {
      id: id(),
      listaId: agostoId,
      produtoId: chocolate.id,
      ordem: 100,
      origem: OrigemItem.EXTRA,
      quantidadePlanejada: 1,
      comprado: true,
      quantidade: 2,
      precoUnitario: 7.49,
      total: 14.98,
      compradoEm: new Date('2026-08-28T10:21:00'),
    },
  });

  console.log(`OK. Usuário: ${email} / bipa123`);
  console.log(`     ${PRODUTOS.length} produtos, ${CATEGORIAS.length} categorias, 3 mercados`);
  console.log(`     1 compra finalizada (julho) e 1 em andamento (agosto)`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
