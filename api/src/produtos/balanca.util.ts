/**
 * Etiquetas de balança (açougue, hortifrúti, frios, padaria) não usam EAN de
 * catálogo: usam EAN-13 iniciado em 2, que é a faixa reservada para código
 * interno da loja. O código carrega o produto e um valor — preço em centavos
 * ou peso em gramas, dependendo de como a balança foi configurada.
 *
 * Esses códigos NUNCA vão existir no Open Food Facts nem em catálogo global:
 * o mesmo produto tem código diferente em cada supermercado. Por isso são
 * resolvidos localmente, e o que se guarda no histórico é o preço por quilo,
 * que é o único número comparável entre compras.
 *
 * Layouts suportados (13 dígitos, o último é o verificador):
 *   C6V5 → 2 + código(6) + valor(5) + DV   (padrão Toledo/Filizola)
 *   C5V6 → 2 + código(5) + valor(6) + DV
 */

export type FormatoBalanca = 'PRECO' | 'PESO';
export type LayoutBalanca = 'C6V5' | 'C5V6';

export interface EtiquetaBalanca {
  /** Código interno do produto naquela loja. */
  codigoInterno: string;
  /** Preço total em reais, quando a balança grava preço. */
  preco?: number;
  /** Peso em quilos, quando a balança grava peso. */
  pesoKg?: number;
  formato: FormatoBalanca;
}

/** EAN-13 iniciado em 2 é código interno de loja, não produto de catálogo. */
export function ehEtiquetaBalanca(ean: string): boolean {
  const limpo = somenteDigitos(ean);
  return limpo.length === 13 && limpo.startsWith('2');
}

/**
 * Decodifica a etiqueta. Devolve `null` quando o código não é de balança ou
 * quando o dígito verificador não fecha — melhor não adivinhar do que
 * preencher um preço errado no carrinho do usuário.
 */
export function lerEtiquetaBalanca(
  ean: string,
  formato: FormatoBalanca = 'PRECO',
  layout: LayoutBalanca = 'C6V5',
): EtiquetaBalanca | null {
  const d = somenteDigitos(ean);
  if (!ehEtiquetaBalanca(d)) return null;
  if (!digitoVerificadorValido(d)) return null;

  const tamCodigo = layout === 'C6V5' ? 6 : 5;
  const tamValor = layout === 'C6V5' ? 5 : 6;

  const codigoInterno = d.slice(1, 1 + tamCodigo);
  const bruto = Number(d.slice(1 + tamCodigo, 1 + tamCodigo + tamValor));
  if (!Number.isFinite(bruto)) return null;

  return formato === 'PRECO'
    ? { codigoInterno, preco: arredondar(bruto / 100, 2), formato }
    : { codigoInterno, pesoKg: arredondar(bruto / 1000, 3), formato };
}

/** Validação padrão do EAN-8/12/13/14 (soma ponderada 1-3). */
export function digitoVerificadorValido(ean: string): boolean {
  const d = somenteDigitos(ean);
  if (![8, 12, 13, 14].includes(d.length)) return false;

  const digitos = d.split('').map(Number);
  const verificador = digitos.pop() as number;
  // O peso 3 começa no dígito mais à direita antes do verificador.
  const soma = digitos
    .reverse()
    .reduce((acc, n, i) => acc + n * (i % 2 === 0 ? 3 : 1), 0);
  return (10 - (soma % 10)) % 10 === verificador;
}

/** Normaliza o que veio do leitor: só dígitos. */
export function normalizarEan(ean: string): string {
  return somenteDigitos(ean);
}

function somenteDigitos(valor: string): string {
  return (valor ?? '').replace(/\D/g, '');
}

function arredondar(valor: number, casas: number): number {
  const f = 10 ** casas;
  return Math.round(valor * f) / f;
}
