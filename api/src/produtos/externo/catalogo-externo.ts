import { TipoVenda } from '@prisma/client';

/** O que uma fonte externa consegue dizer sobre um código de barras. */
export interface ProdutoExterno {
  ean: string;
  nome: string;
  marca?: string;
  imagemUrl?: string;
  categoriaSugerida?: string;
  tipoVenda?: TipoVenda;
  /** Nome da fonte, para diagnóstico e para medir cobertura. */
  fonte: string;
}

/**
 * Porta para consulta de produto por código de barras.
 *
 * Existe para que trocar ou somar fontes (Cosmos, GS1, catálogo próprio de
 * outra rede) seja acrescentar uma implementação — nunca mexer no
 * ProdutosService. A cascata de busca vive no service; aqui só mora o
 * "como perguntar" a cada fonte.
 */
export abstract class CatalogoExterno {
  abstract readonly nome: string;

  /** Devolve `null` quando a fonte não conhece o código. Nunca lança:
   *  fonte externa fora do ar não pode derrubar o scanner do usuário. */
  abstract buscarPorEan(ean: string): Promise<ProdutoExterno | null>;
}

/** Token de injeção — permite registrar várias fontes em cascata. */
export const CATALOGOS_EXTERNOS = Symbol('CATALOGOS_EXTERNOS');
