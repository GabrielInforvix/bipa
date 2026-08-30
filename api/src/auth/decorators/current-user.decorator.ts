import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { PerfilUsuario } from '@prisma/client';

export interface AuthUser {
  userId: string;
  perfil: PerfilUsuario;
  email: string;
  nome: string;
}

/** Injeta o usuário autenticado (payload do JWT) no handler. */
export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): AuthUser =>
    ctx.switchToHttp().getRequest().user,
);
