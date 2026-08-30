import 'package:flutter/material.dart';

import '../extensions/num_extension.dart';
import '../models/produto_model.dart';
import 'cores.dart';

/// Evolução do preço pago pelo produto.
///
/// Série única, então não precisa de legenda — o título já diz o que é.
/// Só dois pontos ganham marcação: o menor preço, com rótulo, e o atual, em
/// destaque. Rótulo em todo ponto vira ruído e ninguém lê.
class GraficoPrecos extends StatelessWidget {
  final HistoricoPrecos historico;

  const GraficoPrecos(this.historico, {super.key});

  @override
  Widget build(BuildContext context) {
    // Do mais antigo para o mais novo — o histórico vem invertido da API.
    final pontos = historico.registros.reversed.toList();
    if (pontos.length < 2) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Cores.superficie2,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Text(
          'Compre esse produto mais vezes para ver a\nevolução do preço.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Cores.texto3, height: 1.5),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      decoration: BoxDecoration(
        color: Cores.superficie2,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PREÇO PAGO · ${pontos.length} COMPRAS',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                  color: Cores.texto3,
                ),
              ),
              if (historico.ultimo != null && historico.menor != null)
                Text(
                  historico.ultimo == historico.menor
                      ? 'menor preço'
                      : '${historico.ultimo!.emReais} agora',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: historico.ultimo == historico.menor
                        ? Cores.verde
                        : Cores.texto2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 108,
            width: double.infinity,
            child: CustomPaint(painter: _PintorPrecos(pontos)),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final p in _rotulosEixo(pontos))
                Text(
                  p,
                  style: const TextStyle(fontSize: 9.5, color: Cores.texto3),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// No máximo 6 rótulos no eixo — mais que isso se sobrepõe na tela do
  /// celular e vira borrão.
  List<String> _rotulosEixo(List<RegistroPreco> pontos) {
    const meses = [
      'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN',
      'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ',
    ];
    if (pontos.length <= 6) {
      return pontos.map((p) => meses[p.data.month - 1]).toList();
    }
    final passo = (pontos.length / 6).ceil();
    return [
      for (var i = 0; i < pontos.length; i += passo)
        meses[pontos[i].data.month - 1],
    ];
  }
}

class _PintorPrecos extends CustomPainter {
  final List<RegistroPreco> pontos;

  _PintorPrecos(this.pontos);

  @override
  void paint(Canvas canvas, Size size) {
    final precos = pontos.map((p) => p.preco).toList();
    var minimo = precos.reduce((a, b) => a < b ? a : b);
    var maximo = precos.reduce((a, b) => a > b ? a : b);
    // Respiro para a linha não encostar nas bordas do quadro.
    final folga = (maximo - minimo) * 0.25;
    minimo -= folga == 0 ? 1 : folga;
    maximo += folga == 0 ? 1 : folga;

    const margem = 6.0;
    final largura = size.width - margem * 2;
    final altura = size.height - 14;

    double x(int i) =>
        margem + (pontos.length == 1 ? largura / 2 : largura * i / (pontos.length - 1));
    double y(double v) => altura * (maximo - v) / (maximo - minimo);

    // Grade discreta — presente para dar referência, apagada para não competir.
    final grade = Paint()
      ..color = Cores.linhaForte.withValues(alpha: 0.45)
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final gy = altura * i / 4;
      _tracejada(canvas, Offset(0, gy), Offset(size.width, gy), grade);
    }

    final caminho = Path();
    for (var i = 0; i < pontos.length; i++) {
      final ponto = Offset(x(i), y(precos[i]));
      i == 0 ? caminho.moveTo(ponto.dx, ponto.dy) : caminho.lineTo(ponto.dx, ponto.dy);
    }

    // Área sob a linha, esmaecendo para baixo.
    final area = Path.from(caminho)
      ..lineTo(x(pontos.length - 1), altura)
      ..lineTo(x(0), altura)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Cores.laranja.withValues(alpha: 0.26),
            Cores.laranja.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, altura)),
    );

    canvas.drawPath(
      caminho,
      Paint()
        ..color = Cores.laranja
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Menor preço: anel verde + rótulo. Verde aqui é status, e vem sempre
    // acompanhado do texto — nunca cor sozinha.
    final iMenor = precos.indexOf(precos.reduce((a, b) => a < b ? a : b));
    final pMenor = Offset(x(iMenor), y(precos[iMenor]));
    canvas.drawCircle(pMenor, 4.5, Paint()..color = Cores.superficie2);
    canvas.drawCircle(pMenor, 4, Paint()..color = Cores.verde);

    final rotulo = TextPainter(
      text: TextSpan(
        text: 'menor ${precos[iMenor].emValor}',
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: Cores.verde,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    rotulo.paint(
      canvas,
      Offset(
        (pMenor.dx - rotulo.width / 2).clamp(0.0, size.width - rotulo.width),
        (pMenor.dy + 8).clamp(0.0, altura + 2),
      ),
    );

    // Ponto atual em destaque, com anel da cor do fundo para descolar da linha.
    final pAtual = Offset(x(pontos.length - 1), y(precos.last));
    canvas.drawCircle(pAtual, 6, Paint()..color = Cores.superficie2);
    canvas.drawCircle(pAtual, 4.5, Paint()..color = Cores.laranja);
  }

  void _tracejada(Canvas canvas, Offset de, Offset ate, Paint tinta) {
    const traco = 2.0, vao = 4.0;
    var x = de.dx;
    while (x < ate.dx) {
      canvas.drawLine(
        Offset(x, de.dy),
        Offset((x + traco).clamp(0, ate.dx), ate.dy),
        tinta,
      );
      x += traco + vao;
    }
  }

  @override
  bool shouldRepaint(_PintorPrecos anterior) => anterior.pontos != pontos;
}
