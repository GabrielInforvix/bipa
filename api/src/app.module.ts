import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AuthModule } from './auth/auth.module';
import { CategoriasModule } from './categorias/categorias.module';
import { ConvitesModule } from './convites/convites.module';
import { DashboardModule } from './dashboard/dashboard.module';
import { ListasModule } from './listas/listas.module';
import { MercadosModule } from './mercados/mercados.module';
import { PrismaModule } from './prisma/prisma.module';
import { ProdutosModule } from './produtos/produtos.module';
import { SincronizacaoModule } from './sincronizacao/sincronizacao.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    // Teto generoso: o app dispara rajadas legítimas ao sincronizar a fila
    // depois de uma compra inteira feita offline.
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 300 }]),
    PrismaModule,
    AuthModule,
    CategoriasModule,
    ConvitesModule,
    MercadosModule,
    ProdutosModule,
    ListasModule,
    SincronizacaoModule,
    DashboardModule,
  ],
  providers: [{ provide: APP_GUARD, useClass: ThrottlerGuard }],
})
export class AppModule {}
