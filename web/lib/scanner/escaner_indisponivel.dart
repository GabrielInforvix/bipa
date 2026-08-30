import 'package:flutter/widgets.dart';

import 'escaner_codigo_barras.dart';

EscanerCodigoBarras criarEscanerPlataforma() => EscanerIndisponivel();

/// Usado só onde nenhuma das duas implementações se aplica (Windows, Linux,
/// macOS desktop). A tela cai na digitação do código e a compra continua.
class EscanerIndisponivel implements EscanerCodigoBarras {
  @override
  Stream<String> get leituras => const Stream.empty();

  @override
  Stream<ErroEscaner> get erros => const Stream.empty();

  @override
  Future<bool> disponivel() async => false;

  @override
  Future<void> iniciar() async => throw const ErroEscaner(
        'Esta plataforma não lê código de barras. Digite o código para continuar.',
      );

  @override
  Widget previa() => const SizedBox.shrink();

  @override
  void confirmarLeitura() {}

  @override
  Future<bool> alternarLanterna() async => false;

  @override
  Future<void> parar() async {}

  @override
  void dispose() {}
}
