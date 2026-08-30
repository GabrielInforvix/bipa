import 'package:sembast/sembast.dart';

import 'fabrica_banco.dart';

/// Banco local em IndexedDB.
///
/// Toda leitura de tela sai daqui, nunca da rede: é isso que faz o app abrir
/// instantâneo e continuar inteiro dentro do supermercado, onde o sinal cai.
/// A rede só alimenta este banco por trás, pelo sincronizador.
///
/// Onde grava depende da plataforma (ver `fabrica_banco.dart`): IndexedDB na
/// web, arquivo privado no Android/iOS.
///
/// Atenção conhecida do **PWA no iOS**: o Safari pode limpar o IndexedDB depois
/// de ~7 dias sem uso — e um app de compras é usado poucas vezes por mês, então
/// esse é o caso comum, não a exceção. A mitigação é sincronizar cedo e sempre
/// (ao abrir, ao voltar a conexão e ao encerrar a compra), para que o servidor
/// tenha os dados antes de a limpeza acontecer. No app instalado (APK) esse
/// risco não existe.
class BancoLocal {
  static Database? _db;

  static final listas = stringMapStoreFactory.store('listas');
  static final produtos = stringMapStoreFactory.store('produtos');
  static final categorias = stringMapStoreFactory.store('categorias');
  static final mercados = stringMapStoreFactory.store('mercados');
  static final fila = stringMapStoreFactory.store('fila_sincronizacao');
  static final avulsos = stringMapStoreFactory.store('avulsos');

  static Future<Database> get instancia async =>
      _db ??= await abrirBancoLocal();

  /// Limpa tudo — usado no logout, para não deixar a lista de um usuário
  /// visível para o próximo que entrar no mesmo aparelho.
  static Future<void> limpar() async {
    final db = await instancia;
    await db.transaction((txn) async {
      for (final store in [listas, produtos, categorias, mercados, fila, avulsos]) {
        await store.delete(txn);
      }
    });
  }
}
