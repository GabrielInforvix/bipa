import 'dart:convert';

import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';

import '../models/basicos_model.dart';
import 'parametros_globais.dart';

/// Levantado quando a requisição não saiu do aparelho (sem rede, DNS, timeout).
/// É diferente de um erro do servidor: aqui o app segue offline e enfileira a
/// alteração em vez de mostrar erro ao usuário.
class SemConexaoException implements Exception {
  final String mensagem;
  const SemConexaoException([this.mensagem = 'Sem conexão']);
  @override
  String toString() => mensagem;
}

/// Client HTTP que injeta o Bearer token e renova a sessão sozinho.
class AutenticacaoInterceptor extends http.BaseClient {
  final http.Client _inner = http.Client();

  /// Evita várias renovações simultâneas quando a tela dispara vários
  /// requests ao mesmo tempo.
  static Future<bool>? _renovacaoEmAndamento;

  /// Tempo curto de propósito: no supermercado, esperar 30s por uma resposta
  /// é pior do que assumir que está offline e seguir pela fila local.
  static const Duration _tempoLimite = Duration(seconds: 12);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (ParametrosGlobais.token.isNotEmpty &&
        JwtDecoder.isExpired(ParametrosGlobais.token)) {
      final ok = await (_renovacaoEmAndamento ??=
          _renovar().whenComplete(() => _renovacaoEmAndamento = null));
      // Falhar a renovação só derruba a sessão se o servidor respondeu que o
      // refresh não vale mais. Sem rede, o app continua funcionando offline.
      if (!ok && _refreshRejeitado) {
        await Sessao.limpar();
        Get.offAllNamed('/login');
      }
    }

    request.headers['Authorization'] = 'Bearer ${ParametrosGlobais.token}';
    request.headers['Content-Type'] = 'application/json';

    try {
      return await _inner.send(request).timeout(_tempoLimite);
    } catch (e) {
      throw SemConexaoException(e.toString());
    }
  }

  static bool _refreshRejeitado = false;

  Future<bool> _renovar() async {
    if (ParametrosGlobais.refreshToken.isEmpty) {
      _refreshRejeitado = true;
      return false;
    }
    try {
      final resposta = await _inner
          .post(
            Uri.parse('${ParametrosGlobais.apiBase}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': ParametrosGlobais.refreshToken}),
          )
          .timeout(_tempoLimite);

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        final dados =
            jsonDecode(utf8.decode(resposta.bodyBytes)) as Map<String, dynamic>;
        await Sessao.salvar(
          token: dados['accessToken'] as String,
          refreshToken: dados['refreshToken'] as String,
          usuario: UsuarioModel.fromJson(
              Map<String, dynamic>.from(dados['usuario'] as Map)),
        );
        _refreshRejeitado = false;
        return true;
      }
      // 401/403 = o refresh morreu de verdade. Outros códigos podem ser
      // instabilidade do servidor, e aí não vale derrubar a sessão.
      _refreshRejeitado =
          resposta.statusCode == 401 || resposta.statusCode == 403;
      return false;
    } catch (_) {
      _refreshRejeitado = false; // sem rede — mantém a sessão
      return false;
    }
  }
}

/// Extrai a mensagem de erro da API (já em pt-BR) para mostrar ao usuário.
String mensagemDeErro(http.Response resposta) {
  try {
    final corpo = jsonDecode(utf8.decode(resposta.bodyBytes));
    final msg = corpo['message'];
    if (msg is List) return msg.join('\n');
    if (msg is String) return msg;
  } catch (_) {}
  return 'Erro inesperado (${resposta.statusCode}). Tente novamente.';
}

bool sucesso(http.Response r) => r.statusCode >= 200 && r.statusCode < 300;
