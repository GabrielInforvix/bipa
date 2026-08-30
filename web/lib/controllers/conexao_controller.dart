import 'dart:async';

import 'package:get/get.dart';

import '../globais/parametros_globais.dart';
import '../offline/fila_sincronizacao.dart';
import '../offline/monitor_conexao.dart';
import '../offline/sincronizador.dart';

/// Estado de conexão e da fila de sincronização.
///
/// Ficar offline é um estado previsto do app, não um erro — por isso o aviso
/// aparece em laranja e diz o que importa: continua funcionando.
class ConexaoController extends GetxController {
  final online = true.obs;
  final pendentes = 0.obs;
  final sincronizando = false.obs;
  final ultimaSincronizacao = Rxn<DateTime>();

  StreamSubscription<EstadoSincronizacao>? _inscricao;
  Timer? _periodico;

  @override
  void onInit() {
    super.onInit();
    online.value = conexaoAtiva();

    // Voltar a conexão dispara a fila na hora: no PWA do iOS o IndexedDB pode
    // ser limpo depois de dias sem uso, então quanto antes os dados chegarem
    // ao servidor, melhor.
    observarConexao((conectado) {
      online.value = conectado;
      if (conectado) sincronizar();
    });

    _inscricao = Sincronizador.estado.listen((estado) {
      sincronizando.value = estado == EstadoSincronizacao.enviando;
      if (estado == EstadoSincronizacao.offline) online.value = false;
      if (estado == EstadoSincronizacao.ocioso) {
        online.value = true;
        ultimaSincronizacao.value = Sincronizador.ultimaSincronizacao;
      }
    });

    _periodico = Timer.periodic(const Duration(minutes: 2), (_) {
      if (online.value) sincronizar();
    });

    atualizarPendentes();
  }

  Future<void> atualizarPendentes() async {
    pendentes.value = await FilaSincronizacao.quantidade();
  }

  Future<void> sincronizar() async {
    final r = await Sincronizador.sincronizar();
    pendentes.value = r.pendentes;
    if (r.sucesso) {
      online.value = true;
      ultimaSincronizacao.value = Sincronizador.ultimaSincronizacao;
    }
  }

  /// Texto curto para o chip de status na barra superior.
  String get rotulo {
    if (ParametrosGlobais.convidado) return 'sem conta';
    if (!online.value) return 'sem conexão';
    if (sincronizando.value) return 'enviando…';
    if (pendentes.value > 0) return '${pendentes.value} na fila';
    return 'sincronizado';
  }

  @override
  void onClose() {
    _inscricao?.cancel();
    _periodico?.cancel();
    super.onClose();
  }
}
