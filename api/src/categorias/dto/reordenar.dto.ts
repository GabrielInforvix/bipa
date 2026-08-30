import { ArrayNotEmpty, IsArray, IsUUID } from 'class-validator';

/** A ordem das categorias é a ordem do corredor do mercado. O usuário
 *  arrasta uma vez e não volta atrás no corredor de bebidas nunca mais. */
export class ReordenarCategoriasDto {
  @IsArray()
  @ArrayNotEmpty()
  @IsUUID('all', { each: true })
  ids: string[];
}
