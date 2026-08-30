import 'dart:async';
import 'dart:convert';

// Necessário mesmo parecendo redundante: os métodos de RecordRef (.delete,
// .put) são extensões, e extensão só vale no arquivo que a importa.
import 'package:sembast/sembast.dart';

import '../globais/http_interceptor.dart';
import '../globais/parametros_globais.dart';
import '../models/basicos_model.dart';
import '../models/lista_model.dart';
import '../models/produto_model.dart';
import 'banco_local.dart';
import 'fila_sincronizacao.dart';
import 'repositorio_listas.dart';

enum EstadoSincronizacao { ocioso, enviando, offline, erro }

class ResultadoSync {
  final bool sucesso;
  final int enviadas;
  final int pendentes;
  final String? erro;

  const ResultadoSync({
    required this.sucesso,
    this.enviadas = 0,
    this.pendentes = 0,
    this.erro,
  });
}

/// Leva a fila local para o servidor e traz o delta de volta.
///
/// Uma viagem só: o POST manda as operações pendentes e já recebe as
/// alterações feitas em outro aparelho desde o último cursor.
class Sincronizador {
  static final _client = AutenticacaoInterceptor();

  /// Evita duas sincronizações concorrentes — que enviariam a mesma fila duas
  /// vezes e desperdiçariam a viagem.
  static Future<ResultadoSync>? _emAndamento;

  static final _estado = StreamController<EstadoSincronizacao>.broadcast();
  static Stream<EstadoSincronizacao> get estado => _estado.stream;
  static DateTime? ultimaSincronizacao;

  static Future<ResultadoSync> sincronizar() =>
      _emAndamento ??= _executar().whenComplete(() => _emAndamento = null);

  static Future<ResultadoSync> _executar() async {
    // Convidado não tem token: os dados ficam no aparelho até virar conta.
    if (!ParametrosGlobais.temConta) {
      return const ResultadoSync(sucesso: false, erro: 'Sem conta');
    }

    _estado.add(EstadoSincronizacao.enviando);
    final pendentes = await FilaSincronizacao.pendentes();
    final cursor = await Sessao.cursor();

    try {
      final resposta = await _client.post(
        Uri.parse('${ParametrosGlobais.apiBase}/sincronizacao'),
        body: jsonEncode({
          'operacoes': pendentes.map((o) => o.paraApi()).toList(),
          'desde': ?cursor,
        }),
      );

      if (!sucesso(resposta)) {
        _estado.add(EstadoSincronizacao.erro);
        return ResultadoSync(
          sucesso: false,
          pendentes: pendentes.length,
          erro: mensagemDeErro(resposta),
        );
      }

      final corpo =
          jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;

      // Sai da fila o que o servidor confirmou. O que falhou por algo
      // passageiro fica para a próxima tentativa — perder uma alteração é
      // pior do que reenviá-la.
      final resolvidas = <String>[
        ...(corpo['aplicadas'] as List? ?? <dynamic>[]).cast<String>(),
        ...(corpo['ignoradas'] as List? ?? <dynamic>[]).cast<String>(),
        // Falha permanente também sai: reenviar não muda o resultado, e
        // mantê-la deixaria o contador de pendentes travado para sempre.
        ...(corpo['falhas'] as List? ?? <dynamic>[])
            .whereType<Map>()
            .where((f) => f['permanente'] == true)
            .map((f) => f['id'] as String),
      ];
      await FilaSincronizacao.confirmar(resolvidas);

      await _aplicarDelta(corpo['alteracoes']);

      final servidorEm = corpo['servidorEm'] as String?;
      if (servidorEm != null) await Sessao.salvarCursor(servidorEm);

      ultimaSincronizacao = DateTime.now();
      _estado.add(EstadoSincronizacao.ocioso);
      return ResultadoSync(
        sucesso: true,
        enviadas: resolvidas.length,
        pendentes: await FilaSincronizacao.quantidade(),
      );
    } on SemConexaoException {
      // Offline não é erro: a fila continua guardada e sobe na próxima.
      _estado.add(EstadoSincronizacao.offline);
      return ResultadoSync(
        sucesso: false,
        pendentes: pendentes.length,
        erro: 'Sem conexão',
      );
    } catch (e) {
      _estado.add(EstadoSincronizacao.erro);
      return ResultadoSync(
        sucesso: false,
        pendentes: pendentes.length,
        erro: e.toString(),
      );
    }
  }

