import 'package:flutter/material.dart';

import '../extensions/num_extension.dart';
import '../models/lista_model.dart';
import 'cores.dart';

/// Numeral condensado dos valores em reais — a "etiqueta de preço" do app.
/// Tabular para os dígitos não dançarem enquanto o total sobe.
TextStyle estiloValor(double tamanho, {Color? cor}) => TextStyle(
      fontSize: tamanho,
      fontWeight: FontWeight.w700,
      color: cor ?? Cores.tinta,
      letterSpacing: -0.5,
      height: 1.05,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

const rotulo = TextStyle(
  fontSize: 10.5,
  fontWeight: FontWeight.w600,
  letterSpacing: 1.1,
  color: Cores.texto3,
);

/// Código de barras desenhado, não glifo de fonte.
///
/// O `Icons.barcode_reader` do Material vira um borrão nos tamanhos que a
/// interface usa. Como este é o símbolo da ação principal do app, ele é
/// desenhado — barras de larguras variadas, iguais às do mockup aprovado.
class IconeBarras extends StatelessWidget {
  final double tamanho;
  final Color cor;

  const IconeBarras({super.key, this.tamanho = 22, this.cor = Colors.white});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: tamanho,
        height: tamanho,
        child: CustomPaint(painter: _PintorBarras(cor)),
      );
}

class _PintorBarras extends CustomPainter {
  final Color cor;

  _PintorBarras(this.cor);

  // Larguras relativas: o ritmo irregular é o que faz ler como código de
  // barras, e não como um pente.
  static const _larguras = [0.13, 0.07, 0.17, 0.07, 0.13, 0.07];

  @override
  void paint(Canvas canvas, Size size) {
    final tinta = Paint()..color = cor;
    final vao = 0.06 * size.width;
    final total = _larguras.fold<double>(0, (a, b) => a + b) * size.width +
        vao * (_larguras.length - 1);
    var x = (size.width - total) / 2;
    final topo = size.height * 0.12;
    final alturaCheia = size.height * 0.76;

    for (var i = 0; i < _larguras.length; i++) {
      final largura = _larguras[i] * size.width;
      // Barras alternadas ficam mais curtas, como num código real.
      final altura = i.isEven ? alturaCheia : alturaCheia * 0.82;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, topo + (alturaCheia - altura) / 2, largura, altura),
          Radius.circular(largura * 0.3),
        ),
        tinta,
      );
      x += largura + vao;
    }
  }

  @override
  bool shouldRepaint(_PintorBarras anterior) => anterior.cor != cor;
}

/// Etiqueta pequena de estado. Estado nunca é comunicado só por cor: sempre
/// vem com texto, para funcionar em qualquer tipo de visão.
class Etiqueta extends StatelessWidget {
  final String texto;
  final Color cor;
  final Color fundo;
  final IconData? icone;

  const Etiqueta(
    this.texto, {
    super.key,
    this.cor = Cores.texto2,
    this.fundo = Cores.superficie2,
    this.icone,
  });

  factory Etiqueta.economia(double valor) => Etiqueta(
        valor.emReais,
        cor: Cores.verde,
        fundo: Cores.verdeSuave,
        icone: Icons.arrow_downward,
      );

  factory Etiqueta.estouro(double valor) => Etiqueta(
        valor.abs().emReais,
        cor: Cores.carmim,
        fundo: Cores.carmimSuave,
        icone: Icons.arrow_upward,
      );

