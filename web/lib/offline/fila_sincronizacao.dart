import 'package:sembast/sembast.dart';

import '../globais/parametros_globais.dart';
import 'banco_local.dart';

enum EntidadeSync {
  lista('lista'),
  listaItem('lista_item'),
  produto('produto'),
  categoria('categoria'),
  mercado('mercado');

  const EntidadeSync(this.chave);
  final String chave;
}

enum AcaoSync {
  criar('criar'),
  atualizar('atualizar'),
  excluir('excluir');

  const AcaoSync(this.chave);
  final String chave;
}

/// Uma alteração feita no aparelho, esperando para subir.
class OperacaoPendente {
  final String id;
  final EntidadeSync entidade;
  final String entidadeId;
  final AcaoSync acao;
  final DateTime ocorridoEm;
  final Map<String, dynamic> dados;

  OperacaoPendente({
    required this.id,
    required this.entidade,
    required this.entidadeId,
    required this.acao,
    required this.ocorridoEm,
    this.dados = const {},
  });

  /// Descrição curta para a tela de sincronização.
  String get descricao => switch (entidade) {
        EntidadeSync.lista => 'Lista ${_acaoTexto()}',
        EntidadeSync.listaItem => '${dados['_rotulo'] ?? 'Item'} ${_acaoTexto()}',
        EntidadeSync.produto => '${dados['nome'] ?? 'Produto'} · novo',
        EntidadeSync.categoria => 'Categoria ${_acaoTexto()}',
        EntidadeSync.mercado => 'Mercado ${_acaoTexto()}',
      };

  String _acaoTexto() => switch (acao) {
        AcaoSync.criar => 'criado',
        AcaoSync.atualizar => 'alterado',
        AcaoSync.excluir => 'removido',
      };

  Map<String, dynamic> paraApi() => {
        'id': id,
        'entidade': entidade.chave,
        'entidadeId': entidadeId,
        'acao': acao.chave,
        'ocorridoEm': ocorridoEm.toUtc().toIso8601String(),
        // Campos internos (prefixo _) são só para a UI da fila.
        'dados': Map.fromEntries(
          dados.entries.where((e) => !e.key.startsWith('_')),
        ),
      };

  Map<String, dynamic> paraBanco() => {
        'id': id,
        'entidade': entidade.chave,
        'entidadeId': entidadeId,
        'acao': acao.chave,
        'ocorridoEm': ocorridoEm.toIso8601String(),
        'dados': dados,
      };

  factory OperacaoPendente.doBanco(Map<String, dynamic> json) =>
      OperacaoPendente(
        id: json['id'] as String,
        entidade: EntidadeSync.values
            .firstWhere((e) => e.chave == json['entidade']),
        entidadeId: json['entidadeId'] as String,
        acao: AcaoSync.values.firstWhere((a) => a.chave == json['acao']),
        ocorridoEm: DateTime.parse(json['ocorridoEm'] as String),
        dados: Map<String, dynamic>.from(json['dados'] as Map? ?? {}),
      );
}

/// Fila de saída (outbox).
///
/// Toda alteração é gravada aqui ANTES de tentar a rede. É o que garante que
/// nada se perde quando o sinal cai no meio do corredor — e o `id` próprio de
/// cada operação é o que garante que reenviar o lote não duplica nada no
/// servidor.
class FilaSincronizacao {
  /// Enfileira uma alteração. Se já existe uma operação pendente para o mesmo
  /// registro e a mesma ação, ela é substituída: o que importa é o estado
  /// final do item, não cada toque no botão de quantidade.
  static Future<void> enfileirar({
    required EntidadeSync entidade,
    required String entidadeId,
    required AcaoSync acao,
    Map<String, dynamic> dados = const {},
  }) async {
    final db = await BancoLocal.instancia;
    final op = OperacaoPendente(
      id: novoId(),
      entidade: entidade,
      entidadeId: entidadeId,
      acao: acao,
      ocorridoEm: DateTime.now(),
      dados: dados,
    );

    await db.transaction((txn) async {
      // Excluir vence tudo que estava pendente para aquele registro: não faz
      // sentido enviar a edição de um item que o usuário acabou de apagar.
      if (acao == AcaoSync.excluir) {
        await BancoLocal.fila.delete(
          txn,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('entidadeId', entidadeId),
              Filter.notEquals('acao', AcaoSync.criar.chave),
            ]),
          ),
        );
      } else {
        await BancoLocal.fila.delete(
          txn,
          finder: Finder(
            filter: Filter.and([
              Filter.equals('entidadeId', entidadeId),
              Filter.equals('acao', acao.chave),
            ]),
          ),
        );
      }
      await BancoLocal.fila.record(op.id).put(txn, op.paraBanco());
    });
  }

  /// Operações pendentes em ordem cronológica — a lista precisa ser criada
  /// antes dos itens dela.
  static Future<List<OperacaoPendente>> pendentes({int limite = 400}) async {
    final db = await BancoLocal.instancia;
    final registros = await BancoLocal.fila.find(
      db,
      finder: Finder(
        sortOrders: [SortOrder('ocorridoEm')],
        limit: limite,
      ),
    );
    return registros
        .map((r) => OperacaoPendente.doBanco(Map<String, dynamic>.from(r.value)))
        .toList();
  }

  static Future<int> quantidade() async {
    final db = await BancoLocal.instancia;
    return BancoLocal.fila.count(db);
  }

  /// Remove da fila só o que o servidor confirmou ter aplicado (ou já
  /// conhecia). O que falhou permanece para a próxima tentativa.
  static Future<void> confirmar(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await BancoLocal.instancia;
    await BancoLocal.fila.records(ids).delete(db);
  }

  static Future<void> limpar() async {
    final db = await BancoLocal.instancia;
    await BancoLocal.fila.delete(db);
  }
}
