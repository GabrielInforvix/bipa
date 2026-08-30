import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CatalogoExterno, ProdutoExterno } from './catalogo-externo';

/**
 * Adaptador do Open Food Facts.
 *
 * É o SEGUNDO degrau da cascata, nunca o primeiro: a cobertura de EAN
 * brasileiro fora das grandes marcas é baixa, e uma consulta externa no
 * caminho do scanner custa tempo que o usuário sente no corredor. Só é
 * chamado quando o catálogo local não conhece o código.
 */
@Injectable()
export class OpenFoodFactsService extends CatalogoExterno {
  readonly nome = 'open-food-facts';
  private readonly log = new Logger(OpenFoodFactsService.name);
  private readonly url: string;
  private readonly timeoutMs: number;

  constructor(config: ConfigService) {
    super();
    this.url = config.get(
      'OPEN_FOOD_FACTS_URL',
      'https://world.openfoodfacts.org/api/v2/product',
    );
    this.timeoutMs = Number(config.get('CATALOGO_EXTERNO_TIMEOUT_MS', 3500));
  }

  async buscarPorEan(ean: string): Promise<ProdutoExterno | null> {
    if (!this.url) return null;

    // Timeout curto e obrigatório: no supermercado, esperar 10s por uma API
    // é pior do que cadastrar o produto na mão.
    const cancelar = AbortSignal.timeout(this.timeoutMs);
    try {
      const campos = 'product_name,brands,image_url,categories';
      const resposta = await fetch(
        `${this.url}/${encodeURIComponent(ean)}.json?fields=${campos}`,
        {
          signal: cancelar,
          headers: { 'User-Agent': 'Bipa/0.1 (lista de supermercado)' },
        },
      );
      if (!resposta.ok) return null;

      const corpo = (await resposta.json()) as {
        status?: number;
        product?: {
          product_name?: string;
          brands?: string;
          image_url?: string;
          categories?: string;
        };
      };
      const p = corpo.product;
      if (corpo.status !== 1 || !p) return null;
      const nome = p.product_name?.trim();
      if (!nome) return null;

      return {
        ean,
        nome,
        marca: primeiro(p.brands),
        imagemUrl: p.image_url || undefined,
        categoriaSugerida: primeiro(p.categories),
        fonte: this.nome,
      };
    } catch (erro) {
      // Fonte externa fora do ar não pode derrubar o scanner: o usuário
      // simplesmente cai no cadastro manual.
      this.log.warn(
        `Consulta ao Open Food Facts falhou para ${ean}: ${(erro as Error).message}`,
      );
      return null;
    }
  }
}

/** "Italac,Italac Alimentos" → "Italac" */
function primeiro(lista?: string): string | undefined {
  const valor = lista?.split(',')[0]?.trim();
  return valor || undefined;
}
