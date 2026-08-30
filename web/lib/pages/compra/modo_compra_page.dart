import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/compra_controller.dart';
import '../../controllers/conexao_controller.dart';
import '../../controllers/listas_controller.dart';
import '../../extensions/num_extension.dart';
import '../../globais/parametros_globais.dart';
import '../../models/lista_model.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/feedback.dart';
import '../../widget/item_lista.dart';
import '../../widget/pedir_conta.dart';
import 'folha_preco.dart';

/// Modo Compra — a tela usada dentro do supermercado.
///
/// Três decisões definem esta tela:
///  · o total é o maior elemento, legível de braço estendido;
///  · não há barra de navegação inferior — o polegar só encontra BIPAR;
///  · comprados ficam na mesma lista dos pendentes, riscados.
class ModoCompraPage extends StatefulWidget {
  const ModoCompraPage({super.key});

  @override
  State<ModoCompraPage> createState() => _ModoCompraPageState();
}

class _ModoCompraPageState extends State<ModoCompraPage> {
  final _compra = Get.put(CompraController());

  @override
  void initState() {
    super.initState();
    _abrir();
  }

  /// Sem argumento (recarga da página, atalho do PWA, link direto) cai na
  /// compra em andamento. Antes disso a tela ficava girando para sempre.
  Future<void> _abrir() async {
    final listas = Get.find<ListasController>();
    var id = Get.arguments as String?;
    if (id == null) {
      await listas.recarregar();
      id = listas.emCompra?.id ?? listas.rascunhos.firstOrNull?.id;
    }
    if (id == null) {
      Get.offAllNamed('/inicio');
      return;
    }
    await _compra.carregar(id);
    await _compra.iniciarCompra();
  }

  @override
  void dispose() {
    Get.find<ListasController>().recarregar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.superficie,
      body: SafeArea(
        child: Obx(() {
          final lista = _compra.lista.value;
          if (lista == null) {
            return const Center(
                child: CircularProgressIndicator(color: Cores.laranja));
          }

          return Column(
            children: [
              _BarraTopo(lista: lista),
              _Total(lista: lista),
              _Abas(compra: _compra, lista: lista),
              Expanded(child: _Conteudo(compra: _compra, lista: lista)),
              _BarraInferior(compra: _compra, lista: lista),
            ],
          );
        }),
      ),
    );
  }
}

class _BarraTopo extends StatelessWidget {
  final ListaModel lista;

  const _BarraTopo({required this.lista});

  @override
  Widget build(BuildContext context) {
    final conexao = Get.find<ConexaoController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 14, 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    lista.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
                if (lista.mercadoNome != null) ...[
                  const SizedBox(width: 7),
                  Etiqueta(lista.mercadoNome!),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Obx(() {
            final ok = conexao.online.value && conexao.pendentes.value == 0;
            return Etiqueta(
              ok ? 'ok' : conexao.rotulo,
              cor: ok ? Cores.verde : Cores.laranjaEscuro,
              fundo: ok ? Cores.verdeSuave : Cores.laranjaSuave,
            );
          }),
        ],
      ),
    );
  }
}

/// O total é o maior elemento da tela. É a única promessa do app.
class _Total extends StatelessWidget {
  final ListaModel lista;

  const _Total({required this.lista});

  @override
  Widget build(BuildContext context) {
    final t = lista.totais;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Column(
        children: [
          const Text('TOTAL ATÉ AGORA', style: rotulo),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(t.totalPago.emReais, style: estiloValor(50)),
          ),
          const SizedBox(height: 5),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                'estimado ${t.totalEstimado.emReais}',
                style: const TextStyle(fontSize: 12, color: Cores.texto2),
              ),
              if (t.economia.abs() >= 0.01)
                DeltaValor(t.economia, tamanho: 12, ehTotal: true),
            ],
          ),
          if (t.orcamento != null) ...[
            const SizedBox(height: 12),
            BarraOrcamento(t),
          ],
        ],
      ),
    );
  }
}

class _Abas extends StatelessWidget {
  final CompraController compra;
  final ListaModel lista;

  const _Abas({required this.compra, required this.lista});

