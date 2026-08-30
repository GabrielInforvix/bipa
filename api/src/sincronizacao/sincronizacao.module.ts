import { Module } from '@nestjs/common';
import { SincronizacaoController } from './sincronizacao.controller';
import { SincronizacaoService } from './sincronizacao.service';

@Module({
  controllers: [SincronizacaoController],
  providers: [SincronizacaoService],
})
export class SincronizacaoModule {}
