import { PartialType, OmitType } from '@nestjs/mapped-types';
import { IsEnum, IsOptional } from 'class-validator';
import { StatusLista } from '@prisma/client';
import { CreateListaDto } from './create-lista.dto';

export class UpdateListaDto extends PartialType(
  OmitType(CreateListaDto, ['id', 'copiarDeListaId'] as const),
) {
  @IsOptional()
  @IsEnum(StatusLista)
  status?: StatusLista;
}
