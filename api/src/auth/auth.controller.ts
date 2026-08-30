import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { AuthUser, CurrentUser } from './decorators/current-user.decorator';
import { LoginDto } from './dto/login.dto';
import { RegistrarDto } from './dto/registrar.dto';
import { RenovarDto } from './dto/renovar.dto';
import { TrocarSenhaDto } from './dto/trocar-senha.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  // Limite apertado: login e cadastro são o alvo óbvio de força bruta.
  @Post('register')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  registrar(@Body() dto: RegistrarDto) {
    return this.auth.registrar(dto);
  }

  @Post('login')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  login(@Body() dto: LoginDto) {
    return this.auth.login(dto);
  }

  @Post('refresh')
  renovar(@Body() dto: RenovarDto) {
    return this.auth.renovar(dto.refreshToken);
  }

  @Post('logout')
  sair(@Body() dto: RenovarDto) {
    return this.auth.sair(dto.refreshToken);
  }

  @Get('perfil')
  @UseGuards(JwtAuthGuard)
  perfil(@CurrentUser() user: AuthUser) {
    return this.auth.perfil(user.userId);
  }

  @Post('trocar-senha')
  @UseGuards(JwtAuthGuard)
  trocarSenha(@CurrentUser() user: AuthUser, @Body() dto: TrocarSenhaDto) {
    return this.auth.trocarSenha(user.userId, dto.senhaAtual, dto.novaSenha);
  }
}
