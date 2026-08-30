import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { Request, Response } from 'express';

/**
 * Tratamento central de erros.
 *
 * O log guarda o erro inteiro para diagnóstico; a resposta ao cliente devolve
 * só uma frase em português. Nada de stack trace, nome de tabela ou trecho de
 * SQL vazando para o navegador.
 */
@Catch()
export class FiltroDeErros implements ExceptionFilter {
  private readonly log = new Logger('Erro');

  catch(erro: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const res = ctx.getResponse<Response>();
    const req = ctx.getRequest<Request>();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | string[] = 'Erro inesperado. Tente novamente.';

    if (erro instanceof HttpException) {
      status = erro.getStatus();
      const corpo = erro.getResponse();
      message =
        typeof corpo === 'string'
          ? corpo
          : ((corpo as { message?: string | string[] }).message ?? erro.message);
    } else if (erro instanceof Prisma.PrismaClientKnownRequestError) {
      switch (erro.code) {
        case 'P2002':
          status = HttpStatus.CONFLICT;
          message = 'Esse registro já existe.';
          break;
        case 'P2025':
          status = HttpStatus.NOT_FOUND;
          message = 'Registro não encontrado.';
          break;
        case 'P2003':
          status = HttpStatus.BAD_REQUEST;
          message = 'Referência inválida.';
          break;
        default:
          status = HttpStatus.BAD_REQUEST;
          message = 'Não foi possível concluir a operação.';
      }
    }

    if (status >= 500) {
      this.log.error(
        `${req.method} ${req.url} — ${(erro as Error)?.message}`,
        (erro as Error)?.stack,
      );
    }

    res.status(status).json({
      statusCode: status,
      message,
      path: req.url,
      timestamp: new Date().toISOString(),
    });
  }
}
