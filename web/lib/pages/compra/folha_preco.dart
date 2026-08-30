import 'package:flutter/material.dart';

import '../../extensions/num_extension.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/teclado_preco.dart';

/// Folha de quantidade e preço.
///
/// Sobe POR CIMA da câmera, que continua ligada atrás. É o que faz o ciclo do
/// bipe ser: leu → confirma → já está lendo o próximo. Abrir uma tela cheia
/// aqui custaria quatro transições por produto, e uma compra tem trinta.
class FolhaPreco extends StatefulWidget {
  final String titulo;
  final String? subtitulo;
  final String? ean;
  final bool porPeso;
  final double quantidadeInicial;
  final double? precoInicial;

  /// Último preço pago — vira uma tecla no teclado.
  final double? sugestao;

  /// Preço planejado, para mostrar a economia na hora.
  final double? precoEstimado;

  final String etiquetaTopo;
  final Color? corEtiqueta;
  final Color? fundoEtiqueta;
  final Future<void> Function(double quantidade, double preco) aoConfirmar;

  const FolhaPreco({
    super.key,
    required this.titulo,
    required this.aoConfirmar,
    this.subtitulo,
    this.ean,
    this.porPeso = false,
    this.quantidadeInicial = 1,
    this.precoInicial,
    this.sugestao,
    this.precoEstimado,
    this.etiquetaTopo = 'na sua lista',
    this.corEtiqueta,
    this.fundoEtiqueta,
  });

  /// Abre a folha sobre a tela atual, sem trocar de rota.
  static Future<bool?> abrir(
    BuildContext context, {
    required String titulo,
    required Future<void> Function(double, double) aoConfirmar,
    String? subtitulo,
    String? ean,
    bool porPeso = false,
    double quantidadeInicial = 1,
    double? precoInicial,
    double? sugestao,
    double? precoEstimado,
    String etiquetaTopo = 'na sua lista',
    Color? corEtiqueta,
    Color? fundoEtiqueta,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      // Barreira translúcida: a câmera continua visível atrás, o contexto
      // não se perde.
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => FolhaPreco(
        titulo: titulo,
        subtitulo: subtitulo,
        ean: ean,
        porPeso: porPeso,
        quantidadeInicial: quantidadeInicial,
        precoInicial: precoInicial,
        sugestao: sugestao,
        precoEstimado: precoEstimado,
        etiquetaTopo: etiquetaTopo,
        corEtiqueta: corEtiqueta,
        fundoEtiqueta: fundoEtiqueta,
        aoConfirmar: aoConfirmar,
      ),
    );
  }

  @override
  State<FolhaPreco> createState() => _FolhaPrecoState();
}

class _FolhaPrecoState extends State<FolhaPreco> {
  late EntradaCentavos _preco;
  late double _quantidade;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _quantidade = widget.quantidadeInicial;
    _preco = EntradaCentavos();
    // Já vem preenchido com o preço conhecido: na maioria das vezes basta
    // confirmar.
    final inicial = widget.precoInicial ?? widget.sugestao;
    if (inicial != null) _preco.definir(inicial);
  }

  double get _total => ((_quantidade * _preco.valor) * 100).round() / 100;

  double? get _diferenca {
    final estimado = widget.precoEstimado;
    if (estimado == null || _preco.vazio) return null;
    return ((estimado * _quantidade - _total) * 100).round() / 100;
  }

  Future<void> _confirmar() async {
    if (_preco.vazio) return;
    setState(() => _salvando = true);
    await widget.aoConfirmar(_quantidade, _preco.valor);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final diferenca = _diferenca;

    return Container(
      decoration: const BoxDecoration(
        color: Cores.superficie,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
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
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Etiqueta(
                      widget.etiquetaTopo,
                      cor: widget.corEtiqueta ?? Cores.verde,
                      fundo: widget.fundoEtiqueta ?? Cores.verdeSuave,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
                    ),
                    if (widget.subtitulo != null || widget.ean != null)
                      Text(
                        [widget.subtitulo, widget.ean]
                            .where((e) => e != null && e.isNotEmpty)
                            .join(' · '),
                        style: const TextStyle(
                            fontSize: 11.5, color: Cores.texto3),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ContadorQuantidade(
                valor: _quantidade,
                porPeso: widget.porPeso,
                aoMudar: (v) => setState(() => _quantidade = v),
              ),
              const SizedBox(width: 8),
              Text(
                widget.porPeso ? 'kg' : 'un',
                style: const TextStyle(fontSize: 12.5, color: Cores.texto3),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    widget.porPeso ? 'PREÇO POR KG' : 'PREÇO UNITÁRIO',
                    style: rotulo,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _preco.formatado,
                    style: estiloValor(26, cor: Cores.laranjaEscuro),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: Cores.superficie2,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TOTAL DO ITEM', style: rotulo),
                      if (diferenca != null && diferenca.abs() >= 0.01) ...[
                        const SizedBox(height: 3),
                        DeltaValor(diferenca,
                            ehTotal: true, sufixo: 'vs. estimado'),
                      ],
                    ],
                  ),
                ),
                Text(_total.emReais, style: estiloValor(24)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          TecladoPreco(
            entrada: _preco,
            sugestao: widget.sugestao,
            textoConfirmar: _salvando ? '···' : 'OK',
            aoMudar: (nova) => setState(() => _preco = nova),
            aoConfirmar: _salvando ? () {} : _confirmar,
          ),
        ],
      ),
    );
  }
}
