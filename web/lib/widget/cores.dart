import 'package:flutter/material.dart';

/// Paleta do Bipa, igual à aprovada no mockup.
///
/// A regra que sustenta tudo: **o laranja é a marca e a ação de bipar, e nunca
/// aparece em número**. Verde é exclusivo de economia, carmim é exclusivo de
/// estouro. Se o acento entrasse nos valores, o usuário perderia o semáforo
/// justamente na informação que ele mais lê — o preço.
class Cores {
  // Marca / ação
  static const laranja = Color(0xFFDC4B16);
  static const laranjaEscuro = Color(0xFFB03A0F);
  static const laranjaSuave = Color(0xFFFBE8E0);

  // Semáforo — só para dinheiro
  static const verde = Color(0xFF0C7245);
  static const verdeSuave = Color(0xFFE0F1E8);
  static const carmim = Color(0xFFB51F35);
  static const carmimSuave = Color(0xFFFAE5E8);

  // Neutros (grafite levemente quente)
  static const tinta = Color(0xFF191A1C);
  static const texto2 = Color(0xFF585B60);
  static const texto3 = Color(0xFF8A8D93);
  static const linha = Color(0xFFE1DED8);
  static const linhaForte = Color(0xFFCBC7BF);
  static const superficie = Color(0xFFFFFFFF);
  static const superficie2 = Color(0xFFF4F2EE);
  static const superficie3 = Color(0xFFE9E6E1);
  static const fundo = Color(0xFFF5F4F1);

  // Câmera — a tela do scanner é escura em qualquer tema
  static const camera = Color(0xFF111214);
}
