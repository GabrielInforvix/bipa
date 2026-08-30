import { IsString, MaxLength, MinLength } from 'class-validator';

export class TrocarSenhaDto {
  @IsString()
  @MinLength(1, { message: 'Informe a senha atual.' })
  senhaAtual: string;

  @IsString()
  @MinLength(6, { message: 'A nova senha precisa ter ao menos 6 caracteres.' })
  @MaxLength(72)
  novaSenha: string;
}
