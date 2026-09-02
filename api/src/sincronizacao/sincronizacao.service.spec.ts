import { PrismaClient, StatusLista } from '@prisma/client';
import { config as carregarEnv } from 'dotenv';
import { v7 as uuidv7 } from 'uuid';
import { PrismaService } from '../prisma/prisma.service';
import { OperacaoDto } from './dto/sincronizar.dto';
import { SincronizacaoService } from './sincronizacao.service';

carregarEnv();

/**
 * Testes de integração da sincronização, contra Postgres de verdade.
 *
 * São de integração de propósito: o que pode dar errado aqui é justamente a
 * conversa com o banco — upsert, constraint de unicidade, `atualizadoEm`
 * gerado pelo servidor. Um mock do Prisma testaria só o meu raciocínio sobre
 * o banco, que é exatamente a parte que eu poderia errar.
 *
 * Roda contra `DATABASE_URL_TEST` (banco `mercado_test`). **Esses testes
 * apagam dados** — nunca aponte para o banco de desenvolvimento.
 */
const urlTeste =
  process.env.DATABASE_URL_TEST ??
  process.env.DATABASE_URL?.replace(/\/mercado(\?|$)/, '/mercado_test$1');

const prisma = new PrismaClient({
  datasources: { db: { url: urlTeste } },
});
const servico = new SincronizacaoService(prisma as unknown as PrismaService);

const id = () => uuidv7();
const USUARIO = id();
const OUTRO_USUARIO = id();

/** Monta uma operação da fila do app. */
function op(
  entidade: OperacaoDto['entidade'],
  entidadeId: string,
  acao: OperacaoDto['acao'],
  dados: Record<string, unknown> = {},
  ocorridoEm = '2026-08-28T12:00:00.000Z',
): OperacaoDto {
  return { id: id(), entidade, entidadeId, acao, ocorridoEm, dados };
}

