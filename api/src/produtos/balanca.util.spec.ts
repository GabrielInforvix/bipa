import {
  digitoVerificadorValido,
  ehEtiquetaBalanca,
  lerEtiquetaBalanca,
  normalizarEan,
} from './balanca.util';

describe('etiqueta de balança', () => {
  // 2 + código 004512 + valor 04320 + DV 1  →  R$ 43,20
  const ETIQUETA_PRECO = '2004512043201';
  // 2 + código 004512 + valor 01238 + DV 2  →  1,238 kg
  const ETIQUETA_PESO = '2004512012382';
  // Layout alternativo: 2 + código 00451 + valor 004320 + DV 3
  const ETIQUETA_C5V6 = '2004510043203';
  // EAN de catálogo de verdade (arroz do seed)
  const EAN_CATALOGO = '7896036098264';

  it('reconhece código interno de loja pelo prefixo 2', () => {
    expect(ehEtiquetaBalanca(ETIQUETA_PRECO)).toBe(true);
    expect(ehEtiquetaBalanca(EAN_CATALOGO)).toBe(false);
  });

  it('lê o preço embutido na etiqueta', () => {
    const etiqueta = lerEtiquetaBalanca(ETIQUETA_PRECO, 'PRECO');
    expect(etiqueta).toEqual({
      codigoInterno: '004512',
      preco: 43.2,
      formato: 'PRECO',
    });
  });

  it('lê o peso embutido na etiqueta', () => {
    const etiqueta = lerEtiquetaBalanca(ETIQUETA_PESO, 'PESO');
    expect(etiqueta).toEqual({
      codigoInterno: '004512',
      pesoKg: 1.238,
      formato: 'PESO',
    });
  });

  it('respeita o layout configurado da balança', () => {
    expect(lerEtiquetaBalanca(ETIQUETA_C5V6, 'PRECO', 'C5V6')).toEqual({
      codigoInterno: '00451',
      preco: 43.2,
      formato: 'PRECO',
    });
  });

  it('recusa etiqueta com dígito verificador errado', () => {
    // Preencher preço errado no carrinho é pior do que não preencher nada.
    expect(lerEtiquetaBalanca('2004512043209', 'PRECO')).toBeNull();
  });

  it('não trata EAN de catálogo como etiqueta', () => {
    expect(lerEtiquetaBalanca(EAN_CATALOGO, 'PRECO')).toBeNull();
  });

  it('valida o dígito verificador de EAN-13 e EAN-8', () => {
    expect(digitoVerificadorValido(EAN_CATALOGO)).toBe(true);
    expect(digitoVerificadorValido('7891234567895')).toBe(true);
    expect(digitoVerificadorValido('7891234567890')).toBe(false);
    expect(digitoVerificadorValido('12345')).toBe(false);
  });

  it('normaliza o que vem do leitor', () => {
    expect(normalizarEan(' 789-6036 098264 ')).toBe(EAN_CATALOGO);
  });
});
