import 'parse.dart';
import 'produto_model.dart';

enum StatusLista {
  rascunho,
  emCompra,
  finalizada;

  static StatusLista deTexto(dynamic v) {
    switch (parseString(v).toUpperCase()) {
      case 'EM_COMPRA':
        return StatusLista.emCompra;
      case 'FINALIZADA':
        return StatusLista.finalizada;
      default:
        return StatusLista.rascunho;
    }
  }

  String get paraApi => switch (this) {
        StatusLista.emCompra => 'EM_COMPRA',
        StatusLista.finalizada => 'FINALIZADA',
        StatusLista.rascunho => 'RASCUNHO',
      };

  String get rotulo => switch (this) {
        StatusLista.emCompra => 'em compra',
        StatusLista.finalizada => 'finalizada',
        StatusLista.rascunho => 'rascunho',
      };
}

/// Regra 12: produto não planejado é contabilizado à parte no resumo.
enum OrigemItem {
  planejado,
  extra;

  static OrigemItem deTexto(dynamic v) =>
      parseString(v).toUpperCase() == 'EXTRA'
          ? OrigemItem.extra
          : OrigemItem.planejado;

  String get paraApi => this == OrigemItem.extra ? 'EXTRA' : 'PLANEJADO';
  bool get ehExtra => this == OrigemItem.extra;
}

class ListaItemModel {
  final String id;
  final String listaId;
  final String? produtoId;
  final String? nomeLivre;
  final String? categoriaId;
  final String? categoriaNome;
  final int categoriaOrdem;
  final OrigemItem origem;
  final String unidade;
  final int ordem;

  final double quantidadePlanejada;
  final double? precoEstimado;

  final bool comprado;
  final double? quantidade;
  final double? precoUnitario;
  final double? total;
  final DateTime? compradoEm;

  final ProdutoModel? produto;
  final String? observacao;

  const ListaItemModel({
    required this.id,
    required this.listaId,
    this.produtoId,
    this.nomeLivre,
    this.categoriaId,
    this.categoriaNome,
    this.categoriaOrdem = 999,
    this.origem = OrigemItem.planejado,
    this.unidade = 'un',
    this.ordem = 0,
    this.quantidadePlanejada = 1,
    this.precoEstimado,
    this.comprado = false,
    this.quantidade,
    this.precoUnitario,
    this.total,
    this.compradoEm,
    this.produto,
    this.observacao,
  });

  String get nome => produto?.nome ?? nomeLivre ?? 'Item';
  String? get marca => produto?.marca;
  TipoVenda get tipoVenda => produto?.tipoVenda ?? TipoVenda.unidade;
  bool get ehPeso => tipoVenda.ehPeso || unidade == 'kg';

  /// Quantidade que vale agora: a comprada se já passou pelo carrinho,
  /// senão a planejada.
  double get quantidadeAtual => quantidade ?? quantidadePlanejada;

  /// Quanto o item deveria custar pelo preço estimado.
  double get totalEstimado => (precoEstimado ?? 0) * quantidadeAtual;

  /// Positivo = economizou. Só faz sentido depois de comprado.
  double? get diferenca {
    if (!comprado || precoEstimado == null || total == null) return null;
    return double.parse((totalEstimado - total!).toStringAsFixed(2));
  }

  ListaItemModel copyWith({
    bool? comprado,
    double? quantidade,
    double? precoUnitario,
    double? total,
    double? quantidadePlanejada,
    double? precoEstimado,
    String? unidade,
    String? nomeLivre,
    bool limparCompra = false,
  }) =>
      ListaItemModel(
        id: id,
        listaId: listaId,
        produtoId: produtoId,
        nomeLivre: nomeLivre ?? this.nomeLivre,
        categoriaId: categoriaId,
        categoriaNome: categoriaNome,
        categoriaOrdem: categoriaOrdem,
        origem: origem,
        unidade: unidade ?? this.unidade,
        ordem: ordem,
        quantidadePlanejada: quantidadePlanejada ?? this.quantidadePlanejada,
        precoEstimado: precoEstimado ?? this.precoEstimado,
        comprado: limparCompra ? false : (comprado ?? this.comprado),
        quantidade: limparCompra ? null : (quantidade ?? this.quantidade),
        precoUnitario:
            limparCompra ? null : (precoUnitario ?? this.precoUnitario),
        total: limparCompra ? null : (total ?? this.total),
        compradoEm: limparCompra ? null : compradoEm,
        produto: produto,
        observacao: observacao,
      );