describe('SincronizacaoService (integração)', () => {
  beforeAll(async () => {
    await prisma.$connect();
    for (const usuarioId of [USUARIO, OUTRO_USUARIO]) {
      await prisma.usuario.upsert({
        where: { id: usuarioId },
        update: {},
        create: {
          id: usuarioId,
          nome: 'Teste',
          email: `${usuarioId}@teste.local`,
          senhaHash: 'x',
        },
      });
    }
  });

  afterAll(async () => {
    await prisma.usuario.deleteMany({
      where: { id: { in: [USUARIO, OUTRO_USUARIO] } },
    });
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    // Cascata a partir do usuário limparia tudo, mas apagar só os dados
    // mantém os usuários entre os testes.
    await prisma.operacaoSincronizacao.deleteMany({
      where: { usuarioId: { in: [USUARIO, OUTRO_USUARIO] } },
    });
    await prisma.listaMembro.deleteMany({
      where: { usuarioId: { in: [USUARIO, OUTRO_USUARIO] } },
    });
    await prisma.listaItem.deleteMany({
      where: { lista: { usuarioId: { in: [USUARIO, OUTRO_USUARIO] } } },
    });
    await prisma.lista.deleteMany({
      where: { usuarioId: { in: [USUARIO, OUTRO_USUARIO] } },
    });
    await prisma.produto.deleteMany({ where: { criadoPorId: USUARIO } });
    await prisma.categoria.deleteMany({ where: { usuarioId: USUARIO } });
  });

  // ── Idempotência ───────────────────────────────────────────────────

  describe('idempotência', () => {
    it('reenviar o mesmo lote não duplica nada', async () => {
      const listaId = id();
      const lote = {
        operacoes: [
          op('lista', listaId, 'criar', { nome: 'Compras', data: '2026-08-28' }),
        ],
      };

      const primeira = await servico.sincronizar(USUARIO, lote);
      expect(primeira.aplicadas).toHaveLength(1);
      expect(primeira.ignoradas).toHaveLength(0);

      // A resposta se perdeu no caminho e o app reenviou a MESMA fila.
      const segunda = await servico.sincronizar(USUARIO, lote);
      expect(segunda.aplicadas).toHaveLength(0);
      expect(segunda.ignoradas).toHaveLength(1);

      const listas = await prisma.lista.findMany({
        where: { usuarioId: USUARIO },
      });
      expect(listas).toHaveLength(1);
    });

    it('uma operação inválida não derruba as outras do lote', async () => {
      const listaId = id();
      const resultado = await servico.sincronizar(USUARIO, {
        operacoes: [
          op('lista', listaId, 'criar', { nome: 'Boa', data: '2026-08-28' }),
          // Item apontando para uma lista que não existe.
          op('lista_item', id(), 'criar', { listaId: id(), nomeLivre: 'Órfão' }),
          op('lista_item', id(), 'criar', {
            listaId,
            nomeLivre: 'Pão',
            quantidadePlanejada: 2,
          }),
        ],
      });

      expect(resultado.aplicadas).toHaveLength(2);
      expect(resultado.falhas).toHaveLength(1);

      const itens = await prisma.listaItem.findMany({ where: { listaId } });
      expect(itens).toHaveLength(1);
      expect(itens[0].nomeLivre).toBe('Pão');
    });

    it('marca como permanente a falha que nunca vai dar certo', async () => {
      // Item órfão não passa a existir por insistência. Se o servidor não
      // dissesse isso, o app reenviaria a operação em toda sincronização e o
      // contador de pendentes nunca zeraria.
      const orfa = op('lista_item', id(), 'criar', {
        listaId: id(),
        nomeLivre: 'Órfão',
      });
      const primeira = await servico.sincronizar(USUARIO, { operacoes: [orfa] });
      expect(primeira.falhas[0].permanente).toBe(true);

      // E, tendo sido registrada, o reenvio nem tenta de novo.
      const segunda = await servico.sincronizar(USUARIO, { operacoes: [orfa] });
      expect(segunda.falhas).toHaveLength(0);
      expect(segunda.ignoradas).toContain(orfa.id);
    });

    it('falha passageira continua na fila para nova tentativa', async () => {
      // Data inválida faz o Postgres recusar — mas é erro de conteúdo, não
      // estrutural: não pode ser marcado como permanente.
      const resultado = await servico.sincronizar(USUARIO, {
        operacoes: [
          op('lista', id(), 'criar', { nome: 'X', data: 'data-que-nao-existe' }),
        ],
      });
      if (resultado.falhas.length > 0) {
        expect(resultado.falhas[0].permanente).toBe(false);
      }
    });
  });

  // ── Conflito ───────────────────────────────────────────────────────

  describe('resolução de conflito', () => {
    it('descarta alteração mais antiga que a versão do servidor', async () => {
      const listaId = id();
      await prisma.lista.create({
        data: {
          id: listaId,
          usuarioId: USUARIO,
          nome: 'Nome do servidor',
          data: new Date('2026-08-28'),
        },
      });

      // Alteração feita no aparelho ANTES do que já está no servidor.
      await servico.sincronizar(USUARIO, {
        operacoes: [
          op('lista', listaId, 'atualizar', { nome: 'Nome antigo' }, '2020-01-01T00:00:00.000Z'),
        ],
      });

      const lista = await prisma.lista.findUnique({ where: { id: listaId } });
      expect(lista!.nome).toBe('Nome do servidor');
    });

    it('aceita alteração mais nova que a versão do servidor', async () => {
      const listaId = id();
      await prisma.lista.create({
        data: {
          id: listaId,
          usuarioId: USUARIO,
          nome: 'Antigo',
          data: new Date('2026-08-28'),
        },
      });

      await servico.sincronizar(USUARIO, {
        operacoes: [
          op('lista', listaId, 'atualizar', { nome: 'Novo' }, '2099-01-01T00:00:00.000Z'),
        ],
      });

      const lista = await prisma.lista.findUnique({ where: { id: listaId } });
      expect(lista!.nome).toBe('Novo');
    });

    it('COMPRADO VENCE não-comprado, mesmo com o servidor mais novo', async () => {
      // É a única mesclagem especial do sistema. Perder um item já colocado no
      // carrinho faria o usuário passar no caixa com o total errado — por isso
      // a compra vence a regra do último-a-escrever.
      const listaId = id();
      const itemId = id();
      await prisma.lista.create({
        data: {
          id: listaId,
          usuarioId: USUARIO,
          nome: 'Compras',
          data: new Date('2026-08-28'),
        },
      });
      await prisma.listaItem.create({
        data: { id: itemId, listaId, nomeLivre: 'Arroz', comprado: false },
      });

      await servico.sincronizar(USUARIO, {
        operacoes: [
          op(
            'lista_item',
            itemId,
            'atualizar',
            { comprado: true, quantidade: 2, precoUnitario: 5.5 },
            '2020-01-01T00:00:00.000Z', // bem mais antigo que o servidor
          ),
        ],
      });

      const item = await prisma.listaItem.findUnique({ where: { id: itemId } });
      expect(item!.comprado).toBe(true);
      expect(Number(item!.total)).toBe(11);
    });

    it('não ressuscita item desmarcado quando a alteração é velha', async () => {
      const listaId = id();
      const itemId = id();
      await prisma.lista.create({
        data: {
          id: listaId,
          usuarioId: USUARIO,
          nome: 'Compras',
          data: new Date('2026-08-28'),
        },
      });
      await prisma.listaItem.create({
        data: { id: itemId, listaId, nomeLivre: 'Arroz', comprado: true },
      });

      // Desmarcar é alteração comum: perde para o servidor mais novo.
      await servico.sincronizar(USUARIO, {
        operacoes: [
          op('lista_item', itemId, 'atualizar', { comprado: false }, '2020-01-01T00:00:00.000Z'),
        ],
      });

      const item = await prisma.listaItem.findUnique({ where: { id: itemId } });
      expect(item!.comprado).toBe(true);
    });
  });

  // ── Exclusão ───────────────────────────────────────────────────────

  describe('exclusão', () => {
    it('excluir a lista marca o tombstone e leva os itens junto', async () => {
      const listaId = id();
      const itemId = id();
      await prisma.lista.create({
        data: {
          id: listaId,
          usuarioId: USUARIO,
          nome: 'Some',
          data: new Date('2026-08-28'),
        },
      });
      await prisma.listaItem.create({
        data: { id: itemId, listaId, nomeLivre: 'Item' },
      });

      await servico.sincronizar(USUARIO, {
        operacoes: [op('lista', listaId, 'excluir')],
      });

      const lista = await prisma.lista.findUnique({ where: { id: listaId } });
      const item = await prisma.listaItem.findUnique({ where: { id: itemId } });
      expect(lista!.excluidoEm).not.toBeNull();
      expect(item!.excluidoEm).not.toBeNull();
    });

    it('o tombstone volta no delta, para o outro aparelho apagar também', async () => {
      const listaId = id();
      await prisma.lista.create({
        data: {
          id: listaId,
          usuarioId: USUARIO,
          nome: 'Some',
          data: new Date('2026-08-28'),
        },
      });
      await servico.sincronizar(USUARIO, {
        operacoes: [op('lista', listaId, 'excluir')],
      });

      const delta = await servico.puxar(USUARIO);
      const encontrada = (delta.listas as Array<{ id: string; excluidoEm: Date }>)
        .find((l) => l.id === listaId);
      expect(encontrada?.excluidoEm).not.toBeNull();
    });
  });

  // ── Isolamento entre usuários ──────────────────────────────────────

  describe('isolamento', () => {
    it('não deixa alterar lista de outro usuário', async () => {
      const listaId = id();
      await prisma.lista.create({
        data: {
          id: listaId,
          usuarioId: OUTRO_USUARIO,
          nome: 'Do vizinho',
          data: new Date('2026-08-28'),
        },
      });

      await servico.sincronizar(USUARIO, {
        operacoes: [
          op('lista', listaId, 'atualizar', { nome: 'Invadida' }, '2099-01-01T00:00:00.000Z'),
        ],
      });

      const resultado = await servico.sincronizar(USUARIO, {
        operacoes: [
          op('lista', listaId, 'criar', { nome: 'Roubada', data: '2026-08-28' }),
        ],
      });
      // Recusa explícita, não um acidente da chave primária.
      expect(resultado.falhas[0].permanente).toBe(true);
      expect(resultado.falhas[0].motivo).toMatch(/outro usuário/);

      const lista = await prisma.lista.findUnique({ where: { id: listaId } });
      expect(lista!.nome).toBe('Do vizinho');
      expect(lista!.usuarioId).toBe(OUTRO_USUARIO);
    });

    it('o delta não vaza dados de outro usuário', async () => {
      await prisma.lista.create({
        data: {
          id: id(),
          usuarioId: OUTRO_USUARIO,
          nome: 'Do vizinho',
          data: new Date('2026-08-28'),
        },
      });

      const delta = await servico.puxar(USUARIO);
      expect(delta.listas).toHaveLength(0);
    });
  });

  // ── Delta ──────────────────────────────────────────────────────────

  describe('delta por cursor', () => {
    it('traz só o que mudou depois do cursor', async () => {
      await prisma.lista.create({
        data: {
          id: id(),
          usuarioId: USUARIO,
          nome: 'Antiga',
          data: new Date('2026-08-28'),
        },
      });

      const cursor = new Date().toISOString();
      // Espera um instante para o `atualizadoEm` da próxima ficar depois do cursor.
      await new Promise((r) => setTimeout(r, 25));

      await prisma.lista.create({
        data: {
          id: id(),
          usuarioId: USUARIO,
          nome: 'Nova',
          data: new Date('2026-08-28'),
        },
      });

      const delta = await servico.puxar(USUARIO, cursor);
      expect(delta.listas).toHaveLength(1);
      expect((delta.listas[0] as { nome: string }).nome).toBe('Nova');
    });

    it('sem cursor traz tudo (primeira sincronização)', async () => {
      await prisma.lista.create({
        data: {
          id: id(),
          usuarioId: USUARIO,
          nome: 'Uma',
          data: new Date('2026-08-28'),
        },
      });
      const delta = await servico.puxar(USUARIO);
      expect(delta.listas).toHaveLength(1);
    });
  });

  // ── Lista compartilhada ────────────────────────────────────────────

  describe('lista compartilhada', () => {
    /** DONO cria a lista; OUTRO_USUARIO entra como membro. */
    async function listaComMembro() {
      const listaId = id();
      await prisma.lista.create({
        data: {
          id: listaId,
          usuarioId: USUARIO,
          nome: 'Da casa',
          data: new Date('2026-09-01'),
        },
      });
      await prisma.listaMembro.create({
        data: { id: id(), listaId, usuarioId: OUTRO_USUARIO },
      });
      return listaId;
    }

    it('membro sincroniza item na lista do dono', async () => {
      const listaId = await listaComMembro();
      const itemId = id();

      const resultado = await servico.sincronizar(OUTRO_USUARIO, {
        operacoes: [
          op('lista_item', itemId, 'criar', {
            listaId,
            nomeLivre: 'Café',
            comprado: true,
            quantidade: 1,
            precoUnitario: 21.9,
          }),
        ],
      });
      expect(resultado.falhas).toHaveLength(0);

      const item = await prisma.listaItem.findUnique({ where: { id: itemId } });
      // A inicial ao lado do item: quem criou e comprou foi o membro.
      expect(item!.criadoPorId).toBe(OUTRO_USUARIO);
      expect(item!.compradoPorId).toBe(OUTRO_USUARIO);
    });

    it('o delta do membro traz a lista da família, com as pessoas', async () => {
      const listaId = await listaComMembro();
      const delta = await servico.puxar(OUTRO_USUARIO);
      const lista = (delta.listas as Array<any>).find((l) => l.id === listaId);
      expect(lista).toBeDefined();
      expect(lista.usuario.nome).toBe('Teste'); // dono viaja junto
      expect(lista.membros).toHaveLength(1);
    });

    it('quem NÃO é membro continua barrado', async () => {
      const listaId = id();
      await prisma.lista.create({
        data: {
          id: listaId,
          usuarioId: USUARIO,
          nome: 'Só minha',
          data: new Date('2026-09-01'),
        },
      });

      const resultado = await servico.sincronizar(OUTRO_USUARIO, {
        operacoes: [
          op('lista_item', id(), 'criar', { listaId, nomeLivre: 'Invasão' }),
        ],
      });
      expect(resultado.falhas[0].permanente).toBe(true);

      const delta = await servico.puxar(OUTRO_USUARIO);
      expect(
        (delta.listas as Array<any>).find((l) => l.id === listaId),
      ).toBeUndefined();
    });

    it('excluir vindo de MEMBRO vira sair — a lista da família sobrevive', async () => {
      const listaId = await listaComMembro();

      await servico.sincronizar(OUTRO_USUARIO, {
        operacoes: [op('lista', listaId, 'excluir')],
      });

      const lista = await prisma.lista.findUnique({ where: { id: listaId } });
      expect(lista!.excluidoEm).toBeNull(); // ninguém perdeu a lista
      const membros = await prisma.listaMembro.findMany({ where: { listaId } });
      expect(membros).toHaveLength(0); // mas o membro saiu
    });

    it('comprado-vence continua valendo entre pessoas diferentes', async () => {
      const listaId = await listaComMembro();
      const itemId = id();
      await prisma.listaItem.create({
        data: { id: itemId, listaId, nomeLivre: 'Arroz', comprado: false },
      });

      // O membro comprou, mas a operação chegou "velha".
      await servico.sincronizar(OUTRO_USUARIO, {
        operacoes: [
          op(
            'lista_item',
            itemId,
            'atualizar',
            { comprado: true, quantidade: 1, precoUnitario: 27.8 },
            '2020-01-01T00:00:00.000Z',
          ),
        ],
      });

      const item = await prisma.listaItem.findUnique({ where: { id: itemId } });
      expect(item!.comprado).toBe(true);
      expect(item!.compradoPorId).toBe(OUTRO_USUARIO);
    });
  });

  // ── Catálogo ───────────────────────────────────────────────────────

  describe('produto', () => {
    it('EAN já existente vira confirmação, não produto duplicado', async () => {
      const ean = '7896036098264';
      await prisma.produto.create({
        data: { id: id(), ean, nome: 'Arroz', criadoPorId: USUARIO },
      });

      await servico.sincronizar(USUARIO, {
        operacoes: [
          op('produto', id(), 'criar', { ean, nome: 'Arroz de outro jeito' }),
        ],
      });

      const produtos = await prisma.produto.findMany({ where: { ean } });
      expect(produtos).toHaveLength(1);
      expect(produtos[0].nome).toBe('Arroz'); // o cadastro alheio não é sobrescrito
      expect(produtos[0].confirmacoes).toBe(1);
    });

    it('produto sem EAN é aceito (regra 10)', async () => {
      const produtoId = id();
      await servico.sincronizar(USUARIO, {
        operacoes: [op('produto', produtoId, 'criar', { nome: 'Pão na padaria' })],
      });

      const produto = await prisma.produto.findUnique({
        where: { id: produtoId },
      });
      expect(produto?.nome).toBe('Pão na padaria');
      expect(produto?.ean).toBeNull();
    });
  });

  // ── Cenário completo ───────────────────────────────────────────────

  it('uma compra inteira feita offline sobe de uma vez', async () => {
    const listaId = id();
    const itens = [
      { id: id(), nome: 'Arroz', qtd: 1, preco: 27.8 },
      { id: id(), nome: 'Leite', qtd: 3, preco: 5.99 },
      { id: id(), nome: 'Patinho', qtd: 1.238, preco: 34.9 },
    ];

    const resultado = await servico.sincronizar(USUARIO, {
      operacoes: [
        op('lista', listaId, 'criar', {
          nome: 'Compras do mês',
          data: '2026-08-28',
          orcamento: 400,
          status: StatusLista.EM_COMPRA,
        }),
        ...itens.map((i) =>
          op('lista_item', i.id, 'criar', {
            listaId,
            nomeLivre: i.nome,
            quantidadePlanejada: i.qtd,
            comprado: true,
            quantidade: i.qtd,
            precoUnitario: i.preco,
          }),
        ),
      ],
    });

    expect(resultado.falhas).toHaveLength(0);
    expect(resultado.aplicadas).toHaveLength(4);

    const gravados = await prisma.listaItem.findMany({ where: { listaId } });
    const total = gravados.reduce((s, i) => s + Number(i.total), 0);
    // 27,80 + 17,97 + 43,21 (1,238 kg x 34,90 arredondado) = 88,98
    expect(Number(total.toFixed(2))).toBe(88.98);

    // E o delta já devolve tudo para o aparelho na mesma viagem.
    expect(resultado.alteracoes.listas).toHaveLength(1);
    expect(resultado.alteracoes.itens).toHaveLength(3);
  });
});
