import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomInt } from 'node:crypto';
import { novoId } from '../comum/ids';
import { PrismaService } from '../prisma/prisma.service';

/// Sem 0/O, 1/I/L — código que vai ser ditado por telefone e digitado com o
/// polegar não pode ter caractere que se confunde.
const ALFABETO = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const VALIDADE_DIAS = 7;

@Injectable()
export class ConvitesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Gera (ou reaproveita) o convite da lista. Multiuso até ser revogado —
   * a família inteira entra pelo mesmo código, expira em 7 dias.
   * Só o dono convida: editor que convida vira gestão de gente sem dono.
   */
  async gerar(usuarioId: string, listaId: string) {
    await this.exigirDono(usuarioId, listaId);

    const vigente = await this.prisma.convite.findFirst({
      where: {
        listaId,
        revogadoEm: null,
        expiraEm: { gt: new Date() },
      },
    });
    if (vigente) return this.publico(vigente);

    const convite = await this.prisma.convite.create({
      data: {
        id: novoId(),
        listaId,
        codigo: await this.codigoInedito(),
        criadoPorId: usuarioId,
        expiraEm: new Date(Date.now() + VALIDADE_DIAS * 24 * 60 * 60 * 1000),
      },
    });
    return this.publico(convite);
  }

  /** Revogar mata o código na hora; quem já entrou continua na lista. */
  async revogar(usuarioId: string, listaId: string) {
    await this.exigirDono(usuarioId, listaId);
    await this.prisma.convite.updateMany({
      where: { listaId, revogadoEm: null },
      data: { revogadoEm: new Date() },
    });
    return { ok: true };
  }

  /**
   * Prévia antes de entrar: nome, dono e tamanho da lista. Ninguém entra numa
   * lista às cegas por causa de um link.
   */
  async previa(codigo: string) {
    const convite = await this.exigirValido(codigo);
    const lista = await this.prisma.lista.findFirst({
      where: { id: convite.listaId, excluidoEm: null },
      include: {
        usuario: { select: { nome: true } },
        _count: { select: { itens: { where: { excluidoEm: null } } } },
      },
    });
    if (!lista) throw new NotFoundException('Essa lista não existe mais.');

    return {
      codigo: convite.codigo,
      lista: {
        nome: lista.nome,
        dono: lista.usuario.nome,
        itens: lista._count.itens,
      },
    };
  }

  /** Entra na lista. Idempotente: aceitar de novo não duplica o membro. */
  async aceitar(usuarioId: string, codigo: string) {
    const convite = await this.exigirValido(codigo);
    const lista = await this.prisma.lista.findFirst({
      where: { id: convite.listaId, excluidoEm: null },
    });
    if (!lista) throw new NotFoundException('Essa lista não existe mais.');

    // Dono "aceitando" o próprio convite não vira membro de si mesmo.
    if (lista.usuarioId !== usuarioId) {
      await this.prisma.listaMembro.upsert({
        where: { listaId_usuarioId: { listaId: lista.id, usuarioId } },
        create: { id: novoId(), listaId: lista.id, usuarioId },
        update: {},
      });
      // Toca o relógio da lista: o delta dos outros membros passa a incluí-la.
      await this.prisma.lista.update({
        where: { id: lista.id },
        data: { atualizadoEm: new Date() },
      });
    }
    return { ok: true, listaId: lista.id };
  }

  /**
   * Sai da lista (o próprio membro) ou remove alguém (só o dono).
   * O dono não sai da própria lista — ele a exclui, se quiser.
   */
  async removerMembro(
    usuarioId: string,
    listaId: string,
    membroId: string,
  ) {
    const lista = await this.prisma.lista.findFirst({
      where: { id: listaId, excluidoEm: null },
    });
    if (!lista) throw new NotFoundException('Lista não encontrada.');

    const souDono = lista.usuarioId === usuarioId;
    const saindoDeSiMesmo = membroId === usuarioId;
    if (!souDono && !saindoDeSiMesmo) {
      throw new ForbiddenException('Só o dono remove outras pessoas.');
    }

    await this.prisma.listaMembro.deleteMany({
      where: { listaId, usuarioId: membroId },
    });
    await this.prisma.lista.update({
      where: { id: listaId },
      data: { atualizadoEm: new Date() },
    });
    return { ok: true };
  }

  // ── Internos ───────────────────────────────────────────────────────

  private async exigirDono(usuarioId: string, listaId: string) {
    const lista = await this.prisma.lista.findFirst({
      where: { id: listaId, excluidoEm: null },
    });
    if (!lista) throw new NotFoundException('Lista não encontrada.');
    if (lista.usuarioId !== usuarioId) {
      throw new ForbiddenException('Só o dono da lista convida e revoga.');
    }
    return lista;
  }

  private async exigirValido(codigo: string) {
    const limpo = codigo.toUpperCase().replace(/[^A-Z0-9]/g, '');
    const convite = await this.prisma.convite.findUnique({
      where: { codigo: limpo },
    });
    if (!convite || convite.revogadoEm || convite.expiraEm < new Date()) {
      throw new NotFoundException(
        'Convite inválido ou vencido. Peça um código novo.',
      );
    }
    return convite;
  }

  /** XXX-XXX sem caracteres ambíguos. ~887 milhões de combinações. */
  private async codigoInedito(): Promise<string> {
    for (let tentativa = 0; tentativa < 5; tentativa++) {
      const bruto = Array.from(
        { length: 6 },
        () => ALFABETO[randomInt(ALFABETO.length)],
      ).join('');
      const existe = await this.prisma.convite.findUnique({
        where: { codigo: bruto },
      });
      if (!existe) return bruto;
    }
    throw new Error('Não foi possível gerar um código único.');
  }

  /** O código sai formatado para leitura: "K4M2VD" → "K4M-2VD" na tela. */
  private publico(convite: { codigo: string; expiraEm: Date }) {
    return { codigo: convite.codigo, expiraEm: convite.expiraEm };
  }
}
