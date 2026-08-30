import { Module } from '@nestjs/common';
import { MercadosController } from './mercados.controller';
import { MercadosService } from './mercados.service';

@Module({
  controllers: [MercadosController],
  providers: [MercadosService],
  exports: [MercadosService],
})
export class MercadosModule {}
