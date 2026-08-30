import { StatusLista } from '@prisma/client';
import { IsEnum, IsOptional } from 'class-validator';

export class ListarListasDto {
  @IsOptional()
  @IsEnum(StatusLista)
  status?: StatusLista;
}
