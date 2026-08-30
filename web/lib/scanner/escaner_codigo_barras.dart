import 'package:flutter/widgets.dart';

/// Porta do leitor de código de barras.
///
/// Existe para que a decisão técnica mais arriscada do projeto — ler código de
/// barras — fique atrás de uma interface. Hoje há duas implementações:
///
/// - **Android/iOS:** `EscanerNativo`, sobre o ML Kit. É a leitura boa: rápida,
///   tolerante a foco ruim e a código amassado na embalagem.
/// - **Web:** `EscanerWeb`, sobre a API `BarcodeDetector` do navegador. Existe
///   no Chrome para Android e **não existe no Safari do iOS** — onde falta, a
///   tela oferece digitação do código.
///
/// A prévia da câmera é devolvida como *widget* justamente para caber nas duas:
/// na web é um `HtmlElementView` com o `<video>`, no nativo é a textura da
/// câmera. Nenhuma tela precisa saber a diferença.
abstract class EscanerCodigoBarras {
  /// Se este aparelho/navegador consegue ler código de barras.
  /// Quando `false`, a tela oferece digitação manual — nunca um beco sem saída.
  Future<bool> disponivel();

  /// Liga a câmera.
  Future<void> iniciar();

  /// Prévia da câmera para desenhar na tela.
  Widget previa();

  /// Códigos lidos, já sem repetição em sequência: apontar a câmera para o
  /// mesmo produto por dois segundos emite uma leitura, não trinta.
  Stream<String> get leituras;

  /// Falhas que só aparecem **depois** de a câmera começar a abrir — permissão
  /// negada no diálogo do sistema, câmera ocupada por outro app.
  ///
  /// Existe porque no nativo a câmera é iniciada pelo próprio widget de
  /// prévia, então o erro não pode ser devolvido por `iniciar()`: ele chega
  /// mais tarde. Sem este canal, a falha viraria tela vazia.
  Stream<ErroEscaner> get erros;

  /// Desliga a câmera e libera o aparelho.
  Future<void> parar();

  /// Retorno de leitura: vibração curta + bipe.
  ///
  /// No corredor o usuário não está olhando a tela quando o código entra no
  /// enquadramento — o retorno precisa ser sonoro e tátil, não visual.
  void confirmarLeitura();

  /// Lanterna, quando o aparelho tiver. Prateleira baixa de supermercado é
  /// escura o suficiente para isso importar.
  Future<bool> alternarLanterna();

  void dispose();
}

/// Erros do leitor, já com texto pronto para a tela.
class ErroEscaner implements Exception {
  final String mensagem;
  final bool permissaoNegada;

  const ErroEscaner(this.mensagem, {this.permissaoNegada = false});

  @override
  String toString() => mensagem;
}

/// Descarta leitura repetida do mesmo código.
///
/// Sem isso, manter a câmera sobre um produto dispararia dezenas de leituras
/// iguais e o app abriria a folha de preço em looping.
class FiltroDeRepeticao {
  static const _janela = Duration(seconds: 3);

  String? _ultimo;
  DateTime _quando = DateTime.fromMillisecondsSinceEpoch(0);

  bool aceita(String codigo) {
    final agora = DateTime.now();
    if (codigo == _ultimo && agora.difference(_quando) < _janela) return false;
    _ultimo = codigo;
    _quando = agora;
    return true;
  }

  void limpar() => _ultimo = null;
}
