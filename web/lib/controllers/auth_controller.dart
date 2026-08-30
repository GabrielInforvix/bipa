import 'package:get/get.dart';

import '../globais/http_interceptor.dart';
import '../globais/parametros_globais.dart';
import '../models/basicos_model.dart';
import '../offline/banco_local.dart';
import '../offline/sincronizador.dart';
import '../services/api_service.dart';
import '../widget/feedback.dart';
import 'conexao_controller.dart';

class AuthController extends GetxController {
  final _api = ApiService();

  final carregando = false.obs;
  final erro = RxnString();

  UsuarioModel? get usuario => ParametrosGlobais.usuario;
  bool get logado => ParametrosGlobais.logado;
  bool get temConta => ParametrosGlobais.temConta;
  bool get convidado => ParametrosGlobais.convidado;

  /// Entra sem cadastro. O usuário monta listas e faz compras no aparelho;
  /// bipar e sincronizar continuam pedindo conta.
  Future<void> usarSemConta() async {
    await Sessao.entrarComoConvidado();
    Get.offAllNamed('/inicio');
  }

  Future<bool> entrar(String email, String senha) =>
      _autenticar(() => _api.entrar(email.trim(), senha));

  Future<bool> cadastrar(String nome, String email, String senha) =>
      _autenticar(() => _api.cadastrar(nome.trim(), email.trim(), senha));

  Future<bool> _autenticar(Future<void> Function() acao) async {
    carregando.value = true;
    erro.value = null;
    // Quem estava como convidado tem listas locais e uma fila cheia — elas
    // precisam SUBIR antes de qualquer coisa, senão o pull sobrescreveria o
    // que a pessoa montou sem conta.
    final vindoDeConvidado = ParametrosGlobais.convidado;
    try {
      await acao();
      if (vindoDeConvidado) {
        await Sincronizador.sincronizar();
      } else {
        // Primeira carga: o app precisa abrir com a lista pronta, não vazia.
        await Sincronizador.cargaInicial();
      }
      if (Get.isRegistered<ConexaoController>()) {
        await Get.find<ConexaoController>().atualizarPendentes();
      }
      return true;
    } on SemConexaoException {
      erro.value = 'Sem conexão. Para entrar pela primeira vez você precisa '
          'de internet.';
      return false;
    } catch (e) {
      erro.value = _limpar(e);
      return false;
    } finally {
      carregando.value = false;
    }
  }

  Future<void> sair() async {
    await _api.sair();
    // Limpa o banco local: a lista de um usuário não pode ficar visível para
    // o próximo que entrar no mesmo aparelho.
    await BancoLocal.limpar();
    Get.offAllNamed('/login');
    Aviso.neutro('Você saiu da conta.');
  }

  String _limpar(Object e) =>
      e.toString().replaceFirst('Exception: ', '').trim();
}
