import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  AuthUser,
  CurrentUser,
} from '../auth/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CreateItemDto } from './dto/create-item.dto';
import { CreateListaDto } from './dto/create-lista.dto';
import { ListarListasDto } from './dto/listar-listas.dto';
import { UpdateItemDto } from './dto/update-item.dto';
import { UpdateListaDto } from './dto/update-lista.dto';
import { ListasService } from './listas.service';

@Controller('listas')
@UseGuards(JwtAuthGuard)
export class ListasController {
  constructor(private readonly listas: ListasService) {}

  @Get()
  listar(@CurrentUser() user: AuthUser, @Query() q: ListarListasDto) {
    return this.listas.listar(user.userId, q.status);
  }

  @Post()
  criar(@CurrentUser() user: AuthUser, @Body() dto: CreateListaDto) {
    return this.listas.criar(user.userId, dto);
  }

  @Get(':id')
  porId(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.listas.porId(user.userId, id);
  }

  @Put(':id')
  atualizar(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateListaDto,
  ) {
    return this.listas.atualizar(user.userId, id, dto);
  }

  @Delete(':id')
  remover(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.listas.remover(user.userId, id);
  }

  @Post(':id/iniciar')
  iniciar(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.listas.iniciarCompra(user.userId, id);
  }

  @Post(':id/finalizar')
  finalizar(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.listas.finalizar(user.userId, id);
  }

  @Post(':id/repetir')
  repetir(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body('nome') nome?: string,
  ) {
    return this.listas.repetir(user.userId, id, nome);
  }

  @Post(':id/itens')
  adicionarItem(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateItemDto,
  ) {
    return this.listas.adicionarItem(user.userId, id, dto);
  }

  @Put(':id/itens/:itemId')
  atualizarItem(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: UpdateItemDto,
  ) {
    return this.listas.atualizarItem(user.userId, id, itemId, dto);
  }

  // PATCH é o que o app usa no Modo Compra (só quantidade e preço mudam).
  @Patch(':id/itens/:itemId')
  ajustarItem(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: UpdateItemDto,
  ) {
    return this.listas.atualizarItem(user.userId, id, itemId, dto);
  }

  @Delete(':id/itens/:itemId')
  removerItem(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('itemId', ParseUUIDPipe) itemId: string,
  ) {
    return this.listas.removerItem(user.userId, id, itemId);
  }
}
