import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { NestFactory } from '@nestjs/core';
import { static as expressStatic } from 'express';
import type { NextFunction, Request, Response } from 'express';
import { existsSync } from 'node:fs';
import { join } from 'node:path';
import { AppModule } from './app.module';
import { FiltroDeErros } from './comum/filtro-de-erros';

async function bootstrap() {
  const app = await NestFactory.create(AppModule, { bufferLogs: false });
  const config = app.get(ConfigService);

  // Em produção (SERVE_WEB=true) a própria API serve o build do Flutter.
  if (config.get('SERVE_WEB') === 'true') {
    const webDir =
      config.get('WEB_DIR') || join(__dirname, '..', '..', 'web', 'build', 'web');
    if (existsSync(webDir)) {
      app.use(expressStatic(webDir));
      app.use((req: Request, res: Response, next: NextFunction) => {
        if (req.method === 'GET' && !req.path.startsWith('/api')) {
          res.sendFile(join(webDir, 'index.html'));
        } else {
          next();
        }
      });
    }
  }

  app.setGlobalPrefix('api');

  const corsOrigin = config.get('CORS_ORIGIN', 'http://localhost:8080');
  app.enableCors({
    origin:
      corsOrigin === 'dev'
        ? [/^http:\/\/localhost:\d+$/, /^http:\/\/127\.0\.0\.1:\d+$/]
        : corsOrigin.split(','),
    credentials: true,
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new FiltroDeErros());

  const porta = config.get('PORT', 3010);
  await app.listen(porta);
  new Logger('Bipa').log(`API no ar em http://localhost:${porta}/api`);
}
bootstrap();
