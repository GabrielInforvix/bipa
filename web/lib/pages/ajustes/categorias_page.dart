import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/listas_controller.dart';
import '../../globais/parametros_globais.dart';
import '../../models/basicos_model.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/feedback.dart';

/// Ordem das categorias — que aqui significa **ordem do corredor**.
///
/// Categoria é taxonomia; corredor é itinerário. Hortifrúti antes de mercearia
/// porque é assim que se anda no mercado, não porque o alfabeto mandou. O
/// usuário arrasta uma vez e nunca mais volta atrás no corredor de bebidas —
/// é a diferença entre uma lista bonita e uma lista que economiza vinte
/// minutos de compra.
class CategoriasPage extends StatefulWidget {
  const CategoriasPage({super.key});

  @override
  State<CategoriasPage> createState() => _CategoriasPageState();
}

class _CategoriasPageState extends State<CategoriasPage> {
  final _listas = Get.find<ListasController>();
  late List<CategoriaModel> _ordem;
  bool _mudou = false;

  @override
  void initState() {
    super.initState();
    _ordem = List.of(_listas.categorias);
  }

  Future<void> _salvar() async {
    await _listas.reordenarCategorias(_ordem);
    _mudou = false;
    if (mounted) {
      Get.back();
      Aviso.sucesso('Ordem do corredor salva.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ParametrosGlobais.convidado || _ordem.isEmpty) {
      return Scaffold(
        backgroundColor: Cores.superficie,
        appBar: AppBar(title: const Text('Categorias')),
        body: VazioComAcao(
          icone: Icons.category_outlined,
          titulo: ParametrosGlobais.convidado
              ? 'Categorias vêm com a conta'
              : 'Nada para ordenar ainda',
          descricao: ParametrosGlobais.convidado
              ? 'No modo sem conta os itens ficam em "Outros". Ao criar a '
                  'conta, as categorias chegam já na ordem de um mercado '
                  'típico — e aí você ajusta para o seu.'
              : 'As categorias aparecem aqui depois da primeira sincronização.',
        ),
      );
    }

    return Scaffold(
      backgroundColor: Cores.superficie,
      appBar: AppBar(
        title: const Text('Ordem do corredor',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Cores.superficie2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.route_outlined, size: 18, color: Cores.texto2),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Arraste para deixar na ordem em que você anda no seu '
                      'mercado. As listas passam a agrupar os itens nessa '
                      'sequência.',
                      style: TextStyle(
                          fontSize: 12.5, color: Cores.texto2, height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _ordem.length,
              // O feedback do arrasto: cartão levemente elevado, nada de
              // mudar cor — o dedo já sabe o que está segurando.
              proxyDecorator: (child, _, animation) => AnimatedBuilder(
                animation: animation,
                builder: (_, _) => Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(13),
                  child: child,
                ),
              ),
              // onReorderItem já entrega o índice de destino corrigido pela
              // remoção — sem o clássico ajuste manual do para--.
              onReorderItem: (de, para) {
                setState(() {
                  _ordem.insert(para, _ordem.removeAt(de));
                  _mudou = true;
                });
              },
              itemBuilder: (_, i) {
                final c = _ordem[i];
                return Container(
                  key: ValueKey(c.id),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    color: Cores.superficie2,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      Text(
                        '${i + 1}',
                        style: estiloValor(14, cor: Cores.texto3),
                      ),
                      const SizedBox(width: 12),
                      if (c.icone != null) ...[
                        Text(c.icone!, style: const TextStyle(fontSize: 17)),
                        const SizedBox(width: 9),
                      ],
                      Expanded(
                        child: Text(
                          c.nome,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.drag_handle,
                              size: 22, color: Cores.texto3),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Cores.linha)),
            ),
            child: BotaoPrincipal(
              'Salvar ordem',
              aoTocar: _mudou ? _salvar : null,
            ),
          ),
        ],
      ),
    );
  }
}
