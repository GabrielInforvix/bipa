import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../extensions/num_extension.dart';
import 'cores.dart';

/// Teclado de preço estilo caixa registradora.
///
/// Não usa o teclado do sistema de propósito. Em PWA no iOS o teclado nativo
/// com vírgula decimal é inconsistente e empurra o layout ao abrir — e no
/// corredor, com uma mão só, um layout que se mexe custa erro de digitação.
/// Aqui o usuário digita só dígitos e os centavos preenchem da direita para a
/// esquerda: `599` vira R$ 5,99. Sem vírgula, sem ponto, sem ambiguidade.
class TecladoPreco extends StatelessWidget {
  final EntradaCentavos entrada;
  final ValueChanged<EntradaCentavos> aoMudar;
  final VoidCallback aoConfirmar;
  final String textoConfirmar;

  /// Último preço pago. Vira uma tecla: na maioria das vezes o preço não
  /// mudou e um toque resolve.
  final double? sugestao;

  const TecladoPreco({
    super.key,
    required this.entrada,
    required this.aoMudar,
    required this.aoConfirmar,
    this.sugestao,
    this.textoConfirmar = 'OK',
  });

  void _digitar(String d) {
    HapticFeedback.selectionClick();
    final nova = entrada.copia()..digitar(d);
    aoMudar(nova);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final linha in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (final d in linha) ...[
                  Expanded(child: _Tecla(d, aoTocar: () => _digitar(d))),
                  if (d != linha.last) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: sugestao != null
                  ? _Tecla(
                      'últ. ${sugestao!.emValor}',
                      pequena: true,
                      aoTocar: () {
                        HapticFeedback.selectionClick();
                        aoMudar(entrada.copia()..definir(sugestao!));
                      },
                    )
                  : _Tecla(
                      '⌫',
                      aoTocar: () {
                        HapticFeedback.selectionClick();
                        aoMudar(entrada.copia()..apagar());
                      },
                    ),
            ),
            const SizedBox(width: 6),
            Expanded(child: _Tecla('0', aoTocar: () => _digitar('0'))),
            const SizedBox(width: 6),
            Expanded(
              child: _Tecla(
                textoConfirmar,
                destaque: true,
                aoTocar: entrada.vazio ? null : aoConfirmar,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tecla extends StatelessWidget {
  final String texto;
  final VoidCallback? aoTocar;
  final bool destaque;
  final bool pequena;

  const _Tecla(
    this.texto, {
    this.aoTocar,
    this.destaque = false,
    this.pequena = false,
  });

  @override
  Widget build(BuildContext context) {
    final desabilitada = aoTocar == null;
    return Material(
      color: destaque
          ? (desabilitada ? Cores.superficie3 : Cores.laranja)
          : Cores.superficie2,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          // 46px é o mínimo confortável para o polegar em movimento.
          height: 46,
          child: Center(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: pequena ? 12.5 : 19,
                fontWeight: destaque || pequena ? FontWeight.w700 : FontWeight.w600,
                color: destaque
                    ? (desabilitada ? Cores.texto3 : Colors.white)
                    : (pequena ? Cores.texto2 : Cores.tinta),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Contador de quantidade com − e +.
///
/// Para produto vendido por peso o passo é 0,1 kg e o valor aceita casas
/// decimais — 1,238 kg de patinho é caso normal, não exceção.
class ContadorQuantidade extends StatelessWidget {
  final double valor;
  final ValueChanged<double> aoMudar;
  final bool porPeso;
  final String unidade;

  const ContadorQuantidade({
    super.key,
    required this.valor,
    required this.aoMudar,
    this.porPeso = false,
    this.unidade = 'un',
  });

  double get _passo => porPeso ? 0.1 : 1;

  void _somar(double delta) {
    HapticFeedback.selectionClick();
    final novo = ((valor + delta) * 1000).round() / 1000;
    aoMudar(novo < _passo ? _passo : novo);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Cores.linhaForte),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BotaoPasso(icone: Icons.remove, aoTocar: () => _somar(-_passo)),
          Container(
            constraints: const BoxConstraints(minWidth: 62),
            alignment: Alignment.center,
            child: Text(
              valor.emQuantidade,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          _BotaoPasso(icone: Icons.add, aoTocar: () => _somar(_passo)),
        ],
      ),
    );
  }
}

class _BotaoPasso extends StatelessWidget {
  final IconData icone;
  final VoidCallback aoTocar;

  const _BotaoPasso({required this.icone, required this.aoTocar});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Cores.superficie2,
      child: InkWell(
        onTap: aoTocar,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icone, size: 20, color: Cores.texto2),
        ),
      ),
    );
  }
}
