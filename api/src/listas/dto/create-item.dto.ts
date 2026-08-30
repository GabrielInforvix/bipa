import { OrigemItem, TipoVenda } from '@prisma/client';
import { Type } from 'class-transformer';
import {
  IsBoolean,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsPositive,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateItemDto {
  @IsOptional()
  @IsUUID()
  id?: string;

  /** Item pode apontar para o catálogo… */
  @IsOptional()
  @IsUUID()
  produtoId?: string;

  /** …ou ser só um nome escrito na mão ("pão na padaria"). */
  @IsOptional()
  @IsString()
  @MaxLength(120)
  nomeLivre?: string;

  @IsOptional()
  @IsUUID()
  categoriaId?: string;

  @IsOptional()
  @IsEnum(OrigemItem)
  origem?: OrigemItem;

  @IsOptional()
  @IsEnum(TipoVenda)
  tipoVenda?: TipoVenda;

  @IsOptional()
  @IsString()
  @MaxLength(10)
  unidade?: string;

  /** Decimal porque 1,238 kg de patinho é caso normal, não exceção. */
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 3 })
  @IsPositive()
  @Max(99999)
  quantidadePlanejada?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  precoEstimado?: number;

  @IsOptional()
  @IsInt()
  ordem?: number;

  @IsOptional()
  @IsBoolean()
  comprado?: boolean;

  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 3 })
  @IsPositive()
  quantidade?: number;

  /** R$ por unidade, ou R$ por quilo quando o produto é vendido por peso. */
  @IsOptional()
  @Type(() => Number)
  @IsNumber({ maxDecimalPlaces: 2 })
  @Min(0)
  precoUnitario?: number;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  observacao?: string;
}
