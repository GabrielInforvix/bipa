import { IsDateString, IsOptional } from 'class-validator';

export class PuxarDto {
  @IsOptional()
  @IsDateString()
  desde?: string;
}