  /// Aplica no banco local o que veio do servidor.
  ///
  /// O delta chega normalizado — `lista_itens` traz só `produtoId` e
  /// `categoriaId`, sem o produto nem a categoria aninhados. Por isso os itens
  /// são **hidratados** aqui com o catálogo local antes de virar o documento
  /// que a tela lê; sem esse passo todo item apareceria como "Item" na
  /// categoria "Outros".
  static Future<void> _aplicarDelta(dynamic alteracoes) async {
    if (alteracoes is! Map) return;
    final db = await BancoLocal.instancia;

    await RepositorioListas.salvarCategorias(
      (alteracoes['categorias'] as List? ?? [])
          .map((e) => CategoriaModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
    await RepositorioListas.salvarMercados(
      (alteracoes['mercados'] as List? ?? [])
          .map((e) => MercadoModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
    await RepositorioListas.salvarProdutos(
      (alteracoes['produtos'] as List? ?? [])
          .map((e) => ProdutoModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );

    // Catálogo local inteiro, para resolver as referências dos itens.
    final produtos = {
      for (final p in await RepositorioListas.buscarProdutos('', limite: 5000))
        p.id: p,
    };
    final categorias = {
      for (final c in await RepositorioListas.categorias()) c.id: c,
    };
    final mercados = {
      for (final m in await RepositorioListas.mercados()) m.id: m,
    };

    final itensPorLista = <String, List<ListaItemModel>>{};
    for (final bruto in (alteracoes['itens'] as List? ?? [])) {
      final json = Map<String, dynamic>.from(bruto);
      if (json['excluidoEm'] != null) continue; // tombstone
      final item = ListaItemModel.fromJson(
        _hidratar(json, produtos, categorias),
      );
      itensPorLista.putIfAbsent(item.listaId, () => []).add(item);
    }

    for (final bruto in (alteracoes['listas'] as List? ?? [])) {
      final json = Map<String, dynamic>.from(bruto);
      final id = json['id'] as String;

      // Tombstone: lista apagada em outro aparelho sai daqui também. Sem
      // isso, ela ressuscitaria a cada sincronização.
      if (json['excluidoEm'] != null) {
        await BancoLocal.listas.record(id).delete(db);
        continue;
      }

      final existente = await RepositorioListas.lista(id);
      final novos = itensPorLista[id];
      // Só troca os itens quando o servidor mandou itens dessa lista; senão
      // preserva o que já está local (o delta pode não ter tocado neles).
      final itens = novos ?? existente?.itens ?? const <ListaItemModel>[];
      final mercado = mercados[json['mercadoId']];

      final lista = ListaModel.fromJson({
        ...json,
        'itens': itens.map((i) => i.toJson()).toList(),
        'mercado': mercado == null
            ? (existente?.mercadoNome == null
                ? null
                : {'nome': existente!.mercadoNome})
            : {'nome': mercado.nome},
      });
      await RepositorioListas.salvarLocal(lista);
    }
  }

  /// Preenche produto e categoria do item a partir do catálogo local.
  ///
  /// A categoria do item vem do próprio item quando ele tem uma; senão herda
  /// a do produto — é o que faz o agrupamento por corredor funcionar em vez
  /// de jogar tudo em "Outros".
  static Map<String, dynamic> _hidratar(
    Map<String, dynamic> json,
    Map<String, ProdutoModel> produtos,
    Map<String, CategoriaModel> categorias,
  ) {
    final produto = produtos[json['produtoId']];
    final categoriaId = json['categoriaId'] ?? produto?.categoriaId;
    final categoria = categorias[categoriaId];

    return {
      ...json,
      if (produto != null) 'produto': produto.toJson(),
      'categoriaId': categoriaId,
      if (categoria != null)
        'categoria': {'nome': categoria.nome, 'ordem': categoria.ordem},
    };
  }

  /// Primeira carga: traz tudo do servidor para o banco local.
  static Future<bool> cargaInicial() async {
    try {
      final resposta = await _client
          .get(Uri.parse('${ParametrosGlobais.apiBase}/sincronizacao'));
      if (!sucesso(resposta)) return false;
      await _aplicarDelta(
        jsonDecode(utf8.decode(resposta.bodyBytes)),
      );
      await Sessao.salvarCursor(DateTime.now().toUtc().toIso8601String());
      ultimaSincronizacao = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }
}
