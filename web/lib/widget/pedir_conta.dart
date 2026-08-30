import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'componentes.dart';
import 'cores.dart';

/// Convite para criar conta, mostrado quando o convidado esbarra em algo que
/// depende do servidor.
///
/// É um convite, não um erro: a pessoa escolheu entrar sem cadastro e está
/// usando o app normalmente. O texto diz o que ela ganha, não o que ela deixou
/// de fazer — e deixa claro que nada do que já montou se perde.
Future<void> pedirConta(
  BuildContext context, {
  required String recurso,
  required String porque,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Cores.superficie,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Cores.linhaForte,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: Cores.laranjaSuave,
              shape: BoxShape.circle,
            ),
            child: const IconeBarras(tamanho: 24, cor: Cores.laranja),
          ),
          const SizedBox(height: 14),
          Text(
            '$recurso precisa de conta',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            porque,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13.5, color: Cores.texto2, height: 1.45),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Cores.verdeSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_outline, size: 17, color: Cores.verde),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Suas listas e compras já feitas sobem junto. Nada do que '
                    'você montou se perde.',
                    style: TextStyle(
                        fontSize: 12.5, color: Cores.verde, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          BotaoPrincipal(
            'Criar conta',
            aoTocar: () {
              Navigator.pop(context);
              Get.toNamed('/login');
            },
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Agora não',
                style: TextStyle(color: Cores.texto3)),
          ),
        ],
      ),
    ),
  );
}
