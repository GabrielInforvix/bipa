import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import {
  AuthUser,
  CurrentUser,
} from '../auth/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateMercadoDto } from './dto/create-mercado.dto';
import { UpdateMercadoDto } from './dto/update-mercado.dto';
import { MercadosService } from './mercados.service';

@Controller('mercados')
@UseGuards(JwtAuthGuard)
export class MercadosController {
  constructor(private readonly mercados: MercadosService) {}

  @Get()
  listar(@CurrentUser() user: AuthUser) {
    return this.mercados.listar(user.userId);
  }

  @Post()
  criar(@CurrentUser() user: AuthUser, @Body() dto: CreateMercadoDto) {
    return this.mercados.criar(user.userId, dto);
  }

  @Patch(':id')
  atualizar(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateMercadoDto,
  ) {
    return this.mercados.atualizar(user.userId, id, dto);
  }

  @Delete(':id')
  remover(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.mercados.remover(user.userId, id);
  }
}
