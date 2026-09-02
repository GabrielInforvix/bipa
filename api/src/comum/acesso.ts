import { Prisma } from '@prisma/client';

/**
 * O filtro que faz a lista compartilhada existir.
 *
 * Antes, "lista sua" era `usuarioId == você`. Agora é **dona OU membro** — e
 * este fragmento é usado por todos os services que tocam listas (listas,
 * sincronização, dashboard, histórico de preços). Centralizado porque um
 * `if` esquecido em um canto viraria vazamento de dados no outro.
 */
export function minhaLista(usuarioId: string): Prisma.ListaWhereInput {
  return {
    OR: [{ usuarioId }, { membros: { some: { usuarioId } } }],
  };
}

/** Membros de uma lista (dono + participantes), para respostas e iniciais. */
export const INCLUIR_PESSOAS = {
  usuario: { select: { id: true, nome: true } },
  membros: {
    select: {
      usuarioId: true,
      entrouEm: true,
      usuario: { select: { id: true, nome: true } },
    },
  },
} satisfies Prisma.ListaInclude;
