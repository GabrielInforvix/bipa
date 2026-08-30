import 'parse.dart';

/// Como o produto é vendido. PESO muda o significado de tudo na tela de
/// compra: a quantidade vira peso em quilos e o preço vira R$/kg.
enum TipoVenda {
  unidade,
  peso;

  static TipoVenda deTexto(dynamic v) =>
      parseString(v).toUpperCase() == 'PESO' ? TipoVenda.peso : TipoVenda.unidade;

  String get paraApi => this == TipoVenda.peso ? 'PESO' : 'UNIDADE';
  bool get ehPeso => this == TipoVenda.peso;
  String get unidadePadrao => ehPeso ? 'kg' : 'un';

  /// "R$ 34,90/kg" ou "R$ 5,99"
  String rotuloPreco(String preco) => ehPeso ? '$preco/kg' : preco;
}

class ProdutoModel {
  final String id;
  final String? ean;
  final String nome;
  final String? marca;
  final String? imagemUrl;
  final TipoVenda tipoVenda;
  final String unidade;
  final String? categoriaId;
  final String? categoriaNome;
  final int confirmacoes;

  const ProdutoModel({
    required this.id,
    this.ean,
    required this.nome,
    this.marca,
    this.imagemUrl,
    this.tipoVenda = TipoVenda.unidade,
    this.unidade = 'un',
    this.categoriaId,
    this.categoriaNome,
    this.confirmacoes = 0,
  });

  /// Nome com marca, do jeito que aparece na prateleira.
  String get descricao =>
      (marca == null || marca!.isEmpty) ? nome : '$nome · $marca';

  factory ProdutoModel.fromJson(Map<String, dynamic> json) {
    final categoria = json['categoria'];
    return ProdutoModel(
      id: parseString(json['id']),
      ean: parseStringOpt(json['ean']),
      nome: parseString(json['nome']),
      marca: parseStringOpt(json['marca']),
      imagemUrl: parseStringOpt(json['imagemUrl']),
      tipoVenda: TipoVenda.deTexto(json['tipoVenda']),
      unidade: parseString(json['unidade'], padrao: 'un'),
      categoriaId: parseStringOpt(json['categoriaId']),
      categoriaNome: categoria is Map
          ? parseStringOpt(categoria['nome'])
          : parseStringOpt(json['categoriaNome']),
      confirmacoes: parseInt(json['confirmacoes']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ean': ean,
        'nome': nome,
        'marca': marca,
        'imagemUrl': imagemUrl,
        'tipoVenda': tipoVenda.paraApi,
        'unidade': unidade,
        'categoriaId': categoriaId,
        'categoriaNome': categoriaNome,
        'confirmacoes': confirmacoes,
      };
}

/// Etiqueta de balança decodificada pelo servidor (EAN iniciado em 2).
class EtiquetaBalanca {
  final String codigoInterno;
  final double? preco;
  final double? pesoKg;

  const EtiquetaBalanca({required this.codigoInterno, this.preco, this.pesoKg});

  factory EtiquetaBalanca.fromJson(Map<String, dynamic> json) => EtiquetaBalanca(
        codigoInterno: parseString(json['codigoInterno']),
        preco: parseDoubleOpt(json['preco']),
        pesoKg: parseDoubleOpt(json['pesoKg']),
      );
}

/// Como um código bipado foi resolvido — define qual tela o app abre.
enum OrigemBusca {
  catalogo,
  balanca,
  externo,
  naoEncontrado;

  static OrigemBusca deTexto(dynamic v) {
    switch (parseString(v).toUpperCase()) {
      case 'CATALOGO':
        return OrigemBusca.catalogo;
      case 'BALANCA':
        return OrigemBusca.balanca;
      case 'EXTERNO':
        return OrigemBusca.externo;
      default:
        return OrigemBusca.naoEncontrado;
    }
  }
}

class ResultadoBusca {
  final OrigemBusca origem;
  final ProdutoModel? produto;
  final EtiquetaBalanca? etiqueta;
  final double? ultimoPreco;

  const ResultadoBusca({
    required this.origem,
    this.produto,
    this.etiqueta,
    this.ultimoPreco,
  });

  factory ResultadoBusca.fromJson(Map<String, dynamic> json) => ResultadoBusca(
        origem: OrigemBusca.deTexto(json['origem']),
        produto: json['produto'] is Map
            ? ProdutoModel.fromJson(
                Map<String, dynamic>.from(json['produto'] as Map))
            : null,
        etiqueta: json['etiqueta'] is Map
            ? EtiquetaBalanca.fromJson(
                Map<String, dynamic>.from(json['etiqueta'] as Map))
            : null,
        ultimoPreco: parseDoubleOpt(json['ultimoPreco']),
      );
}

/// Histórico de preços com as estatísticas da tela do produto.
class HistoricoPrecos {
  final List<RegistroPreco> registros;
  final double? ultimo;
  final double? menor;
  final double? maior;
  final double? medio;

  const HistoricoPrecos({
    this.registros = const [],
    this.ultimo,
    this.menor,
    this.maior,
    this.medio,
  });

  bool get vazio => registros.isEmpty;

  factory HistoricoPrecos.fromJson(Map<String, dynamic> json) => HistoricoPrecos(
        registros: (json['registros'] as List? ?? [])
            .map((e) => RegistroPreco.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        ultimo: parseDoubleOpt(json['ultimo']),
        menor: parseDoubleOpt(json['menor']),
        maior: parseDoubleOpt(json['maior']),
        medio: parseDoubleOpt(json['medio']),
      );
}

class RegistroPreco {
  final String id;
  final double preco;
  final double quantidade;
  final double total;
  final DateTime data;
  final String? mercadoNome;

  const RegistroPreco({
    required this.id,
    required this.preco,
    required this.quantidade,
    required this.total,
    required this.data,
    this.mercadoNome,
  });

  factory RegistroPreco.fromJson(Map<String, dynamic> json) {
    final mercado = json['mercado'];
    return RegistroPreco(
      id: parseString(json['id']),
      preco: parseDouble(json['preco']),
      quantidade: parseDouble(json['quantidade'], padrao: 1),
      total: parseDouble(json['total']),
      data: DateTime.tryParse(parseString(json['data']))?.toLocal() ??
          DateTime.now(),
      mercadoNome: mercado is Map ? parseStringOpt(mercado['nome']) : null,
    );
  }
}
