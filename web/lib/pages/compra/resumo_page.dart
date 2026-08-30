import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/listas_controller.dart';
import '../../extensions/data_extension.dart';
import '../../extensions/num_extension.dart';
import '../../models/lista_model.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/item_lista.dart';

/// Resumo da compra finalizada.
///
/// Planejados e extras aparecem separados — é o número que revela o impulso,
/// e é o que a regra 12 pede. O que não foi comprado vira uma decisão
/// explícita, que alimenta a próxima lista.
class ResumoPage extends StatelessWidget {
  const ResumoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final listas = Get.find<ListasController>();
    final id = Get.arguments as String?;

    return Scaffold(
      backgroundColor: Cores.superficie,
      body: SafeArea(
        child: Obx(() {
          // Sem argumento (recarga da página) mostra a última compra
          // fechada em vez de girar indefinidamente.
          final lista = id == null
              ? listas.ultimaFinalizada
              : listas.listas.firstWhereOrNull((l) => l.id == id);
          if (lista == null) {
            return const VazioComAcao(
              icone: Icons.receipt_long_outlined,
              titulo: 'Compra não encontrada',
              descricao: 'Volte ao início para escolher uma lista.',
            );
          }
          final t = lista.totais;
          final naoComprados = lista.pendentes;

          return Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, size: 22),
                  onPressed: () => Get.offAllNamed('/inicio'),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    _Topo(lista: lista),
                    const SizedBox(height: 20),
                    _Comparacao(totais: t),
                    if (t.orcamento != null) ...[
                      const SizedBox(height: 9),
                      _Orcamento(totais: t),
                    ],
                    const SizedBox(height: 9),
                    _PlanejadoVsExtra(totais: t),
                    if (naoComprados.isNotEmpty) ...[
                      TituloCategoria('Não comprados',
                          quantidade: naoComprados.length),
                      for (final item in naoComprados)
                        LinhaItem(item, mostrarEstimado: true),
                      const SizedBox(height: 6),
                      const Text(
                        'Esses itens continuam disponíveis ao repetir a lista.',
                        style: TextStyle(fontSize: 12, color: Cores.texto3),
                      ),
                    ],
                  ],
                ),
              ),
              _Acoes(lista: lista, listas: listas),
            ],
          );
        }),
      ),
    );
  }
}

class _Topo extends StatelessWidget {
  final ListaModel lista;

  const _Topo({required this.lista});

  @override
  Widget build(BuildContext context) {
    final t = lista.totais;
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: Cores.verdeSuave,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Cores.verde, size: 27),
        ),
        const SizedBox(height: 12),
        Text(
          'COMPRA FINALIZADA'
          '${lista.mercadoNome != null ? ' · ${lista.mercadoNome!.toUpperCase()}' : ''}',
          style: rotulo,
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(t.totalPago.emReais, style: estiloValor(44)),
        ),
        const SizedBox(height: 4),
        Text(
          '${(lista.finalizadaEm ?? lista.data).emDataBr} · '
          '${t.itensComprados} itens',
          style: const TextStyle(fontSize: 12, color: Cores.texto3),
        ),
      ],
    );
  }
}

class _Comparacao extends StatelessWidget {
  final TotaisLista totais;

  const _Comparacao({required this.totais});

  @override
  Widget build(BuildContext context) {
    final economizou = totais.economia > 0;
    return Cartao(
      child: Column(
        children: [
          _Linha('Total estimado', totais.totalEstimado.emReais),
          const SizedBox(height: 8),
          _Linha('Total pago', totais.totalPago.emReais),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Cores.linha),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                economizou ? 'Economia' : 'Acima do estimado',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: economizou ? Cores.verde : Cores.carmim,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    economizou ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 19,
                    color: economizou ? Cores.verde : Cores.carmim,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    totais.economia.abs().emReais,
                    style: estiloValor(21,
                        cor: economizou ? Cores.verde : Cores.carmim),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final String rotuloTexto;
  final String valor;

  const _Linha(this.rotuloTexto, this.valor);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(rotuloTexto,
            style: const TextStyle(fontSize: 13, color: Cores.texto2)),
        Text(valor, style: estiloValor(15)),
      ],
    );
  }
}

class _Orcamento extends StatelessWidget {
  final TotaisLista totais;

  const _Orcamento({required this.totais});

  @override
  Widget build(BuildContext context) {
    final estourou = totais.estourou;
    return Cartao(
      cor: estourou ? Cores.carmimSuave : Cores.verdeSuave,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ORÇAMENTO ${totais.orcamento!.emReais}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                    color: estourou ? Cores.carmim : Cores.verde,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  estourou
                      ? 'Passou ${totais.saldoOrcamento!.abs().emReais}'
                      : 'Sobraram ${totais.saldoOrcamento!.emReais}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: estourou ? Cores.carmim : Cores.verde,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 86, child: BarraOrcamento(totais, compacta: true)),
        ],
      ),
    );
  }
}

/// Regra 12: extras contabilizados à parte.
class _PlanejadoVsExtra extends StatelessWidget {
  final TotaisLista totais;

  const _PlanejadoVsExtra({required this.totais});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Cartao(
            child: Column(
              children: [
                Text('PLANEJADOS · ${totais.itensComprados - totais.itensExtras}',
                    style: rotulo),
                const SizedBox(height: 4),
                Text(totais.totalPlanejados.emReais, style: estiloValor(18)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Cartao(
            cor: Cores.laranjaSuave,
            borda: Border.all(color: Cores.laranja),
            child: Column(
              children: [
                Text('EXTRAS · ${totais.itensExtras}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.1,
                      color: Cores.laranjaEscuro,
                    )),
                const SizedBox(height: 4),
                Text(totais.totalExtras.emReais,
                    style: estiloValor(18, cor: Cores.laranjaEscuro)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Acoes extends StatelessWidget {
  final ListaModel lista;
  final ListasController listas;

  const _Acoes({required this.lista, required this.listas});

  @override
  Widget build(BuildContext context) {
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
              'Repetir lista',
              icone: Icons.refresh,
              altura: 48,
              aoTocar: () async {
                final nova = await listas.repetir(lista);
                Get.offNamed('/lista', arguments: nova.id);
              },
            ),
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 48,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: const BorderSide(color: Cores.linhaForte, width: 1.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              onPressed: () => _compartilhar(context),
              child: const Icon(Icons.share_outlined,
                  size: 20, color: Cores.tinta),
            ),
          ),
        ],
      ),
    );
  }

  /// Texto pronto para WhatsApp. Resolve o compartilhamento familiar antes de
  /// existir lista multiusuário.
  void _compartilhar(BuildContext context) {
    final t = lista.totais;
    final linhas = [
      '*${lista.nome}*',
      '${(lista.finalizadaEm ?? lista.data).emDataBr}'
          '${lista.mercadoNome != null ? ' · ${lista.mercadoNome}' : ''}',
      '',
      ...lista.comprados.map((i) =>
          '• ${i.nome} — ${i.quantidadeAtual.emQuantidade} ${i.ehPeso ? 'kg' : 'un'} — ${(i.total ?? 0).emReais}'),
      '',
      '*Total: ${t.totalPago.emReais}*',
      if (t.economia.abs() >= 0.01)
        t.economia > 0
            ? 'Economia: ${t.economia.emReais}'
            : 'Acima do estimado: ${t.economia.abs().emReais}',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Compartilhar compra',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: SingleChildScrollView(
          child: SelectableText(
            linhas.join('\n'),
            style: const TextStyle(fontSize: 12.5, height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar',
                style: TextStyle(color: Cores.texto2)),
          ),
        ],
      ),
    );
  }
}