  factory ListaItemModel.fromJson(Map<String, dynamic> json) {
    final categoria = json['categoria'];
    final produtoJson = json['produto'];
    return ListaItemModel(
      id: parseString(json['id']),
      listaId: parseString(json['listaId']),
      produtoId: parseStringOpt(json['produtoId']),
      nomeLivre: parseStringOpt(json['nomeLivre']),
      categoriaId: parseStringOpt(json['categoriaId']),
      categoriaNome: categoria is Map ? parseStringOpt(categoria['nome']) : null,
      categoriaOrdem: categoria is Map ? parseInt(categoria['ordem'], padrao: 999) : 999,
      origem: OrigemItem.deTexto(json['origem']),
      unidade: parseString(json['unidade'], padrao: 'un'),
      ordem: parseInt(json['ordem']),
      quantidadePlanejada: parseDouble(json['quantidadePlanejada'], padrao: 1),
      precoEstimado: parseDoubleOpt(json['precoEstimado']),
      comprado: parseBool(json['comprado']),
      quantidade: parseDoubleOpt(json['quantidade']),
      precoUnitario: parseDoubleOpt(json['precoUnitario']),
      total: parseDoubleOpt(json['total']),
      compradoEm: DateTime.tryParse(parseString(json['compradoEm']))?.toLocal(),
      produto: produtoJson is Map
          ? ProdutoModel.fromJson(Map<String, dynamic>.from(produtoJson))
          : null,
      observacao: parseStringOpt(json['observacao']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'listaId': listaId,
        'produtoId': produtoId,
        'nomeLivre': nomeLivre,
        'categoriaId': categoriaId,
        'categoria': categoriaNome == null
            ? null
            : {'nome': categoriaNome, 'ordem': categoriaOrdem},
        'origem': origem.paraApi,
        'unidade': unidade,
        'ordem': ordem,
        'quantidadePlanejada': quantidadePlanejada,
        'precoEstimado': precoEstimado,
        'comprado': comprado,
        'quantidade': quantidade,
        'precoUnitario': precoUnitario,
        'total': total,
        'compradoEm': compradoEm?.toIso8601String(),
        'produto': produto?.toJson(),
        'observacao': observacao,
      };
}

/// Totais da compra, calculados no servidor e recalculados localmente quando
/// o app está offline — as duas contas precisam bater.
class TotaisLista {
  final double totalPago;
  final double totalEstimado;
  final double economia;
  final double totalPlanejados;
  final double totalExtras;
  final int itensComprados;
  final int itensPendentes;
  final int itensExtras;
  final double? orcamento;
  final double? saldoOrcamento;

  const TotaisLista({
    this.totalPago = 0,
    this.totalEstimado = 0,
    this.economia = 0,
    this.totalPlanejados = 0,
    this.totalExtras = 0,
    this.itensComprados = 0,
    this.itensPendentes = 0,
    this.itensExtras = 0,
    this.orcamento,
    this.saldoOrcamento,
  });

  /// Fração do orçamento já gasta (0..1+). Null quando não há orçamento.
  double? get fracaoOrcamento {
    if (orcamento == null || orcamento == 0) return null;
    return totalPago / orcamento!;
  }

  bool get estourou => saldoOrcamento != null && saldoOrcamento! < 0;

  factory TotaisLista.fromJson(Map<String, dynamic> json) => TotaisLista(
        totalPago: parseDouble(json['totalPago']),
        totalEstimado: parseDouble(json['totalEstimado']),
        economia: parseDouble(json['economia']),
        totalPlanejados: parseDouble(json['totalPlanejados']),
        totalExtras: parseDouble(json['totalExtras']),
        itensComprados: parseInt(json['itensComprados']),
        itensPendentes: parseInt(json['itensPendentes']),
        itensExtras: parseInt(json['itensExtras']),
        orcamento: parseDoubleOpt(json['orcamento']),
        saldoOrcamento: parseDoubleOpt(json['saldoOrcamento']),
      );

  Map<String, dynamic> toJson() => {
        'totalPago': totalPago,
        'totalEstimado': totalEstimado,
        'economia': economia,
        'totalPlanejados': totalPlanejados,
        'totalExtras': totalExtras,
        'itensComprados': itensComprados,
        'itensPendentes': itensPendentes,
        'itensExtras': itensExtras,
        'orcamento': orcamento,
        'saldoOrcamento': saldoOrcamento,
      };

  /// Recalcula os totais a partir dos itens. É o que mantém o número da tela
  /// correto quando o app está sem conexão — a conta local precisa ser a
  /// mesma que a do servidor, senão o total pisca ao sincronizar.
  factory TotaisLista.calcular(
    List<ListaItemModel> itens, {
    double? orcamento,
  }) {
    double planejados = 0;
    double extras = 0;
    double estimadoTotal = 0;
    double estimadoComprados = 0;
    int comprados = 0;
    int pendentes = 0;
    int qtdExtras = 0;

    for (final i in itens) {
      final total = i.total ?? 0;
      if (i.origem.ehExtra) {
        qtdExtras++;
        extras += total;
      } else {
        estimadoTotal += (i.precoEstimado ?? 0) * i.quantidadePlanejada;
        if (i.comprado) {
          planejados += total;
          estimadoComprados += i.totalEstimado;
        }
      }
      if (i.comprado) {
        comprados++;
      } else if (!i.origem.ehExtra) {
        pendentes++;
      }
    }

    final pago = _cent(planejados + extras);
    return TotaisLista(
      totalPago: pago,
      totalEstimado: _cent(estimadoTotal),
      economia: _cent(estimadoComprados - planejados),
      totalPlanejados: _cent(planejados),
      totalExtras: _cent(extras),
      itensComprados: comprados,
      itensPendentes: pendentes,
      itensExtras: qtdExtras,
      orcamento: orcamento,
      saldoOrcamento: orcamento == null ? null : _cent(orcamento - pago),
    );
  }
}

double _cent(double v) => (v * 100).round() / 100;

class ListaModel {
  final String id;
  final String nome;
  final DateTime data;
  final String? observacao;
  final double? orcamento;
  final String? mercadoId;
  final String? mercadoNome;
  final StatusLista status;
  final DateTime? finalizadaEm;
  final List<ListaItemModel> itens;
  final TotaisLista totais;

  const ListaModel({
    required this.id,
    required this.nome,
    required this.data,
    this.observacao,
    this.orcamento,
    this.mercadoId,
    this.mercadoNome,
    this.status = StatusLista.rascunho,
    this.finalizadaEm,
    this.itens = const [],
    this.totais = const TotaisLista(),
  });

  List<ListaItemModel> get pendentes =>
      itens.where((i) => !i.comprado && !i.origem.ehExtra).toList();
  List<ListaItemModel> get comprados => itens.where((i) => i.comprado).toList();
  List<ListaItemModel> get extras =>
      itens.where((i) => i.origem.ehExtra).toList();

  ListaItemModel? itemDoProduto(String produtoId) {
    for (final i in itens) {
      if (i.produtoId == produtoId) return i;
    }
    return null;
  }

  /// Itens agrupados por categoria, na ordem do corredor.
  List<MapEntry<String, List<ListaItemModel>>> agrupadoPorCategoria(
    List<ListaItemModel> lista,
  ) {
    final grupos = <String, List<ListaItemModel>>{};
    final ordens = <String, int>{};
    for (final i in lista) {
      final nome = i.categoriaNome ?? 'Outros';
      grupos.putIfAbsent(nome, () => []).add(i);
      ordens[nome] = i.categoriaOrdem;
    }
    final chaves = grupos.keys.toList()
      ..sort((a, b) => (ordens[a] ?? 999).compareTo(ordens[b] ?? 999));
    return chaves.map((k) => MapEntry(k, grupos[k]!)).toList();
  }

  ListaModel copyWith({
    String? nome,
    double? orcamento,
    String? mercadoId,
    String? mercadoNome,
    StatusLista? status,
    List<ListaItemModel>? itens,
    DateTime? finalizadaEm,
  }) {
    final novosItens = itens ?? this.itens;
    final novoOrcamento = orcamento ?? this.orcamento;
    return ListaModel(
      id: id,
      nome: nome ?? this.nome,
      data: data,
      observacao: observacao,
      orcamento: novoOrcamento,
      mercadoId: mercadoId ?? this.mercadoId,
      mercadoNome: mercadoNome ?? this.mercadoNome,
      status: status ?? this.status,
      finalizadaEm: finalizadaEm ?? this.finalizadaEm,
      itens: novosItens,
      // Recalcula sempre que a lista muda: é o total que fica na tela.
      totais: TotaisLista.calcular(novosItens, orcamento: novoOrcamento),
    );
  }

  factory ListaModel.fromJson(Map<String, dynamic> json) {
    final mercado = json['mercado'];
    final itens = (json['itens'] as List? ?? [])
        .map((e) => ListaItemModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final orcamento = parseDoubleOpt(json['orcamento']);
    return ListaModel(
      id: parseString(json['id']),
      nome: parseString(json['nome']),
      data: DateTime.tryParse(parseString(json['data']))?.toLocal() ??
          DateTime.now(),
      observacao: parseStringOpt(json['observacao']),
      orcamento: orcamento,
      mercadoId: parseStringOpt(json['mercadoId']),
      mercadoNome: mercado is Map ? parseStringOpt(mercado['nome']) : null,
      status: StatusLista.deTexto(json['status']),
      finalizadaEm:
          DateTime.tryParse(parseString(json['finalizadaEm']))?.toLocal(),
      itens: itens,
      totais: json['totais'] is Map
          ? TotaisLista.fromJson(Map<String, dynamic>.from(json['totais']))
          : TotaisLista.calcular(itens, orcamento: orcamento),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nome': nome,
        'data': data.toIso8601String(),
        'observacao': observacao,
        'orcamento': orcamento,
        'mercadoId': mercadoId,
        'mercado': mercadoNome == null ? null : {'nome': mercadoNome},
        'status': status.paraApi,
        'finalizadaEm': finalizadaEm?.toIso8601String(),
        'itens': itens.map((e) => e.toJson()).toList(),
        'totais': totais.toJson(),
      };
}
