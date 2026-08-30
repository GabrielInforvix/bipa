import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { PerfilUsuario, Usuario } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'node:crypto';
import { novoId } from '../comum/ids';
import { PrismaService } from '../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { RegistrarDto } from './dto/registrar.dto';

export interface JwtPayload {
  sub: string;
  perfil: PerfilUsuario;
  email: string;
  nome: string;
}

interface RefreshPayload {
  sub: string;
  jti: string;
}

/** Categorias que todo usuário novo recebe, já na ordem em que se anda no
 *  supermercado — hortifrúti na entrada, limpeza no fim. A ordem é editável
 *  depois; o que importa é não começar em ordem alfabética, que não
 *  corresponde a nenhum corredor real. */
const CATEGORIAS_PADRAO: Array<{ nome: string; icone: string }> = [
  { nome: 'Hortifrúti', icone: '🥬' },
  { nome: 'Padaria', icone: '🥖' },
  { nome: 'Açougue', icone: '🥩' },
  { nome: 'Frios e Laticínios', icone: '🧀' },
  { nome: 'Mercearia', icone: '🍚' },
  { nome: 'Bebidas', icone: '🥤' },
  { nome: 'Congelados', icone: '🧊' },
  { nome: 'Limpeza', icone: '🧴' },
  { nome: 'Higiene', icone: '🪥' },
  { nome: 'Outros', icone: '📦' },
];

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
  ) {}

  async registrar(dto: RegistrarDto) {
    const email = dto.email.trim().toLowerCase();
    const existente = await this.prisma.usuario.findUnique({ where: { email } });
    if (existente) {
      throw new ConflictException('Já existe uma conta com esse e-mail.');
    }

    const usuario = await this.prisma.usuario.create({
      data: {
        id: novoId(),
        nome: dto.nome.trim(),
        email,
        senhaHash: await bcrypt.hash(dto.senha, 10),
      },
    });
    await this.criarCategoriasPadrao(usuario.id);

    const tokens = await this.emitirTokens(usuario);
    return { usuario: this.publico(usuario), ...tokens };
  }

  async login(dto: LoginDto) {
    const email = dto.email.trim().toLowerCase();
    const usuario = await this.prisma.usuario.findUnique({ where: { email } });
    const ok = usuario && (await bcrypt.compare(dto.senha, usuario.senhaHash));
    if (!ok) throw new UnauthorizedException('E-mail ou senha incorretos.');
    if (!usuario.ativo) {
      throw new UnauthorizedException('Conta desativada.');
    }

    const tokens = await this.emitirTokens(usuario);
    return { usuario: this.publico(usuario), ...tokens };
  }

  async renovar(refreshToken: string) {
    let payload: RefreshPayload;
    try {
      payload = await this.jwt.verifyAsync<RefreshPayload>(refreshToken, {
        secret: this.config.getOrThrow('JWT_REFRESH_SECRET'),
      });
    } catch {
      throw new UnauthorizedException('Sessão inválida. Entre novamente.');
    }

    const guardado = await this.prisma.tokenAtualizacao.findUnique({
      where: { jti: payload.jti },
    });
    if (!guardado || guardado.revogadoEm || guardado.expiraEm < new Date()) {
      throw new UnauthorizedException('Sessão expirada. Entre novamente.');
    }
    const confere = await bcrypt.compare(refreshToken, guardado.tokenHash);
    if (!confere) {
      throw new UnauthorizedException('Sessão inválida. Entre novamente.');
    }

    const usuario = await this.prisma.usuario.findUnique({
      where: { id: payload.sub },
    });
    if (!usuario || !usuario.ativo) {
      throw new UnauthorizedException('Conta desativada.');
    }

    // Rotação: o token usado morre aqui e um novo par é emitido.
    await this.prisma.tokenAtualizacao.update({
      where: { id: guardado.id },
      data: { revogadoEm: new Date() },
    });
    const tokens = await this.emitirTokens(usuario);
    return { usuario: this.publico(usuario), ...tokens };
  }

  async sair(refreshToken: string) {
    try {
      const { jti } = await this.jwt.verifyAsync<RefreshPayload>(refreshToken, {
        secret: this.config.getOrThrow('JWT_REFRESH_SECRET'),
      });
      await this.prisma.tokenAtualizacao.updateMany({
        where: { jti, revogadoEm: null },
        data: { revogadoEm: new Date() },
      });
    } catch {
      // token já inválido — sair é idempotente
    }
    return { ok: true };
  }

  async perfil(usuarioId: string) {
    const u = await this.prisma.usuario.findUnique({
      where: { id: usuarioId },
      select: { id: true, nome: true, email: true, perfil: true },
    });
    if (!u) throw new UnauthorizedException('Usuário não encontrado.');
    return u;
  }

  async trocarSenha(usuarioId: string, senhaAtual: string, novaSenha: string) {
    const u = await this.prisma.usuario.findUnique({ where: { id: usuarioId } });
    const ok = u && (await bcrypt.compare(senhaAtual, u.senhaHash));
    if (!ok) throw new BadRequestException('Senha atual incorreta.');
    await this.prisma.usuario.update({
      where: { id: u.id },
      data: { senhaHash: await bcrypt.hash(novaSenha, 10) },
    });
    // Trocar a senha derruba as outras sessões.
    await this.prisma.tokenAtualizacao.updateMany({
      where: { usuarioId, revogadoEm: null },
      data: { revogadoEm: new Date() },
    });
    return { ok: true };
  }

  /** Categorias padrão do usuário, criadas junto com a conta. */
  async criarCategoriasPadrao(usuarioId: string) {
    await this.prisma.categoria.createMany({
      data: CATEGORIAS_PADRAO.map((c, i) => ({
        id: novoId(),
        nome: c.nome,
        icone: c.icone,
        ordem: i,
        usuarioId,
      })),
      skipDuplicates: true,
    });
  }

  private async emitirTokens(usuario: Usuario) {
    const accessToken = await this.jwt.signAsync(
      {
        sub: usuario.id,
        perfil: usuario.perfil,
        email: usuario.email,
        nome: usuario.nome,
      } satisfies JwtPayload,
      {
        secret: this.config.getOrThrow('JWT_ACCESS_SECRET'),
        expiresIn: this.config.get('JWT_ACCESS_TTL', '15m'),
      },
    );

    const jti = randomUUID();
    const refreshToken = await this.jwt.signAsync(
      { sub: usuario.id, jti } satisfies RefreshPayload,
      {
        secret: this.config.getOrThrow('JWT_REFRESH_SECRET'),
        expiresIn: this.config.get('JWT_REFRESH_TTL', '60d'),
      },
    );

    const { exp } = this.jwt.decode(refreshToken) as { exp: number };
    await this.prisma.tokenAtualizacao.create({
      data: {
        id: novoId(),
        jti,
        usuarioId: usuario.id,
        tokenHash: await bcrypt.hash(refreshToken, 10),
        expiraEm: new Date(exp * 1000),
      },
    });

    return { accessToken, refreshToken };
  }

  private publico(usuario: Usuario) {
    return {
      id: usuario.id,
      nome: usuario.nome,
      email: usuario.email,
      perfil: usuario.perfil,
    };
  }
}