  @override
  Widget build(BuildContext context) {
    final t = lista.totais;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Obx(() {
        final ativa = compra.aba.value;
        return Row(
          children: [
            for (final (i, dados) in [
              ('Pendentes', t.itensPendentes),
              ('Comprados', t.itensComprados),
              ('Extras', t.itensExtras),
            ].indexed)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: GestureDetector(
                  onTap: () => compra.aba.value = i,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: ativa == i
                          ? Cores.laranjaSuave
                          : Cores.superficie2,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '${dados.$1} ${dados.$2}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: ativa == i
                            ? Cores.laranjaEscuro
                            : Cores.texto2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

class _Conteudo extends StatelessWidget {
  final CompraController compra;
  final ListaModel lista;

  const _Conteudo({required this.compra, required this.lista});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final aba = compra.aba.value;
      final itens = switch (aba) {
        1 => lista.comprados,
        2 => lista.extras,
        _ => lista.pendentes,
      };

      if (itens.isEmpty) {
        return VazioComAcao(
          icone: switch (aba) {
            1 => Icons.check_circle_outline,
            2 => Icons.add_shopping_cart,
            _ => Icons.done_all,
          },
          titulo: switch (aba) {
            1 => 'Nada comprado ainda',
            2 => 'Nenhuma compra extra',
            _ => 'Tudo comprado!',
          },
          descricao: switch (aba) {
            1 => 'Bipe o primeiro produto para começar.',
            2 => 'Produtos fora da lista aparecem aqui, separados do planejado.',
            _ => 'Não sobrou nada pendente. Pode fechar a compra.',
          },
        );
      }

      // Agrupado por categoria = ordem do corredor.
      final grupos = lista.agrupadoPorCategoria(itens);
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final grupo in grupos) ...[
            TituloCategoria(grupo.key, quantidade: grupo.value.length),
            for (final item in grupo.value)
              LinhaItem(
                item,
                mostrarEstimado: aba == 0,
                aoTocar: () => _abrirPreco(context, item),
                aoAlternar: () => _alternar(context, item),
              ),
          ],
        ],
      );
    });
  }

  Future<void> _abrirPreco(BuildContext context, ListaItemModel item) async {
    await FolhaPreco.abrir(
      context,
      titulo: item.nome,
      subtitulo: item.marca,
      porPeso: item.ehPeso,
      quantidadeInicial: item.quantidadeAtual,
      precoInicial: item.precoUnitario,
      sugestao: item.precoEstimado,
      precoEstimado: item.precoEstimado,
      aoConfirmar: (quantidade, preco) => compra.comprarItem(
        item,
        quantidade: quantidade,
        precoUnitario: preco,
      ),
    );
  }

  void _alternar(BuildContext context, ListaItemModel item) {
    if (item.comprado) {
      compra.desfazerCompra(item);
      Aviso.neutro('${item.nome} voltou para os pendentes.');
    } else {
      _abrirPreco(context, item);
    }
  }
}

/// Ação principal na metade inferior — alcance do polegar, uma mão só.
class _BarraInferior extends StatelessWidget {
  final CompraController compra;
  final ListaModel lista;

  const _BarraInferior({required this.compra, required this.lista});

  @override
  Widget build(BuildContext context) {
    final tudoComprado = lista.totais.itensPendentes == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Cores.superficie,
        border: Border(top: BorderSide(color: Cores.linha)),
      ),
      child: Row(
        children: [
          Expanded(
            child: BotaoPrincipal(
              'BIPAR',
              icone2: const IconeBarras(tamanho: 24),
              altura: 56,
              aoTocar: ParametrosGlobais.convidado
                  ? () => pedirConta(
                context,
                recurso: 'Bipar código de barras',
                porque: 'A leitura consulta o catálogo de produtos no servidor '
                    'e guarda o preço no seu histórico.',
              )
                  : () => Get.toNamed('/scanner', arguments: lista.id),
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 56,
            height: 56,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: const BorderSide(color: Cores.linhaForte, width: 1.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Get.toNamed('/lista', arguments: lista.id),
              child: const Icon(Icons.add, size: 24, color: Cores.tinta),
            ),
          ),
          if (tudoComprado) ...[
            const SizedBox(width: 9),
            SizedBox(
              width: 56,
              height: 56,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: Cores.verde,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _finalizar(context),
                child: const Icon(Icons.check, size: 26),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _finalizar(BuildContext context) async {
    final ok = await confirmar(
      context,
      titulo: 'Fechar a compra?',
      mensagem:
          'O total de ${lista.totais.totalPago.emReais} será guardado e cada '
          'preço entra no histórico dos produtos.',
      confirmarTexto: 'Fechar compra',
    );
    if (!ok) return;
    await compra.finalizar();
    Get.offNamed('/resumo', arguments: lista.id);
  }
}
