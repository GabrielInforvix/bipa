import { Type } from 'class-transformer';
import {
  IsDateString,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateListaDto {
  /** O app gera o id offline; o servidor respeita o que veio. */
  @IsOptional()
  @IsUUID()
  id?: string;

  @IsString()
  @MinLength(1, { message: 'Informe o nome da lista.' })
  @MaxLength(80)
  nome: string;

  @IsOptional()
  @IsDateString({}, { message: 'Data inválida.' })
  data?: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  observacao?: string;

  /** Teto da compra. Responde a pergunta do corredor: dá pra levar? */
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @IsPositive()
  orcamento?: number;

  @IsOptional()
  @IsUUID()
  mercadoId?: string;

  /** Copia os itens de uma lista anterior ao criar (o "repetir lista"). */
  @IsOptional()
  @IsUUID()
  copiarDeListaId?: string;
}
