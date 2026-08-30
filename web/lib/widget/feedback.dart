import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'cores.dart';

/// Avisos curtos no rodapé.
///
/// Ficam embaixo porque no Modo Compra o topo é ocupado pelo total, que não
/// pode ser tapado por nada.
class Aviso {
  static void sucesso(String mensagem, {SnackBarAction? acao}) =>
      _mostrar(mensagem, Cores.verde, acao);

  static void erro(String mensagem) => _mostrar(mensagem, Cores.carmim, null);

  static void neutro(String mensagem, {SnackBarAction? acao}) =>
      _mostrar(mensagem, Cores.tinta, acao);

  /// Aviso com desfazer — usado ao marcar item comprado por engano, que é o
  /// erro mais comum dentro do supermercado.
  static void comDesfazer(String mensagem, VoidCallback aoDesfazer) {
    _mostrar(
      mensagem,
      Cores.tinta,
      SnackBarAction(
        label: 'DESFAZER',
        textColor: const Color(0xFFFFB596),
        onPressed: aoDesfazer,
      ),
    );
  }

  static void _mostrar(String mensagem, Color fundo, SnackBarAction? acao) {
    final contexto = Get.context;
    if (contexto == null) return;
    final messenger = ScaffoldMessenger.maybeOf(contexto);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            mensagem,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
            ),
          ),
          backgroundColor: fundo,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: Duration(seconds: acao == null ? 3 : 5),
          action: acao,
        ),
      );
  }
}

/// Confirmação de ação destrutiva.
Future<bool> confirmar(
  BuildContext contexto, {
  required String titulo,
  required String mensagem,
  String confirmarTexto = 'Confirmar',
  bool destrutivo = false,
}) async {
  final resposta = await showDialog<bool>(
    context: contexto,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w700)),
      content: Text(mensagem, style: const TextStyle(color: Cores.texto2)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar',
              style: TextStyle(color: Cores.texto2)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: destrutivo ? Cores.carmim : Cores.laranja,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmarTexto),
        ),
      ],
    ),
  );
  return resposta ?? false;
}
