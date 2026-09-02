import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/listas_controller.dart';
import '../../extensions/data_extension.dart';
import '../../extensions/num_extension.dart';
import '../../models/lista_model.dart';
import '../../globais/parametros_globais.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/pedir_conta.dart';
import 'folha_entrar.dart';

/// Todas as listas, separadas por estado.
class ListasPage extends StatelessWidget {
  const ListasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final listas = Get.find<ListasController>();

    return Scaffold(
      backgroundColor: Cores.fundo,
      body: SafeArea(
        child: RefreshIndicator(
          color: Cores.laranja,
          onRefresh: listas.atualizarDoServidor,
          child: Obx(() {
            if (listas.listas.isEmpty && !listas.carregando.value) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  VazioComAcao(
                    icone: Icons.list_alt,
                    titulo: 'Nenhuma lista ainda',
                    descricao:
                        'Crie a primeira no botão laranja. Depois é só repetir '
                        'a cada mês — os produtos e os preços já vêm juntos.',
                  ),
                ],
              );
            }

            final emCompra = listas.emCompra;
            final rascunhos = listas.rascunhos;
            final finalizadas = listas.listas
                .where((l) => l.status == StatusLista.finalizada)
                .toList()
              ..sort((a, b) => (b.finalizadaEm ?? b.data)
                  .compareTo(a.finalizadaEm ?? a.data));

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Minhas listas',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w700)),
                    ),
                    // Entrada do convite: quem recebeu um código chega por aqui.
                    TextButton.icon(
                      onPressed: () => ParametrosGlobais.convidado
                          ? pedirConta(
                              context,
                              recurso: 'Entrar numa lista',
                              porque:
                                  'A lista compartilhada mora no servidor, '
                                  'junto das pessoas que participam dela.',
                            )
                          : FolhaEntrar.abrir(context),
                      icon: const Icon(Icons.group_add_outlined, size: 18),
                      label: const Text('Entrar com código',
                          style: TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w600)),
                      style: TextButton.styleFrom(
                          foregroundColor: Cores.laranjaEscuro),
                    ),
                  ],
                ),
                if (emCompra != null) ...[
                  const TituloCategoria('Em andamento'),
                  _Cartao(emCompra, destaque: true),
                ],
                if (rascunhos.isNotEmpty) ...[
                  TituloCategoria('Prontas para comprar',
                      quantidade: rascunhos.length),
                  for (final l in rascunhos) _Cartao(l),
                ],
                if (finalizadas.isNotEmpty) ...[
                  TituloCategoria('Compras anteriores',
                      quantidade: finalizadas.length),
                  for (final l in finalizadas) _Cartao(l),
                ],
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Cartao extends StatelessWidget {
  final ListaModel lista;
  final bool destaque;

  const _Cartao(this.lista, {this.destaque = false});

  @override
  Widget build(BuildContext context) {
    final t = lista.totais;
    final finalizada = lista.status == StatusLista.finalizada;

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Cartao(
        cor: destaque ? Cores.laranjaSuave : Cores.superficie,
        borda: Border.all(
          color: destaque ? Cores.laranja : Cores.linha,
        ),
        aoTocar: () => Get.toNamed(
          finalizada ? '/resumo' : (destaque ? '/compra' : '/lista'),
          arguments: lista.id,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    lista.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
                if (destaque)
                  Etiqueta('em compra',
                      cor: Cores.laranjaEscuro, fundo: Cores.superficie),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              [
                (lista.finalizadaEm ?? lista.data).relativa,
                if (lista.rotuloPessoas != null) lista.rotuloPessoas!,
                if (lista.mercadoNome != null) lista.mercadoNome!,
                '${lista.itens.length} itens',
              ].join(' · '),
              style: const TextStyle(fontSize: 11.5, color: Cores.texto3),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(finalizada || destaque ? 'PAGO' : 'ESTIMADO',
                          style: rotulo),
                      Text(
                        (finalizada || destaque
                                ? t.totalPago
                                : t.totalEstimado)
                            .emReais,
                        style: estiloValor(20),
                      ),
                    ],
                  ),
                ),
                if (finalizada && t.economia.abs() >= 0.01)
                  t.economia > 0
                      ? Etiqueta.economia(t.economia)
                      : Etiqueta.estouro(t.economia),
                if (destaque && t.orcamento != null)
                  Text(
                    'de ${t.orcamento!.emReais}',
                    style:
                        const TextStyle(fontSize: 12, color: Cores.texto2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
