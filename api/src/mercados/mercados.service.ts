import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { novoId } from '../comum/ids';
import { PrismaService } from '../prisma/prisma.service';
import { CreateMercadoDto } from './dto/create-mercado.dto';
import { UpdateMercadoDto } from './dto/update-mercado.dto';

@Injectable()
export class MercadosService {
  constructor(private readonly prisma: PrismaService) {}

  listar(usuarioId: string) {
    return this.prisma.mercado.findMany({
      where: { usuarioId, ativo: true },
      orderBy: { nome: 'asc' },
    });
  }

  async criar(usuarioId: string, dto: CreateMercadoDto) {
    const nome = dto.nome.trim();
    const existente = await this.prisma.mercado.findFirst({
      where: { usuarioId, nome },
    });
    if (existente) {
      // Reativa em vez de recusar: o usuário não deve se importar com o fato
      // de já ter cadastrado e removido esse mercado antes.
      if (!existente.ativo) {
        return this.prisma.mercado.update({
          where: { id: existente.id },
          data: { ativo: true, cidade: dto.cidade ?? existente.cidade },
        });
      }
      return existente;
    }
    return this.prisma.mercado.create({
      data: { id: dto.id ?? novoId(), usuarioId, nome, cidade: dto.cidade },
    });
  }

  async atualizar(usuarioId: string, id: string, dto: UpdateMercadoDto) {
    await this.exigir(usuarioId, id);
    if (dto.nome) {
      const duplicado = await this.prisma.mercado.findFirst({
        where: { usuarioId, nome: dto.nome.trim(), NOT: { id } },
      });
      if (duplicado) {
        throw new ConflictException('Você já tem um mercado com esse nome.');
      }
    }
    return this.prisma.mercado.update({
      where: { id },
      data: { nome: dto.nome?.trim(), cidade: dto.cidade },
    });
  }

  /** Mercado citado em lista ou histórico só é inativado — apagar de vez
   *  destruiria a comparação de preço entre lojas. */
  async remover(usuarioId: string, id: string) {
    await this.exigir(usuarioId, id);
    const usado =
      (await this.prisma.lista.findFirst({ where: { mercadoId: id } })) ||
      (await this.prisma.historicoPreco.findFirst({ where: { mercadoId: id } }));
    if (usado) {
      await this.prisma.mercado.update({ where: { id }, data: { ativo: false } });
    } else {
      await this.prisma.mercado.delete({ where: { id } });
    }
    return { ok: true };
  }

  private async exigir(usuarioId: string, id: string) {
    const m = await this.prisma.mercado.findFirst({ where: { id, usuarioId } });
    if (!m) throw new NotFoundException('Mercado não encontrado.');
    return m;
  }
}
