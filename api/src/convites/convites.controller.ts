import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import {
  AuthUser,
  CurrentUser,
} from '../auth/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { ConvitesService } from './convites.service';

@Controller()
@UseGuards(JwtAuthGuard)
export class ConvitesController {
  constructor(private readonly convites: ConvitesService) {}

  @Post('listas/:id/convites')
  gerar(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.convites.gerar(user.userId, id);
  }

  @Delete('listas/:id/convites')
  revogar(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.convites.revogar(user.userId, id);
  }

  // Limite apertado: prévia por código é o alvo óbvio de adivinhação.
  @Get('convites/:codigo')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  previa(@Param('codigo') codigo: string) {
    return this.convites.previa(codigo);
  }

  @Post('convites/:codigo/aceitar')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  aceitar(@CurrentUser() user: AuthUser, @Param('codigo') codigo: string) {
    return this.convites.aceitar(user.userId, codigo);
  }

  @Delete('listas/:id/membros/:membroId')
  removerMembro(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('membroId', ParseUUIDPipe) membroId: string,
  ) {
    return this.convites.removerMembro(user.userId, id, membroId);
  }
}
