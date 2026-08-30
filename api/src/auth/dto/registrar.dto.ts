import { IsEmail, IsString, MaxLength, MinLength } from 'class-validator';

export class RegistrarDto {
  @IsString()
  @MinLength(2, { message: 'Informe seu nome.' })
  @MaxLength(120)
  nome: string;

  @IsEmail({}, { message: 'E-mail inválido.' })
  email: string;

  @IsString()
  @MinLength(6, { message: 'A senha precisa ter ao menos 6 caracteres.' })
  @MaxLength(72)
  senha: string;
}
