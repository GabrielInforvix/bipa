import 'package:flutter/material.dart';

import '../extensions/num_extension.dart';
import '../models/lista_model.dart';
import 'componentes.dart';
import 'cores.dart';

/// Uma linha de item, usada no planejamento e no Modo Compra.
///
/// Comprados ficam na MESMA lista dos pendentes, riscados e com a economia ao
/// lado — trocar de aba para conferir o que já entrou no carrinho custaria um
/// toque a cada produto.
class LinhaItem extends StatelessWidget {
  final ListaItemModel item;
  final VoidCallback? aoTocar;
  final VoidCallback? aoAlternar;
  final bool mostrarEstimado;

  /// Inicial de OUTRA pessoa que comprou/adicionou o item, nas listas
  /// compartilhadas. Nulo = foi você mesmo, ou a lista é só sua.
  final String? inicialOutro;

  const LinhaItem(
    this.item, {
    super.key,
    this.aoTocar,
    this.aoAlternar,
    this.mostrarEstimado = false,
    this.inicialOutro,
  });

  @override
  Widget build(BuildContext context) {
    final diferenca = item.diferenca;

    return InkWell(
      onTap: aoTocar,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Cores.linha)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: aoAlternar,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(right: 11),
                child: _Marcador(comprado: item.comprado),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: item.comprado ? Cores.texto3 : Cores.tinta,
                            decoration: item.comprado
                                ? TextDecoration.lineThrough
                                : null,
                            decorationThickness: 1.4,
                          ),
                        ),
                      ),
                      if (item.origem.ehExtra) ...[
                        const SizedBox(width: 7),
                        Etiqueta.extra(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitulo(),
                    style: const TextStyle(fontSize: 11.5, color: Cores.texto3),
                  ),
                ],
              ),
            ),
            if (inicialOutro != null) ...[
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Cores.superficie3,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    inicialOutro!,
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Cores.texto2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  (item.comprado
                          ? (item.total ?? 0)
                          : (mostrarEstimado ? item.totalEstimado : 0))
                      .emReais,
                  style: estiloValor(
                    14,
                    cor: item.comprado ? Cores.tinta : Cores.texto3,
                  ),
                ),
                if (diferenca != null && diferenca.abs() >= 0.01) ...[
                  const SizedBox(height: 2),
                  DeltaValor(diferenca, tamanho: 10.5),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Comprado mostra o que foi pago; pendente mostra o que se espera pagar.
  String _subtitulo() {
    final unidade = item.ehPeso ? 'kg' : item.unidade;
    if (item.comprado && item.precoUnitario != null) {
      final preco = item.precoUnitario!.emReais;
      return '${item.quantidadeAtual.emQuantidade} $unidade × '
          '${item.ehPeso ? '$preco/kg' : preco}';
    }
    final estimado = item.precoEstimado;
    final base = '${item.quantidadePlanejada.emQuantidade} $unidade';
    if (estimado == null) return base;
    return '$base · ~${estimado.emReais}${item.ehPeso ? '/kg' : ''}';
  }
}

class _Marcador extends StatelessWidget {
  final bool comprado;

  const _Marcador({required this.comprado});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: comprado ? Cores.verde : Colors.transparent,
        border: Border.all(
          color: comprado ? Cores.verde : Cores.linhaForte,
          width: 1.6,
        ),
        borderRadius: BorderRadius.circular(99),
      ),
      child: comprado
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : null,
    );
  }
}
