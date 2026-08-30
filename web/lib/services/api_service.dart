import 'dart:convert';

import 'package:http/http.dart' as http;

import '../globais/http_interceptor.dart';
import '../globais/parametros_globais.dart';
import '../models/basicos_model.dart';
import '../models/lista_model.dart';
import '../models/produto_model.dart';

/// Acesso à API.
///
/// As telas **não** chamam isto diretamente para ler dados: quem lê é o
/// repositório local. Esta camada serve o que só existe online — autenticação,
/// consulta de EAN em fonte externa e histórico de preços.
class ApiService {
  final _client = AutenticacaoInterceptor();
  String get _base => ParametrosGlobais.apiBase;

  // ── Autenticação ───────────────────────────────────────────────────

  Future<void> entrar(String email, String senha) async {
    final r = await _client.post(
      Uri.parse('$_base/auth/login'),
      body: jsonEncode({'email': email, 'senha': senha}),
    );
    await _guardarSessao(r);
  }

  Future<void> cadastrar(String nome, String email, String senha) async {
    final r = await _client.post(
      Uri.parse('$_base/auth/register'),
      body: jsonEncode({'nome': nome, 'email': email, 'senha': senha}),
    );
    await _guardarSessao(r);
  }

  Future<void> sair() async {
    try {
      await _client.post(
        Uri.parse('$_base/auth/logout'),
        body: jsonEncode({'refreshToken': ParametrosGlobais.refreshToken}),
      );
    } catch (_) {
      // Sair offline é válido: a sessão local some de qualquer jeito.
    }
    await Sessao.limpar();
  }

  Future<void> _guardarSessao(http.Response r) async {
    if (!sucesso(r)) throw Exception(mensagemDeErro(r));
    final d = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    await Sessao.salvar(
      token: d['accessToken'] as String,
      refreshToken: d['refreshToken'] as String,
      usuario:
          UsuarioModel.fromJson(Map<String, dynamic>.from(d['usuario'] as Map)),
    );
  }

  // ── Produtos ───────────────────────────────────────────────────────

  /// Consulta o EAN no servidor, que roda a cascata completa
  /// (catálogo → balança → Open Food Facts).
  Future<ResultadoBusca> buscarPorEan(String ean) async {
    final r = await _client.get(Uri.parse('$_base/produtos/ean/$ean'));
    if (!sucesso(r)) throw Exception(mensagemDeErro(r));
    return ResultadoBusca.fromJson(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<List<ProdutoModel>> buscarProdutos(String termo) async {
    final r = await _client
        .get(Uri.parse('$_base/produtos?termo=${Uri.encodeQueryComponent(termo)}'));
    if (!sucesso(r)) throw Exception(mensagemDeErro(r));
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List)
        .map((e) => ProdutoModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<ProdutoModel> criarProduto(Map<String, dynamic> dados) async {
    final r = await _client.post(
      Uri.parse('$_base/produtos'),
      body: jsonEncode(dados),
    );
    if (!sucesso(r)) throw Exception(mensagemDeErro(r));
    return ProdutoModel.fromJson(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<HistoricoPrecos> historicoPrecos(String produtoId) async {
    final r =
        await _client.get(Uri.parse('$_base/produtos/$produtoId/historico-precos'));
    if (!sucesso(r)) throw Exception(mensagemDeErro(r));
    return HistoricoPrecos.fromJson(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>,
    );
  }

  // ── Listas ─────────────────────────────────────────────────────────

  Future<List<ListaModel>> listas() async {
    final r = await _client.get(Uri.parse('$_base/listas'));
    if (!sucesso(r)) throw Exception(mensagemDeErro(r));
    return (jsonDecode(utf8.decode(r.bodyBytes)) as List)
        .map((e) => ListaModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Fecha a compra no servidor — é o que grava o histórico de preços.
  Future<ListaModel> finalizar(String listaId) async {
    final r =
        await _client.post(Uri.parse('$_base/listas/$listaId/finalizar'));
    if (!sucesso(r)) throw Exception(mensagemDeErro(r));
    return ListaModel.fromJson(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<MercadoModel> criarMercado(String nome) async {
    final r = await _client.post(
      Uri.parse('$_base/mercados'),
      body: jsonEncode({'nome': nome}),
    );
    if (!sucesso(r)) throw Exception(mensagemDeErro(r));
    return MercadoModel.fromJson(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<ResumoDashboard> resumo() async {
    final r = await _client.get(Uri.parse('$_base/dashboard/resumo'));
    if (!sucesso(r)) throw Exception(mensagemDeErro(r));
    return ResumoDashboard.fromJson(
      jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
