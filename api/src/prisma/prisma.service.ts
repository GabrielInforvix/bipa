import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

/** Cliente Prisma compartilhado. Cada usuário só enxerga os próprios dados —
 *  o filtro por `usuarioId` é responsabilidade de cada service. */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  async onModuleInit() {
    await this.$connect();
  }
}
