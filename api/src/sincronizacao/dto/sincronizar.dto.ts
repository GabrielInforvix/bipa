import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsDateString,
  IsIn,
  IsObject,
  IsOptional,
  IsUUID,
  ValidateNested,
} from 'class-validator';

export const ENTIDADES = [
  'lista',
  'lista_item',
  'produto',
  'categoria',
  'mercado',
] as const;
export type EntidadeSync = (typeof ENTIDADES)[number];

export const ACOES = ['criar', 'atualizar', 'excluir'] as const;
export type AcaoSync = (typeof ACOES)[number];

export class OperacaoDto {
  /** Gerado pelo app. É a chave da idempotência: reenviar o mesmo lote
   *  não pode aplicar a operação duas vezes. */
  @IsUUID()
  id: string;

  @IsIn(ENTIDADES)
  entidade: EntidadeSync;

  @IsUUID()
  entidadeId: string;

  @IsIn(ACOES)
  acao: AcaoSync;

  /** Momento em que a alteração aconteceu no aparelho. Usado para decidir
   *  quem vence quando servidor e app mexeram no mesmo registro. */
  @IsDateString()
  ocorridoEm: string;

  @IsOptional()
  @IsObject()
  dados?: Record<string, unknown>;
}

export class SincronizarDto {
  @IsArray()
  @ArrayMaxSize(500)
  @ValidateNested({ each: true })
  @Type(() => OperacaoDto)
  operacoes: OperacaoDto[];

  /** Cursor do último pull. Ausente = primeira sincronização (traz tudo). */
  @IsOptional()
  @IsDateString()
  desde?: string;
}
