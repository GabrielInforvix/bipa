import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import {
  AuthUser,
  CurrentUser,
} from '../auth/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { PuxarDto } from './dto/puxar.dto';
import { SincronizarDto } from './dto/sincronizar.dto';
import { SincronizacaoService } from './sincronizacao.service';

@Controller('sincronizacao')
@UseGuards(JwtAuthGuard)
export class SincronizacaoController {
  constructor(private readonly sinc: SincronizacaoService) {}

  /** Envia a fila local e já recebe o delta de volta, numa viagem só. */
  @Post()
  sincronizar(@CurrentUser() user: AuthUser, @Body() dto: SincronizarDto) {
    return this.sinc.sincronizar(user.userId, dto);
  }

  @Get()
  puxar(@CurrentUser() user: AuthUser, @Query() q: PuxarDto) {
    return this.sinc.puxar(user.userId, q.desde);
  }
}
