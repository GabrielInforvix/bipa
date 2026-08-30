import { TipoVenda } from '@prisma/client';
import {
  IsEnum,
  IsOptional,
  IsString,
  IsUUID,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateProdutoDto {
  @IsOptional()
  @IsUUID()
  id?: string;

  /** Regra 10: produto sem código de barras é permitido. */
  @IsOptional()
  @IsString()
  @MaxLength(14)
  ean?: string;

  @IsString()
  @MinLength(2, { message: 'Informe o nome do produto.' })
  @MaxLength(120)
  nome: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  marca?: string;

  @IsOptional()
  @IsEnum(TipoVenda)
  tipoVenda?: TipoVenda;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  unidade?: string;

  @IsOptional()
  @IsUUID()
  categoriaId?: string;

  /** Nome só desse usuário para o produto, sem mexer no catálogo global. */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  apelido?: string;
}
