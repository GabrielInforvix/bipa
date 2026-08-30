import 'package:sembast/sembast.dart';

import 'fabrica_banco_indisponivel.dart'
    if (dart.library.js_interop) 'fabrica_banco_web.dart'
    if (dart.library.io) 'fabrica_banco_io.dart' as plataforma;

/// Abre o banco local: IndexedDB na web, arquivo no Android/iOS.
Future<Database> abrirBancoLocal() => plataforma.abrirBanco();
