import 'package:intl/intl.dart';

final NumberFormat _real = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
final NumberFormat _semSimbolo = NumberFormat('#,##0.00', 'pt_BR');
final NumberFormat _quantidade = NumberFormat('#,##0.###', 'pt_BR');

extension NumFormatacao on num {
  /// 1234.5 → "R$ 1.234,50"
  String get emReais => _real.format(this);

  /// 1234.5 → "1.234,50" — para quando o "R$" já está na tela em outro tamanho.
  String get emValor => _semSimbolo.format(this);

  /// 1.238 → "1,238" · 3 → "3"
  String get emQuantidade => _quantidade.format(this);

  /// Formata quantidade com a unidade: "1,238 kg", "3 un".
  String emQuantidadeCom(String unidade) => '$emQuantidade $unidade';
}

/// Converte texto pt-BR ("1.234,56") em double.
double? parseValorPtBr(String texto) {
  final limpo = texto.trim().replaceAll('.', '').replaceAll(',', '.');
  if (limpo.isEmpty) return null;
  return double.tryParse(limpo);
}

/// Entrada de preço estilo caixa registradora: o usuário digita só dígitos e
/// os centavos vão preenchendo da direita para a esquerda. "599" → 5,99.
///
/// Existe para não depender do teclado do sistema, que em PWA no iOS entrega
/// vírgula decimal de forma inconsistente e empurra o layout ao abrir.
class EntradaCentavos {
  EntradaCentavos([this._centavos = 0]);

  int _centavos;

  int get centavos => _centavos;
  double get valor => _centavos / 100;
  bool get vazio => _centavos == 0;

  /// "R$ 5,99"
  String get formatado => valor.emReais;

  void digitar(String digito) {
    final n = int.tryParse(digito);
    if (n == null) return;
    // Teto de R$ 99.999,99 — acima disso é digitação errada, não compra.
    if (_centavos >= 1000000) return;
    _centavos = _centavos * 10 + n;
  }

  void apagar() => _centavos = _centavos ~/ 10;

  void limpar() => _centavos = 0;

  void definir(double valor) =>
      _centavos = (valor * 100).round().clamp(0, 9999999);

  EntradaCentavos copia() => EntradaCentavos(_centavos);
}
