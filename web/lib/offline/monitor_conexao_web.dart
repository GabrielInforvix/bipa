import 'dart:js_interop';

import 'package:web/web.dart' as web;

bool onlineAgora() => web.window.navigator.onLine;

/// O navegador avisa quando a rede cai e volta. É o gatilho que dispara a
/// fila de sincronização assim que o sinal retorna.
void escutarConexao(void Function(bool online) aoMudar) {
  web.window.addEventListener('online', ((web.Event _) => aoMudar(true)).toJS);
  web.window.addEventListener('offline', ((web.Event _) => aoMudar(false)).toJS);
}
