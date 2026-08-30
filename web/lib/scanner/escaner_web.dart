import 'dart:async';
import 'dart:js_interop';
// has() é uma extensão de js_interop_unsafe.
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'escaner_codigo_barras.dart';

EscanerCodigoBarras criarEscanerPlataforma() => EscanerWeb();

// ── Interop com a API BarcodeDetector ─────────────────────────────────
// Não faz parte de package:web, então é declarada aqui. Existe no Chrome
// para Android e está ausente no Safari do iOS — por isso `disponivel()`
// é verificado antes de abrir a câmera.

@JS('BarcodeDetector')
extension type _BarcodeDetector._(JSObject _) implements JSObject {
  external factory _BarcodeDetector(JSObject options);
  external JSPromise<JSArray<_CodigoDetectado>> detect(JSObject fonte);
}

extension type _CodigoDetectado._(JSObject _) implements JSObject {
  external String get rawValue;
  external String get format;
}

/// Leitor do navegador.
///
/// Roda sem WebAssembly extra e sem baixar nada — é a leitura mais rápida
/// disponível em Flutter Web. Onde a API não existe, o app cai na digitação do
/// código, que continua permitindo terminar a compra.
class EscanerWeb implements EscanerCodigoBarras {
  static const _tipoView = 'bipa-camera';
  static bool _viewRegistrada = false;

  web.HTMLVideoElement? _video;
  web.MediaStream? _stream;
  _BarcodeDetector? _detector;
  Timer? _laco;

  final _leituras = StreamController<String>.broadcast();
  final _erros = StreamController<ErroEscaner>.broadcast();
  final _filtro = FiltroDeRepeticao();
  bool _lanternaLigada = false;

  @override
  Stream<String> get leituras => _leituras.stream;

  // Na web a falha aparece já em `iniciar()`, então este canal fica quieto.
  // Existe para a interface valer nas duas plataformas.
  @override
  Stream<ErroEscaner> get erros => _erros.stream;

  @override
  Future<bool> disponivel() async {
    if (!globalContext.has('BarcodeDetector')) return false;
    // Câmera exige contexto seguro (https ou localhost).
    return web.window.isSecureContext;
  }

  @override
  Future<void> iniciar() async {
    if (!await disponivel()) {
      throw const ErroEscaner(
        'Este navegador não lê código de barras. Digite o código para continuar.',
      );
    }

    try {
      // `environment` = câmera traseira. No celular, é sempre ela.
      final restricoes = {
        'video': {
          'facingMode': {'ideal': 'environment'},
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      }.jsify() as JSObject;

      _stream = await web.window.navigator.mediaDevices
          .getUserMedia(restricoes as web.MediaStreamConstraints)
          .toDart;
    } catch (e) {
      final texto = e.toString();
      final negada =
          texto.contains('NotAllowed') || texto.contains('Permission');
      throw ErroEscaner(
        negada
            ? 'Permita o acesso à câmera para bipar produtos.'
            : 'Não foi possível abrir a câmera. Digite o código para continuar.',
        permissaoNegada: negada,
      );
    }

    final video = web.HTMLVideoElement()
      ..autoplay = true
      ..muted = true
      // Sem isto o iOS abre o vídeo em tela cheia por conta própria.
      ..setAttribute('playsinline', 'true')
      ..srcObject = _stream;
    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'cover';
    _video = video;

    if (!_viewRegistrada) {
      ui_web.platformViewRegistry
          .registerViewFactory(_tipoView, (int _) => _video!);
      _viewRegistrada = true;
    }

    _detector = _BarcodeDetector({
      'formats': ['ean_13', 'ean_8', 'upc_a', 'upc_e', 'code_128'],
    }.jsify() as JSObject);

    _iniciarLaco();
  }

  @override
  Widget previa() => const HtmlElementView(viewType: _tipoView);

  /// 250 ms é o intervalo que equilibra: rápido o bastante para parecer
  /// instantâneo, espaçado o bastante para não fritar a bateria.
  void _iniciarLaco() {
    _laco?.cancel();
    _laco = Timer.periodic(const Duration(milliseconds: 250), (_) async {
      final video = _video;
      final detector = _detector;
      if (video == null || detector == null) return;
      if (video.readyState < 2) return; // ainda sem quadro

      try {
        final achados = await detector.detect(video as JSObject).toDart;
        if (achados.length == 0) return;
        final codigo = achados.toDart.first.rawValue;
        if (!_filtro.aceita(codigo)) return;
        confirmarLeitura();
        _leituras.add(codigo);
      } catch (_) {
        // Quadro ruim, foco em transição: a próxima passada resolve.
      }
    });
  }

  @override
  void confirmarLeitura() {
    try {
      web.window.navigator.vibrate(40.toJS);
    } catch (_) {}
    _bipe();
  }

  /// Bipe curto pelo Web Audio — não depende de arquivo de áudio, então
  /// funciona offline e não pesa no cache do PWA.
  void _bipe() {
    try {
      final ctx = web.AudioContext();
      final osc = ctx.createOscillator();
      final ganho = ctx.createGain();
      osc.type = 'square';
      osc.frequency.value = 2100;
      ganho.gain.value = 0.06;
      osc.connect(ganho);
      ganho.connect(ctx.destination);
      osc.start();
      Timer(const Duration(milliseconds: 90), () {
        osc.stop();
        ctx.close();
      });
    } catch (_) {}
  }

  @override
  Future<bool> alternarLanterna() async {
    final faixas = _stream?.getVideoTracks();
    if (faixas == null || faixas.length == 0) return false;
    try {
      final faixa = faixas.toDart.first;
      _lanternaLigada = !_lanternaLigada;
      await faixa
          .applyConstraints({
            'advanced': [
              {'torch': _lanternaLigada}
            ]
          }.jsify() as web.MediaTrackConstraints)
          .toDart;
      return _lanternaLigada;
    } catch (_) {
      _lanternaLigada = false;
      return false;
    }
  }

  @override
  Future<void> parar() async {
    _laco?.cancel();
    _laco = null;
    final faixas = _stream?.getTracks();
    if (faixas != null) {
      for (var i = 0; i < faixas.length; i++) {
        faixas.toDart[i].stop();
      }
    }
    _video?.srcObject = null;
    _stream = null;
    _video = null;
    _detector = null;
    _filtro.limpar();
  }

  @override
  void dispose() {
    parar();
    _leituras.close();
    _erros.close();
  }
}
