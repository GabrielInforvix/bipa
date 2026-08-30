import { IsString, MinLength } from 'class-validator';

export class RenovarDto {
  @IsString()
  @MinLength(10)
  refreshToken: string;
}
