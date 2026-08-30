import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'escaner_codigo_barras.dart';

EscanerCodigoBarras criarEscanerPlataforma() => EscanerNativo();

/// Leitor do Android/iOS, sobre o ML Kit.
///
/// É a leitura que o app merece: decodifica com a embalagem amassada, com
/// pouca luz e sem esperar o foco assentar — três coisas que descrevem
/// exatamente uma prateleira de supermercado.
///
/// **Quem liga a câmera é o widget de prévia, não este código.** O
/// `MobileScannerController` nasce com `autoStart`, e o `start()` do pacote
/// espera (com timeout de 500 ms) que o widget `MobileScanner` já esteja
/// montado. Chamar `start()` antes de colocar a prévia na tela cria um
/// impasse: o widget nunca monta, o timeout estoura e a câmera nunca abre.
class EscanerNativo implements EscanerCodigoBarras {
  final MobileScannerController _controle = MobileScannerController(
    // `normal` já devolve leitura em poucos décimos e não esquenta o aparelho
    // como o modo sem trava. Em compra longa isso importa.
    detectionSpeed: DetectionSpeed.normal,
    // Restringir aos formatos de supermercado brasileiro acelera a
    // decodificação e evita ler QR de propaganda por engano.
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
    ],
  );

  final _leituras = StreamController<String>.broadcast();
  final _erros = StreamController<ErroEscaner>.broadcast();
  final _filtro = FiltroDeRepeticao();
  StreamSubscription<BarcodeCapture>? _inscricao;
  bool _lanternaLigada = false;

  @override
  Stream<String> get leituras => _leituras.stream;

  @override
  Stream<ErroEscaner> get erros => _erros.stream;

  @override
  Future<bool> disponivel() async => true;

  @override
  Future<void> iniciar() async {
    _inscricao = _controle.barcodes.listen((captura) {
      for (final codigo in captura.barcodes) {
        final valor = codigo.rawValue;
        if (valor == null || valor.isEmpty) continue;
        if (!_filtro.aceita(valor)) continue;
        confirmarLeitura();
        _leituras.add(valor);
        break; // uma leitura por quadro
      }
    });

    // A câmera sobe junto com a prévia. Aqui só ficamos de olho no estado
    // para transformar falha do sistema em mensagem na tela.
    _controle.addListener(_observarEstado);
  }

  void _observarEstado() {
    final erro = _controle.value.error;
    if (erro == null) return;

    final negada = erro.errorCode == MobileScannerErrorCode.permissionDenied;
    _erros.add(
      ErroEscaner(
        negada
            ? 'Permita o acesso à câmera para bipar produtos. Você pode '
                'liberar em Ajustes do Android > Apps > Bipa > Permissões.'
            : 'Não foi possível abrir a câmera. Digite o código para continuar.',
        permissaoNegada: negada,
      ),
    );
  }

  @override
  Widget previa() => MobileScanner(controller: _controle, fit: BoxFit.cover);

  @override
  void confirmarLeitura() {
    // Vibração é o retorno que funciona com o celular fora do campo de visão.
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
  }

  @override
  Future<bool> alternarLanterna() async {
    try {
      await _controle.toggleTorch();
      _lanternaLigada = !_lanternaLigada;
      return _lanternaLigada;
    } catch (_) {
      // Nem todo aparelho expõe a lanterna — o botão simplesmente não age.
      return false;
    }
  }

  @override
  Future<void> parar() async {
    await _inscricao?.cancel();
    _inscricao = null;
    _controle.removeListener(_observarEstado);
    _filtro.limpar();
    // Não chamamos stop(): quem desligou a câmera foi o próprio widget de
    // prévia ao sair da árvore. Chamar de novo aqui só geraria exceção.
  }

  @override
  void dispose() {
    _inscricao?.cancel();
    _controle.removeListener(_observarEstado);
    try {
      // O widget de prévia sai da árvore antes daqui e já desliga a câmera.
      // O try existe para o caso de a ordem se inverter numa versão futura do
      // pacote — descartar duas vezes não pode derrubar a tela.
      _controle.dispose();
    } catch (_) {}
    _leituras.close();
    _erros.close();
  }
}
