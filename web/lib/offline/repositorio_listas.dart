import 'package:sembast/sembast.dart';

import '../globais/parametros_globais.dart';
import '../models/basicos_model.dart';
import '../models/lista_model.dart';
import '../models/produto_model.dart';
import 'banco_local.dart';
import 'fila_sincronizacao.dart';

/// Repositório offline-first.
///
/// A regra é uma só: **grava local, enfileira, devolve na hora**. A tela nunca
/// espera a rede — nem para marcar um item como comprado, nem para ver o total
/// mudar. O sincronizador leva a fila para o servidor quando puder.
class RepositorioListas {
  // ── Leitura ────────────────────────────────────────────────────────

  static Future<List<ListaModel>> listas() async {
    final db = await BancoLocal.instancia;
    final registros = await BancoLocal.listas.find(
      db,
      finder: Finder(sortOrders: [SortOrder('data', false)]),
    );
    return registros
        .map((r) => ListaModel.fromJson(Map<String, dynamic>.from(r.value)))
        .toList();
  }

  static Future<ListaModel?> lista(String id) async {
    final db = await BancoLocal.instancia;
    final valor = await BancoLocal.listas.record(id).get(db);
    if (valor == null) return null;
    return ListaModel.fromJson(Map<String, dynamic>.from(valor));
  }

  static Future<ListaModel?> emCompra() async {
    final todas = await listas();
    for (final l in todas) {
      if (l.status == StatusLista.emCompra) return l;
    }
    return null;
  }

  static Future<ListaModel?> ultimaFinalizada() async {
    final todas = await listas();
    final finalizadas =
        todas.where((l) => l.status == StatusLista.finalizada).toList()
          ..sort((a, b) => (b.finalizadaEm ?? b.data)
              .compareTo(a.finalizadaEm ?? a.data));
    return finalizadas.isEmpty ? null : finalizadas.first;
  }

  static Future<void> salvarLocal(ListaModel lista) async {
    final db = await BancoLocal.instancia;
    await BancoLocal.listas.record(lista.id).put(db, lista.toJson());
  }

  static Future<void> removerLocal(String id) async {
    final db = await BancoLocal.instancia;
    await BancoLocal.listas.record(id).delete(db);
  }

  // ── Escrita (local primeiro, sempre) ───────────────────────────────

  static Future<ListaModel> criarLista({
    required String nome,
    DateTime? data,
    String? observacao,
    double? orcamento,
    String? mercadoId,
    String? mercadoNome,
    ListaModel? copiarDe,
  }) async {
    final id = novoId();
    final quando = data ?? DateTime.now();

    // Repetir lista: traz os produtos, usa o preço PAGO antes apenas como
    // estimativa, e zera quantidade e preço realizados.
    final itens = <ListaItemModel>[];
    if (copiarDe != null) {
      for (final (i, item) in copiarDe.itens.indexed) {
        itens.add(ListaItemModel(
          id: novoId(),
          listaId: id,
          produtoId: item.produtoId,
          nomeLivre: item.nomeLivre,
          categoriaId: item.categoriaId,
          categoriaNome: item.categoriaNome,
          categoriaOrdem: item.categoriaOrdem,
          unidade: item.unidade,
          ordem: i,
          quantidadePlanejada: item.quantidadePlanejada,
          precoEstimado: item.precoUnitario ?? item.precoEstimado,
          produto: item.produto,
        ));
      }
    }

    final lista = ListaModel(
      id: id,
      nome: nome,
      data: quando,
      observacao: observacao,
      orcamento: orcamento,
      mercadoId: mercadoId,
      mercadoNome: mercadoNome,
      itens: itens,
      totais: TotaisLista.calcular(itens, orcamento: orcamento),
    );

    await salvarLocal(lista);
    await FilaSincronizacao.enfileirar(
      entidade: EntidadeSync.lista,
      entidadeId: id,
      acao: AcaoSync.criar,
      dados: {
        'nome': nome,
        'data': quando.toIso8601String(),
        'observacao': observacao,
        'orcamento': orcamento,
        'mercadoId': mercadoId,
        'status': StatusLista.rascunho.paraApi,
      },
    );
    for (final item in itens) {
      await _enfileirarItem(item, AcaoSync.criar);
    }
    return lista;
  }

