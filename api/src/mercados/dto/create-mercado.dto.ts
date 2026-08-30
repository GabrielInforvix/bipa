import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class CreateMercadoDto {
  @IsOptional()
  @IsString()
  id?: string;

  @IsString()
  @MinLength(1, { message: 'Informe o nome do mercado.' })
  @MaxLength(80)
  nome: string;

  @IsOptional()
  @IsString()
  @MaxLength(80)
  cidade?: string;
}
