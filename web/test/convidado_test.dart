import 'package:bipa_web/globais/parametros_globais.dart';
import 'package:bipa_web/models/basicos_model.dart';
import 'package:bipa_web/offline/sincronizador.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado do modo convidado.
///
/// O risco aqui não é visual, é de confundir dois conceitos parecidos:
///
/// - `logado`   → pode **usar o app** (com conta ou sem)
/// - `temConta` → pode **falar com o servidor**
///
/// Trocar um pelo outro num `if` dá um bug silencioso e feio: ou o convidado
/// é expulso para o login, ou o app tenta sincronizar sem token e fica
/// exibindo erro de sessão para quem nunca pediu conta.
void main() {
  const usuario = UsuarioModel(
    id: 'u1',
    nome: 'Gabriel Torresani',
    email: 'g@bipa.local',
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Sessao.limpar();
  });

  test('sem nada, o app manda para o login', () {
    expect(ParametrosGlobais.logado, isFalse);
    expect(ParametrosGlobais.temConta, isFalse);
  });

  test('convidado pode usar o app, mas não tem conta', () async {
    await Sessao.entrarComoConvidado();
    expect(ParametrosGlobais.logado, isTrue);
    expect(ParametrosGlobais.temConta, isFalse);
  });

  test('o convidado continua convidado depois de fechar o app', () async {
    await Sessao.entrarComoConvidado();
    ParametrosGlobais.convidado = false; // simula o app reiniciando

    await Sessao.carregar();
    expect(ParametrosGlobais.convidado, isTrue);
    expect(ParametrosGlobais.logado, isTrue);
  });

  test('criar conta encerra o modo convidado', () async {
    await Sessao.entrarComoConvidado();
    await Sessao.salvar(
      token: 'a',
      refreshToken: 'b',
      usuario: usuario,
    );

    expect(ParametrosGlobais.convidado, isFalse);
    expect(ParametrosGlobais.temConta, isTrue);
    expect(ParametrosGlobais.usuario?.primeiroNome, 'Gabriel');

    // E não pode voltar a ser convidado por sobra no armazenamento.
    ParametrosGlobais.convidado = true;
    await Sessao.carregar();
    expect(ParametrosGlobais.convidado, isFalse);
  });

  test('sair limpa tudo, inclusive a marca de convidado', () async {
    await Sessao.entrarComoConvidado();
    await Sessao.limpar();
    expect(ParametrosGlobais.convidado, isFalse);
    expect(ParametrosGlobais.logado, isFalse);
  });

  test('convidado não tenta sincronizar', () async {
    await Sessao.entrarComoConvidado();
    final r = await Sincronizador.sincronizar();

    // Sem conta não há token: tentar subiria erro de sessão na cara de quem
    // nunca pediu conta nenhuma.
    expect(r.sucesso, isFalse);
    expect(r.erro, 'Sem conta');
  });

  test('cursor de sincronização é descartado ao sair', () async {
    await Sessao.salvar(token: 'a', refreshToken: 'b', usuario: usuario);
    await Sessao.salvarCursor('2026-08-28T12:00:00.000Z');
    expect(await Sessao.cursor(), isNotNull);

    await Sessao.limpar();
    // Se o cursor sobrevivesse, o próximo usuário deste aparelho começaria
    // com um delta parcial e listas faltando.
    expect(await Sessao.cursor(), isNull);
  });
}