  static Future<ListaModel> atualizarLista(
    ListaModel lista, {
    String? nome,
    double? orcamento,
    String? mercadoId,
    String? mercadoNome,
    StatusLista? status,
  }) async {
    final nova = lista.copyWith(
      nome: nome,
      orcamento: orcamento,
      mercadoId: mercadoId,
      mercadoNome: mercadoNome,
      status: status,
      finalizadaEm:
          status == StatusLista.finalizada ? DateTime.now() : lista.finalizadaEm,
    );
    await salvarLocal(nova);
    await FilaSincronizacao.enfileirar(
      entidade: EntidadeSync.lista,
      entidadeId: lista.id,
      acao: AcaoSync.atualizar,
      dados: {
        'nome': nova.nome,
        'orcamento': nova.orcamento,
        'mercadoId': nova.mercadoId,
        'status': nova.status.paraApi,
        if (nova.finalizadaEm != null)
          'finalizadaEm': nova.finalizadaEm!.toIso8601String(),
      },
    );
    return nova;
  }

  static Future<void> excluirLista(String id) async {
    await removerLocal(id);
    await FilaSincronizacao.enfileirar(
      entidade: EntidadeSync.lista,
      entidadeId: id,
      acao: AcaoSync.excluir,
    );
  }

  // ── Itens ──────────────────────────────────────────────────────────

  static Future<ListaModel> adicionarItem(
    ListaModel lista, {
    ProdutoModel? produto,
    String? nomeLivre,
    double quantidade = 1,
    double? precoEstimado,
    OrigemItem origem = OrigemItem.planejado,
    String? categoriaId,
    String? categoriaNome,
    int categoriaOrdem = 999,
  }) async {
    final item = ListaItemModel(
      id: novoId(),
      listaId: lista.id,
      produtoId: produto?.id,
      nomeLivre: produto == null ? nomeLivre : null,
      categoriaId: categoriaId ?? produto?.categoriaId,
      categoriaNome: categoriaNome ?? produto?.categoriaNome,
      categoriaOrdem: categoriaOrdem,
      origem: origem,
      unidade: produto?.tipoVenda.unidadePadrao ?? 'un',
      ordem: lista.itens.length,
      quantidadePlanejada: quantidade,
      precoEstimado: precoEstimado,
      produto: produto,
    );

    final nova = lista.copyWith(itens: [...lista.itens, item]);
    await salvarLocal(nova);
    await _enfileirarItem(item, AcaoSync.criar);
    return nova;
  }

  /// Registra a compra do item: quantidade, preço pago e total congelado.
  ///
  /// O total é calculado aqui e guardado no item (regra 6/7) — mexer no
  /// produto depois nunca altera uma compra já feita.
  static Future<ListaModel> registrarCompra(
    ListaModel lista,
    ListaItemModel item, {
    required double quantidade,
    required double precoUnitario,
  }) async {
    final total = ((quantidade * precoUnitario) * 100).round() / 100;
    final atualizado = item.copyWith(
      comprado: true,
      quantidade: quantidade,
      precoUnitario: precoUnitario,
      total: total,
    );
    return _substituirItem(lista, atualizado, AcaoSync.atualizar);
  }

  /// Desfazer. Limpa os valores realizados — senão o total continuaria
  /// somando um item que saiu do carrinho.
  static Future<ListaModel> desmarcarCompra(
    ListaModel lista,
    ListaItemModel item,
  ) async {
    final atualizado = item.copyWith(limparCompra: true);
    return _substituirItem(lista, atualizado, AcaoSync.atualizar);
  }

  static Future<ListaModel> alterarPlanejado(
    ListaModel lista,
    ListaItemModel item, {
    double? quantidadePlanejada,
    double? precoEstimado,
    String? unidade,
    String? nomeLivre,
  }) async {
    final atualizado = item.copyWith(
      quantidadePlanejada: quantidadePlanejada,
      precoEstimado: precoEstimado,
      unidade: unidade,
      nomeLivre: nomeLivre,
    );
    return _substituirItem(lista, atualizado, AcaoSync.atualizar);
  }

  static Future<ListaModel> removerItem(
    ListaModel lista,
    ListaItemModel item,
  ) async {
    final itens = lista.itens.where((i) => i.id != item.id).toList();
    final nova = lista.copyWith(itens: itens);
    await salvarLocal(nova);
    await FilaSincronizacao.enfileirar(
      entidade: EntidadeSync.listaItem,
      entidadeId: item.id,
      acao: AcaoSync.excluir,
      dados: {'_rotulo': item.nome},
    );
    return nova;
  }

  static Future<ListaModel> _substituirItem(
    ListaModel lista,
    ListaItemModel item,
    AcaoSync acao,
  ) async {
    final itens = lista.itens.map((i) => i.id == item.id ? item : i).toList();
    final nova = lista.copyWith(itens: itens);
    await salvarLocal(nova);
    await _enfileirarItem(item, acao);
    return nova;
  }

