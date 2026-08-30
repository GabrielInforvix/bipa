import { Injectable, NotFoundException } from '@nestjs/common';
import { novoId } from '../comum/ids';
import { PrismaService } from '../prisma/prisma.service';
import { CreateCategoriaDto } from './dto/create-categoria.dto';
import { UpdateCategoriaDto } from './dto/update-categoria.dto';

@Injectable()
export class CategoriasService {
  constructor(private readonly prisma: PrismaService) {}

  listar(usuarioId: string) {
    return this.prisma.categoria.findMany({
      where: { usuarioId, ativo: true },
      orderBy: [{ ordem: 'asc' }, { nome: 'asc' }],
    });
  }

  async criar(usuarioId: string, dto: CreateCategoriaDto) {
    const ultima = await this.prisma.categoria.findFirst({
      where: { usuarioId },
      orderBy: { ordem: 'desc' },
      select: { ordem: true },
    });
    return this.prisma.categoria.create({
      data: {
        id: dto.id ?? novoId(),
        nome: dto.nome.trim(),
        icone: dto.icone,
        ordem: dto.ordem ?? (ultima ? ultima.ordem + 1 : 0),
        usuarioId,
      },
    });
  }

  async atualizar(usuarioId: string, id: string, dto: UpdateCategoriaDto) {
    await this.exigir(usuarioId, id);
    return this.prisma.categoria.update({
      where: { id },
      data: { nome: dto.nome?.trim(), icone: dto.icone, ordem: dto.ordem },
    });
  }

  /** Reordena em bloco. Categoria que não é do usuário é simplesmente
   *  ignorada — não dá para reordenar a lista de outra pessoa. */
  async reordenar(usuarioId: string, ids: string[]) {
    const minhas = await this.prisma.categoria.findMany({
      where: { usuarioId, id: { in: ids } },
      select: { id: true },
    });
    const permitidos = new Set(minhas.map((c) => c.id));
    await this.prisma.$transaction(
      ids
        .filter((id) => permitidos.has(id))
        .map((id, ordem) =>
          this.prisma.categoria.update({ where: { id }, data: { ordem } }),
        ),
    );
    return this.listar(usuarioId);
  }

  /** Categoria em uso vira inativa; sem uso é excluída de vez. */
  async remover(usuarioId: string, id: string) {
    await this.exigir(usuarioId, id);
    const emUso = await this.prisma.listaItem.findFirst({
      where: { categoriaId: id },
      select: { id: true },
    });
    if (emUso) {
      await this.prisma.categoria.update({
        where: { id },
        data: { ativo: false },
      });
    } else {
      await this.prisma.categoria.delete({ where: { id } });
    }
    return { ok: true };
  }

  private async exigir(usuarioId: string, id: string) {
    const c = await this.prisma.categoria.findFirst({
      where: { id, usuarioId },
    });
    if (!c) throw new NotFoundException('Categoria não encontrada.');
    return c;
  }
}