  factory Etiqueta.extra() => const Etiqueta(
        'extra',
        cor: Cores.laranjaEscuro,
        fundo: Cores.laranjaSuave,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icone != null) ...[
            Icon(icone, size: 12, color: cor),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diferença entre o estimado e o pago.
///
/// A seta é ícone, não caractere: `↓` e `↑` não existem na fonte que o Flutter
/// Web carrega e apareciam como quadrado vazio na tela.
///
/// Positivo = economizou (verde, seta para baixo). Negativo = passou do
/// previsto (carmim, seta para cima). O sinal nunca fica só na cor — vem
/// sempre com a seta e, quando cabe, com a palavra.
class DeltaValor extends StatelessWidget {
  final double valor;
  final double tamanho;
  final String? sufixo;
  final bool ehTotal;

  const DeltaValor(
    this.valor, {
    super.key,
    this.tamanho = 11,
    this.sufixo,
    this.ehTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final economizou = valor > 0;
    final cor = economizou ? Cores.verde : Cores.carmim;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          economizou ? Icons.arrow_downward : Icons.arrow_upward,
          size: tamanho + 1,
          color: cor,
        ),
        const SizedBox(width: 2),
        Text(
          '${ehTotal ? valor.abs().emReais : valor.abs().emValor}'
          '${sufixo == null ? '' : ' $sufixo'}',
          style: TextStyle(
            fontSize: tamanho,
            fontWeight: FontWeight.w600,
            color: cor,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Barra de orçamento com marcador do estimado.
///
/// Responde a pergunta real do corredor: dá pra levar? O marcador mostra se a
/// compra está indo melhor ou pior que o previsto — não só quanto sobrou.
class BarraOrcamento extends StatelessWidget {
  final TotaisLista totais;
  final bool compacta;

  const BarraOrcamento(this.totais, {super.key, this.compacta = false});

  @override
  Widget build(BuildContext context) {
    final fracao = totais.fracaoOrcamento;
    if (fracao == null) return const SizedBox.shrink();

    final estourou = totais.estourou;
    final corBarra = estourou ? Cores.carmim : Cores.laranja;
    final marcador = totais.orcamento == null || totais.orcamento == 0
        ? null
        : (totais.totalEstimado / totais.orcamento!).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, restricoes) {
            final largura = restricoes.maxWidth;
            return SizedBox(
              height: 12,
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: Cores.superficie3,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: fracao.clamp(0.0, 1.0),
                    child: Container(
                      height: 7,
                      decoration: BoxDecoration(
                        color: corBarra,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  if (marcador != null)
                    Positioned(
                      left: (largura * marcador).clamp(0.0, largura - 2),
                      child: Container(
                        width: 2,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Cores.texto2.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        if (!compacta) ...[
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(fracao * 100).round()}% de ${totais.orcamento!.emReais}',
                style: const TextStyle(fontSize: 11, color: Cores.texto3),
              ),
              Text(
                estourou
                    ? 'passou ${totais.saldoOrcamento!.abs().emReais}'
                    : 'restam ${totais.saldoOrcamento!.emReais}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: estourou ? FontWeight.w600 : FontWeight.w400,
                  color: estourou ? Cores.carmim : Cores.texto3,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Cartão neutro do app.
class Cartao extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? cor;
  final VoidCallback? aoTocar;
  final Border? borda;

  const Cartao({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.cor,
    this.aoTocar,
    this.borda,
  });

  @override
  Widget build(BuildContext context) {
    final conteudo = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cor ?? Cores.superficie2,
        borderRadius: BorderRadius.circular(15),
        border: borda,
      ),
      child: child,
    );
    if (aoTocar == null) return conteudo;
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(15),
      child: conteudo,
    );
  }
}

/// Botão de ação principal. Alto (54px) porque no supermercado o toque é
/// apressado, com uma mão só e o carrinho na outra.
class BotaoPrincipal extends StatelessWidget {
  final String texto;
  final VoidCallback? aoTocar;
  final IconData? icone;
  final bool carregando;
  final Color? cor;
  final double altura;

  /// Alternativa a [icone] quando o símbolo é desenhado (ver [IconeBarras]).
  final Widget? icone2;

  const BotaoPrincipal(
    this.texto, {
    super.key,
    this.aoTocar,
    this.icone,
    this.icone2,
    this.carregando = false,
    this.cor,
    this.altura = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: cor ?? Cores.laranja,
          disabledBackgroundColor: Cores.superficie3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: carregando ? null : aoTocar,
        child: carregando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.2, color: Colors.white),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icone2 != null) ...[
                    icone2!,
                    const SizedBox(width: 10),
                  ] else if (icone != null) ...[
                    Icon(icone, size: 21),
                    const SizedBox(width: 9),
                  ],
                  Text(
                    texto,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class BotaoSecundario extends StatelessWidget {
  final String texto;
  final VoidCallback? aoTocar;
  final IconData? icone;
  final Color? cor;

  const BotaoSecundario(this.texto,
      {super.key, this.aoTocar, this.icone, this.cor});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Cores.linhaForte, width: 1.4),
          foregroundColor: cor ?? Cores.tinta,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
        ),
        onPressed: aoTocar,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icone != null) ...[
              Icon(icone, size: 18),
              const SizedBox(width: 8),
            ],
            Text(texto,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Cabeçalho de categoria = corredor do mercado.
class TituloCategoria extends StatelessWidget {
  final String texto;
  final int quantidade;

  const TituloCategoria(this.texto, {super.key, this.quantidade = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
      child: Row(
        children: [
          Text(
            quantidade > 0
                ? '${texto.toUpperCase()} · $quantidade'
                : texto.toUpperCase(),
            style: rotulo,
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Cores.linha, height: 1)),
        ],
      ),
    );
  }
}

/// Estado vazio — sempre com o próximo passo, nunca só "nada aqui".
class VazioComAcao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final String? textoBotao;
  final VoidCallback? aoTocar;

  const VazioComAcao({
    super.key,
    required this.icone,
    required this.titulo,
    required this.descricao,
    this.textoBotao,
    this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: const BoxDecoration(
                color: Cores.superficie2,
                shape: BoxShape.circle,
              ),
              child: Icon(icone, size: 28, color: Cores.texto3),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Cores.texto2, height: 1.45),
            ),
            if (textoBotao != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 220,
                child: BotaoPrincipal(textoBotao!, aoTocar: aoTocar),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
