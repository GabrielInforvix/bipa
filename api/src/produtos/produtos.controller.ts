import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import {
  AuthUser,
  CurrentUser,
} from '../auth/decorators/current-user.decorator';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { BuscarProdutosDto } from './dto/buscar-produtos.dto';
import { CreateProdutoDto } from './dto/create-produto.dto';
import { UpdateProdutoDto } from './dto/update-produto.dto';
import { ProdutosService } from './produtos.service';

@Controller('produtos')
@UseGuards(JwtAuthGuard)
export class ProdutosController {
  constructor(private readonly produtos: ProdutosService) {}

  @Get()
  listar(@CurrentUser() user: AuthUser, @Query() q: BuscarProdutosDto) {
    return this.produtos.listar(user.userId, q.termo, q.limite);
  }

  /** Caminho crítico do scanner — precisa responder rápido. */
  @Get('ean/:ean')
  porEan(@CurrentUser() user: AuthUser, @Param('ean') ean: string) {
    return this.produtos.buscarPorEan(user.userId, ean);
  }

  @Get(':id')
  porId(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.produtos.porId(user.userId, id);
  }

  @Get(':id/historico-precos')
  historico(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.produtos.historicoPrecos(user.userId, id);
  }

  @Post()
  criar(@CurrentUser() user: AuthUser, @Body() dto: CreateProdutoDto) {
    return this.produtos.criar(user.userId, dto);
  }

  @Patch(':id')
  atualizar(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateProdutoDto,
  ) {
    return this.produtos.atualizar(user.userId, id, dto);
  }
}
