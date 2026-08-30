import 'parse.dart';

class UsuarioModel {
  final String id;
  final String nome;
  final String email;
  final String perfil;

  const UsuarioModel({
    required this.id,
    required this.nome,
    required this.email,
    this.perfil = 'COMUM',
  });

  /// "Gabriel Torresani" → "Gabriel"
  String get primeiroNome => nome.split(' ').first;

  factory UsuarioModel.fromJson(Map<String, dynamic> json) => UsuarioModel(
        id: parseString(json['id']),
        nome: parseString(json['nome']),
        email: parseString(json['email']),
        perfil: parseString(json['perfil'], padrao: 'COMUM'),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'nome': nome, 'email': email, 'perfil': perfil};
}

class CategoriaModel {
  final String id;
  final String nome;
  final String? icone;
  final int ordem;

  const CategoriaModel({
    required this.id,
    required this.nome,
    this.icone,
    this.ordem = 0,
  });

  factory CategoriaModel.fromJson(Map<String, dynamic> json) => CategoriaModel(
        id: parseString(json['id']),
        nome: parseString(json['nome']),
        icone: parseStringOpt(json['icone']),
        ordem: parseInt(json['ordem']),
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'nome': nome, 'icone': icone, 'ordem': ordem};
}

class MercadoModel {
  final String id;
  final String nome;
  final String? cidade;

  const MercadoModel({required this.id, required this.nome, this.cidade});

  factory MercadoModel.fromJson(Map<String, dynamic> json) => MercadoModel(
        id: parseString(json['id']),
        nome: parseString(json['nome']),
        cidade: parseStringOpt(json['cidade']),
      );

  Map<String, dynamic> toJson() => {'id': id, 'nome': nome, 'cidade': cidade};
}

/// Resumo da tela de início.
class ResumoDashboard {
  final ResumoCompra? emAndamento;
  final ResumoCompra? ultimaCompra;
  final int totalListas;

  const ResumoDashboard({
    this.emAndamento,
    this.ultimaCompra,
    this.totalListas = 0,
  });

  factory ResumoDashboard.fromJson(Map<String, dynamic> json) => ResumoDashboard(
        emAndamento: json['emAndamento'] is Map
            ? ResumoCompra.fromJson(
                Map<String, dynamic>.from(json['emAndamento']))
            : null,
        ultimaCompra: json['ultimaCompra'] is Map
            ? ResumoCompra.fromJson(
                Map<String, dynamic>.from(json['ultimaCompra']))
            : null,
        totalListas: parseInt(json['totalListas']),
      );
}

class ResumoCompra {
  final String id;
  final String nome;
  final DateTime data;
  final String? mercadoNome;
  final int totalItens;
  final int itensComprados;
  final double totalPago;
  final double economia;
  final double? orcamento;
  final double? saldoOrcamento;

  const ResumoCompra({
    required this.id,
    required this.nome,
    required this.data,
    this.mercadoNome,
    this.totalItens = 0,
    this.itensComprados = 0,
    this.totalPago = 0,
    this.economia = 0,
    this.orcamento,
    this.saldoOrcamento,
  });

  double? get fracaoOrcamento {
    if (orcamento == null || orcamento == 0) return null;
    return totalPago / orcamento!;
  }

  factory ResumoCompra.fromJson(Map<String, dynamic> json) {
    final mercado = json['mercado'];
    return ResumoCompra(
      id: parseString(json['id']),
      nome: parseString(json['nome']),
      data: DateTime.tryParse(parseString(json['data']))?.toLocal() ??
          DateTime.now(),
      mercadoNome: mercado is Map ? parseStringOpt(mercado['nome']) : null,
      totalItens: parseInt(json['totalItens']),
      itensComprados: parseInt(json['itensComprados']),
      totalPago: parseDouble(json['totalPago']),
      economia: parseDouble(json['economia']),
      orcamento: parseDoubleOpt(json['orcamento']),
      saldoOrcamento: parseDoubleOpt(json['saldoOrcamento']),
    );
  }
}
