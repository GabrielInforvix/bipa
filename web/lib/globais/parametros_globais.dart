import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/basicos_model.dart';

const _uuid = Uuid();

/// UUID v7 gerado no aparelho. Ordenável por tempo, o que mantém os índices
/// do Postgres saudáveis, e definitivo desde o nascimento — é o que permite
/// criar lista e itens offline sem remapear id nenhum na sincronização.
String novoId() => _uuid.v7();

class ParametrosGlobais {
  /// Em produção o build usa:
  /// flutter build web --dart-define=API_BASE=https://.../api
  static const String apiBase = String.fromEnvironment(
    'API_BASE',
    defaultValue: 'http://localhost:3010/api',
  );

  static String token = '';
  static String refreshToken = '';
  static UsuarioModel? usuario;

  /// Usando o app sem cadastro. Tudo fica no aparelho e nada sobe para o
  /// servidor — exigir conta na primeira tela é onde a maioria dos apps de
  /// lista perde o usuário.
  static bool convidado = false;

  /// Tem conta de verdade: é o que autoriza falar com o servidor.
  static bool get temConta => usuario != null;

  /// Pode usar o app — com conta ou como convidado.
  static bool get logado => temConta || convidado;
}

/// Persistência da sessão. A senha nunca é guardada.
///
/// O refresh token é longo (60 dias) de propósito: o app é usado poucas vezes
/// por mês e exigir login novo a cada compra seria atrito puro. O access token
/// é curto e só é exigido para sincronizar — nunca para usar o app offline.
class Sessao {
  static const _kToken = 'token';
  static const _kRefresh = 'refresh_token';
  static const _kUsuario = 'usuario';
  static const _kCursor = 'cursor_sincronizacao';
  static const _kConvidado = 'convidado';

  static Future<void> salvar({
    required String token,
    required String refreshToken,
    required UsuarioModel usuario,
  }) async {
    ParametrosGlobais.token = token;
    ParametrosGlobais.refreshToken = refreshToken;
    ParametrosGlobais.usuario = usuario;
    ParametrosGlobais.convidado = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kConvidado);
    await prefs.setString(_kToken, token);
    await prefs.setString(_kRefresh, refreshToken);
    await prefs.setString(_kUsuario, jsonEncode(usuario.toJson()));
  }

  static Future<void> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    ParametrosGlobais.token = prefs.getString(_kToken) ?? '';
    ParametrosGlobais.refreshToken = prefs.getString(_kRefresh) ?? '';
    final json = prefs.getString(_kUsuario);
    if (json != null && json.isNotEmpty) {
      ParametrosGlobais.usuario =
          UsuarioModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
    }
    ParametrosGlobais.convidado = prefs.getBool(_kConvidado) ?? false;
  }

  /// Entra sem cadastro. O que for criado fica na fila local e sobe inteiro
  /// no dia em que o usuário criar a conta — nada se perde na conversão.
  static Future<void> entrarComoConvidado() async {
    ParametrosGlobais.convidado = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kConvidado, true);
  }

  static Future<void> limpar() async {
    ParametrosGlobais.token = '';
    ParametrosGlobais.refreshToken = '';
    ParametrosGlobais.usuario = null;
    ParametrosGlobais.convidado = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kConvidado);
    await prefs.remove(_kToken);
    await prefs.remove(_kRefresh);
    await prefs.remove(_kUsuario);
    await prefs.remove(_kCursor);
  }

  /// Cursor do último delta recebido do servidor.
  static Future<String?> cursor() async =>
      (await SharedPreferences.getInstance()).getString(_kCursor);

  static Future<void> salvarCursor(String valor) async =>
      (await SharedPreferences.getInstance()).setString(_kCursor, valor);
}