  static Future<void> _enfileirarItem(
    ListaItemModel item,
    AcaoSync acao,
  ) async {
    await FilaSincronizacao.enfileirar(
      entidade: EntidadeSync.listaItem,
      entidadeId: item.id,
      acao: acao,
      dados: {
        'listaId': item.listaId,
        'produtoId': item.produtoId,
        'nomeLivre': item.nomeLivre,
        'categoriaId': item.categoriaId,
        'origem': item.origem.paraApi,
        'unidade': item.unidade,
        'ordem': item.ordem,
        'quantidadePlanejada': item.quantidadePlanejada,
        'precoEstimado': item.precoEstimado,
        'comprado': item.comprado,
        'quantidade': item.quantidade,
        'precoUnitario': item.precoUnitario,
        if (item.compradoEm != null)
          'compradoEm': item.compradoEm!.toIso8601String(),
        '_rotulo': item.nome,
      },
    );
  }

  // ── Catálogo local ─────────────────────────────────────────────────

  static Future<void> salvarProdutos(List<ProdutoModel> produtos) async {
    if (produtos.isEmpty) return;
    final db = await BancoLocal.instancia;
    await db.transaction((txn) async {
      for (final p in produtos) {
        await BancoLocal.produtos.record(p.id).put(txn, p.toJson());
      }
    });
  }

  /// Busca no catálogo local — é o primeiro degrau da cascata e o único que
  /// funciona sem conexão.
  static Future<ProdutoModel?> produtoPorEan(String ean) async {
    final db = await BancoLocal.instancia;
    final achados = await BancoLocal.produtos.find(
      db,
      finder: Finder(filter: Filter.equals('ean', ean), limit: 1),
    );
    if (achados.isEmpty) return null;
    return ProdutoModel.fromJson(Map<String, dynamic>.from(achados.first.value));
  }

  static Future<List<ProdutoModel>> buscarProdutos(String termo,
      {int limite = 30}) async {
    final db = await BancoLocal.instancia;
    final alvo = termo.trim().toLowerCase();
    final todos = await BancoLocal.produtos.find(db);
    final achados = todos
        .map((r) => ProdutoModel.fromJson(Map<String, dynamic>.from(r.value)))
        .where((p) =>
            alvo.isEmpty ||
            p.nome.toLowerCase().contains(alvo) ||
            (p.marca ?? '').toLowerCase().contains(alvo))
        .take(limite)
        .toList();
    achados.sort((a, b) => a.nome.compareTo(b.nome));
    return achados;
  }

  static Future<List<CategoriaModel>> categorias() async {
    final db = await BancoLocal.instancia;
    final registros = await BancoLocal.categorias.find(
      db,
      finder: Finder(sortOrders: [SortOrder('ordem')]),
    );
    return registros
        .map((r) => CategoriaModel.fromJson(Map<String, dynamic>.from(r.value)))
        .toList();
  }

  static Future<void> salvarCategorias(List<CategoriaModel> categorias) async {
    if (categorias.isEmpty) return;
    final db = await BancoLocal.instancia;
    await db.transaction((txn) async {
      for (final c in categorias) {
        await BancoLocal.categorias.record(c.id).put(txn, c.toJson());
      }
    });
  }

  static Future<List<MercadoModel>> mercados() async {
    final db = await BancoLocal.instancia;
    final registros = await BancoLocal.mercados.find(
      db,
      finder: Finder(sortOrders: [SortOrder('nome')]),
    );
    return registros
        .map((r) => MercadoModel.fromJson(Map<String, dynamic>.from(r.value)))
        .toList();
  }

  static Future<void> salvarMercados(List<MercadoModel> mercados) async {
    if (mercados.isEmpty) return;
    final db = await BancoLocal.instancia;
    await db.transaction((txn) async {
      for (final m in mercados) {
        await BancoLocal.mercados.record(m.id).put(txn, m.toJson());
      }
    });
  }

  /// Produto cadastrado no corredor, sem conexão. Vai para o catálogo global
  /// assim que a fila subir.
  static Future<ProdutoModel> criarProdutoLocal({
    required String nome,
    String? ean,
    String? marca,
    TipoVenda tipoVenda = TipoVenda.unidade,
    String? categoriaId,
    String? categoriaNome,
  }) async {
    final produto = ProdutoModel(
      id: novoId(),
      ean: ean,
      nome: nome,
      marca: marca,
      tipoVenda: tipoVenda,
      unidade: tipoVenda.unidadePadrao,
      categoriaId: categoriaId,
      categoriaNome: categoriaNome,
    );
    await salvarProdutos([produto]);
    await FilaSincronizacao.enfileirar(
      entidade: EntidadeSync.produto,
      entidadeId: produto.id,
      acao: AcaoSync.criar,
      dados: {
        'ean': ean,
        'nome': nome,
        'marca': marca,
        'tipoVenda': tipoVenda.paraApi,
        'unidade': produto.unidade,
        'categoriaId': categoriaId,
      },
    );
    return produto;
  }
}
