import { IsInt, IsOptional, IsString, MaxLength, Min, MinLength } from 'class-validator';

export class CreateCategoriaDto {
  @IsOptional()
  @IsString()
  id?: string;

  @IsString()
  @MinLength(1, { message: 'Informe o nome da categoria.' })
  @MaxLength(60)
  nome: string;

  @IsOptional()
  @IsString()
  @MaxLength(8)
  icone?: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  ordem?: number;
}
