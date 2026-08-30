import { Injectable } from '@nestjs/common';
import { OrigemItem, StatusLista } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/** Alimenta a tela de início: a compra em andamento e o resumo da última. */
@Injectable()
export class DashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async resumo(usuarioId: string) {
    const [emAndamento, ultima, totalListas] = await Promise.all([
      this.prisma.lista.findFirst({
        where: { usuarioId, excluidoEm: null, status: StatusLista.EM_COMPRA },
        include: this.include(),
        orderBy: { atualizadoEm: 'desc' },
      }),
      this.prisma.lista.findFirst({
        where: { usuarioId, excluidoEm: null, status: StatusLista.FINALIZADA },
        include: this.include(),
        orderBy: { finalizadaEm: 'desc' },
      }),
      this.prisma.lista.count({ where: { usuarioId, excluidoEm: null } }),
    ]);

    return {
      emAndamento: emAndamento ? this.resumir(emAndamento) : null,
      ultimaCompra: ultima ? this.resumir(ultima) : null,
      totalListas,
    };
  }

  private include() {
    return {
      mercado: { select: { id: true, nome: true } },
      itens: {
        where: { excluidoEm: null },
        select: {
          comprado: true,
          origem: true,
          total: true,
          precoEstimado: true,
          quantidade: true,
          quantidadePlanejada: true,
        },
      },
    } as const;
  }

  private resumir(lista: {
    id: string;
    nome: string;
    data: Date;
    orcamento: unknown;
    status: StatusLista;
    finalizadaEm: Date | null;
    mercado: { id: string; nome: string } | null;
    itens: Array<{
      comprado: boolean;
      origem: OrigemItem;
      total: unknown;
      precoEstimado: unknown;
      quantidade: unknown;
      quantidadePlanejada: unknown;
    }>;
  }) {
    let totalPago = 0;
    let estimadoDosComprados = 0;
    let comprados = 0;

    for (const item of lista.itens) {
      if (!item.comprado) continue;
      comprados += 1;
      totalPago += Number(item.total ?? 0);
      if (item.origem !== OrigemItem.EXTRA) {
        estimadoDosComprados +=
          Number(item.precoEstimado ?? 0) *
          Number(item.quantidade ?? item.quantidadePlanejada ?? 1);
      }
    }

    const orcamento = lista.orcamento ? Number(lista.orcamento) : null;
    return {
      id: lista.id,
      nome: lista.nome,
      data: lista.data,
      status: lista.status,
      finalizadaEm: lista.finalizadaEm,
      mercado: lista.mercado,
      totalItens: lista.itens.length,
      itensComprados: comprados,
      totalPago: cent(totalPago),
      economia: cent(estimadoDosComprados - totalPago),
      orcamento,
      saldoOrcamento: orcamento != null ? cent(orcamento - totalPago) : null,
    };
  }
}

function cent(v: number) {
  return Math.round(v * 100) / 100;
}
