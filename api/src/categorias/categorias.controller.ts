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
import { CategoriasService } from './categorias.service';
import { CreateCategoriaDto } from './dto/create-categoria.dto';
import { ReordenarCategoriasDto } from './dto/reordenar.dto';
import { UpdateCategoriaDto } from './dto/update-categoria.dto';

@Controller('categorias')
@UseGuards(JwtAuthGuard)
export class CategoriasController {
  constructor(private readonly categorias: CategoriasService) {}

  @Get()
  listar(@CurrentUser() user: AuthUser) {
    return this.categorias.listar(user.userId);
  }

  @Post()
  criar(@CurrentUser() user: AuthUser, @Body() dto: CreateCategoriaDto) {
    return this.categorias.criar(user.userId, dto);
  }

  @Patch('reordenar')
  reordenar(
    @CurrentUser() user: AuthUser,
    @Body() dto: ReordenarCategoriasDto,
  ) {
    return this.categorias.reordenar(user.userId, dto.ids);
  }

  @Patch(':id')
  atualizar(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateCategoriaDto,
  ) {
    return this.categorias.atualizar(user.userId, id, dto);
  }

  @Delete(':id')
  remover(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.categorias.remover(user.userId, id);
  }
}
