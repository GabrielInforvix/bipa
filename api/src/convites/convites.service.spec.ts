import { PrismaClient } from '@prisma/client';
import { config as carregarEnv } from 'dotenv';
import { v7 as uuidv7 } from 'uuid';
import { PrismaService } from '../prisma/prisma.service';
import { ConvitesService } from './convites.service';

carregarEnv();

/**
 * Integração dos convites, contra Postgres de verdade (`mercado_test`).
 * **Apaga dados** — nunca aponte para o banco de desenvolvimento.
 */
const urlTeste =
  process.env.DATABASE_URL_TEST ??
  process.env.DATABASE_URL?.replace(/\/mercado(\?|$)/, '/mercado_test$1');

const prisma = new PrismaClient({ datasources: { db: { url: urlTeste } } });
const servico = new ConvitesService(prisma as unknown as PrismaService);

const id = () => uuidv7();
const DONO = id();
const CONVIDADA = id();
const INTRUSO = id();

describe('ConvitesService (integração)', () => {
  let listaId: string;

  beforeAll(async () => {
    await prisma.$connect();
    for (const [usuarioId, nome] of [
      [DONO, 'Gabriel'],
      [CONVIDADA, 'Maria'],
      [INTRUSO, 'Intruso'],
    ]) {
      await prisma.usuario.upsert({
        where: { id: usuarioId },
        update: {},
        create: {
          id: usuarioId,
          nome,
          email: `${usuarioId}@teste.local`,
          senhaHash: 'x',
        },
      });
    }
  });

  afterAll(async () => {
    await prisma.usuario.deleteMany({
      where: { id: { in: [DONO, CONVIDADA, INTRUSO] } },
    });
    await prisma.$disconnect();
  });

  beforeEach(async () => {
    await prisma.lista.deleteMany({
      where: { usuarioId: { in: [DONO, CONVIDADA, INTRUSO] } },
    });
    listaId = id();
    await prisma.lista.create({
      data: {
        id: listaId,
        usuarioId: DONO,
        nome: 'Compras da casa',
        data: new Date('2026-09-01'),
      },
    });
  });

  it('só o dono gera e revoga convite', async () => {
    await expect(servico.gerar(CONVIDADA, listaId)).rejects.toThrow(
      /dono da lista/,
    );

    const convite = await servico.gerar(DONO, listaId);
    expect(convite.codigo).toMatch(/^[A-Z2-9]{6}$/);

    await expect(servico.revogar(CONVIDADA, listaId)).rejects.toThrow(
      /dono da lista/,
    );
  });

  it('gerar de novo reaproveita o código vigente', async () => {
    const primeiro = await servico.gerar(DONO, listaId);
    const segundo = await servico.gerar(DONO, listaId);
    // Um código por lista: gerar não pode invalidar o que já foi mandado
    // no grupo da família.
    expect(segundo.codigo).toBe(primeiro.codigo);
  });

  it('prévia mostra a lista sem entregar acesso', async () => {
    const { codigo } = await servico.gerar(DONO, listaId);
    const previa = await servico.previa(codigo);
    expect(previa.lista.nome).toBe('Compras da casa');
    expect(previa.lista.dono).toBe('Gabriel');

    const membros = await prisma.listaMembro.findMany({ where: { listaId } });
    expect(membros).toHaveLength(0);
  });

  it('aceitar cria o membro, e aceitar de novo não duplica', async () => {
    const { codigo } = await servico.gerar(DONO, listaId);

    await servico.aceitar(CONVIDADA, codigo);
    await servico.aceitar(CONVIDADA, codigo); // o link foi clicado duas vezes

    const membros = await prisma.listaMembro.findMany({ where: { listaId } });
    expect(membros).toHaveLength(1);
    expect(membros[0].usuarioId).toBe(CONVIDADA);
  });

  it('o dono aceitando o próprio convite não vira membro de si mesmo', async () => {
    const { codigo } = await servico.gerar(DONO, listaId);
    await servico.aceitar(DONO, codigo);
    const membros = await prisma.listaMembro.findMany({ where: { listaId } });
    expect(membros).toHaveLength(0);
  });

  it('código revogado morre na hora; quem entrou permanece', async () => {
    const { codigo } = await servico.gerar(DONO, listaId);
    await servico.aceitar(CONVIDADA, codigo);

    await servico.revogar(DONO, listaId);
    await expect(servico.aceitar(INTRUSO, codigo)).rejects.toThrow(
      /inválido ou vencido/,
    );

    const membros = await prisma.listaMembro.findMany({ where: { listaId } });
    expect(membros.map((m) => m.usuarioId)).toEqual([CONVIDADA]);
  });

  it('membro sai sozinho; tirar os outros é privilégio do dono', async () => {
    const { codigo } = await servico.gerar(DONO, listaId);
    await servico.aceitar(CONVIDADA, codigo);
    await servico.aceitar(INTRUSO, codigo);

    // O membro não expulsa outro membro.
    await expect(
      servico.removerMembro(CONVIDADA, listaId, INTRUSO),
    ).rejects.toThrow(/Só o dono/);

    // Mas sai de si mesmo.
    await servico.removerMembro(CONVIDADA, listaId, CONVIDADA);
    // E o dono expulsa quem quiser.
    await servico.removerMembro(DONO, listaId, INTRUSO);

    const membros = await prisma.listaMembro.findMany({ where: { listaId } });
    expect(membros).toHaveLength(0);
  });
});
