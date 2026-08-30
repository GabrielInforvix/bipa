import 'escaner_codigo_barras.dart';
// A escolha da implementação é feita em tempo de compilação. Sem isso, o
// código do navegador (dart:js_interop) entraria no build do Android e a
// compilação quebraria.
import 'escaner_indisponivel.dart'
    if (dart.library.js_interop) 'escaner_web.dart'
    if (dart.library.io) 'escaner_nativo.dart' as plataforma;

/// Devolve o leitor certo para a plataforma:
/// ML Kit no Android/iOS, BarcodeDetector na web.
EscanerCodigoBarras criarEscaner() => plataforma.criarEscanerPlataforma();
