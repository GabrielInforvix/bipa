import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../globais/parametros_globais.dart';

/// Exige sessão. Note que "sessão" aqui é ter usuário salvo no aparelho, não
/// ter token válido: o app precisa funcionar offline, e o access token só é
/// exigido na hora de sincronizar.
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) =>
      ParametrosGlobais.logado ? null : const RouteSettings(name: '/login');
}

/// Quem já tem conta não volta para a tela de login. O **convidado** pode:
/// é justamente por ali que ele cria a conta.
class ConvidadoMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) =>
      ParametrosGlobais.temConta ? const RouteSettings(name: '/inicio') : null;
}
