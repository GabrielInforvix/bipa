import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/listas_controller.dart';
import '../../extensions/data_extension.dart';
import '../../extensions/num_extension.dart';
import '../../models/produto_model.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/grafico_precos.dart';

/// Histórico de preço do produto.
///
/// Cada linha traz o mercado. Sem isso a série mistura atacado com loja de
/// bairro e a média não significa nada — foi por isso que o mercado entrou no
/// modelo desde o começo.
class HistoricoProdutoPage extends StatefulWidget {
  final ProdutoModel produto;

  const HistoricoProdutoPage({super.key, required this.produto});

  @override
  State<HistoricoProdutoPage> createState() => _HistoricoProdutoPageState();
}

class _HistoricoProdutoPageState extends State<HistoricoProdutoPage> {
  final _listas = Get.find<ListasController>();
  HistoricoPrecos? _historico;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final h = await _listas.historico(widget.produto.id);
      if (mounted) setState(() => _historico = h);
    } catch (_) {
      if (mounted) {
        setState(() => _erro =
            'O histórico precisa de conexão. Tente de novo quando estiver online.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.produto;

    return Scaffold(
      backgroundColor: Cores.superficie,
      appBar: AppBar(
        backgroundColor: Cores.superficie,
        surfaceTintColor: Colors.transparent,
        title: Column(
          children: [
            Text(
              p.nome,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            if (p.ean != null)
              Text(
                p.ean!,
                style: const TextStyle(
                  fontSize: 11,
                  color: Cores.texto3,
                  fontWeight: FontWeight.w400,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
          ],
        ),
      ),
      body: _erro != null
          ? VazioComAcao(
              icone: Icons.cloud_off_outlined,
              titulo: 'Sem conexão',
              descricao: _erro!,
              textoBotao: 'Tentar de novo',
              aoTocar: () {
                setState(() => _erro = null);
                _carregar();
              },
            )
          : _historico == null
              ? const Center(
                  child: CircularProgressIndicator(color: Cores.laranja))
              : _Conteudo(historico: _historico!, produto: p),
    );
  }
}

class _Conteudo extends StatelessWidget {
  final HistoricoPrecos historico;
  final ProdutoModel produto;

  const _Conteudo({required this.historico, required this.produto});

  @override
  Widget build(BuildContext context) {
    if (historico.vazio) {
      return const VazioComAcao(
        icone: Icons.timeline,
        titulo: 'Ainda sem histórico',
        descricao:
            'Assim que você comprar esse produto, o preço pago fica guardado '
            'aqui e vira a estimativa da próxima lista.',
      );
    }

    final porKg = produto.tipoVenda.ehPeso;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          children: [
            _Estatistica('Último', historico.ultimo, porKg: porKg),
            const SizedBox(width: 6),
            _Estatistica('Menor', historico.menor,
                cor: Cores.verde, porKg: porKg),
            const SizedBox(width: 6),
            _Estatistica('Maior', historico.maior,
                cor: Cores.carmim, porKg: porKg),
            const SizedBox(width: 6),
            _Estatistica('Médio', historico.medio, porKg: porKg),
          ],
        ),
        const SizedBox(height: 14),
        GraficoPrecos(historico),
        const TituloCategoria('Compras'),
        for (final r in historico.registros)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Cores.linha)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.data.emDataBr,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          r.mercadoNome ?? 'sem mercado',
                          '${r.quantidade.emQuantidade} ${porKg ? 'kg' : 'un'}',
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 11.5, color: Cores.texto3),
                      ),
                    ],
                  ),
                ),
                Text(
                  porKg ? '${r.preco.emReais}/kg' : r.preco.emReais,
                  style: estiloValor(
                    14.5,
                    cor: r.preco == historico.menor
                        ? Cores.verde
                        : r.preco == historico.maior
                            ? Cores.carmim
                            : Cores.tinta,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Estatistica extends StatelessWidget {
  final String titulo;
  final double? valor;
  final Color? cor;
  final bool porKg;

  const _Estatistica(this.titulo, this.valor,
      {this.cor, this.porKg = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
        decoration: BoxDecoration(
          color: Cores.superficie2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(titulo.toUpperCase(),
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  color: Cores.texto3,
                )),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor == null ? '—' : valor!.emValor,
                style: estiloValor(14, cor: cor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
