import 'package:bipa_web/extensions/num_extension.dart';
import 'package:bipa_web/models/lista_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testes da conta que aparece na tela.
///
/// Esta é a parte do app que não pode errar: o total é a única promessa que
/// o Bipa faz. E `TotaisLista.calcular` roda no aparelho quando não há
/// conexão, então precisa dar exatamente o mesmo número que o servidor —
/// senão o total pisca ao sincronizar.
void main() {
  group('EntradaCentavos (teclado de caixa)', () {
    test('preenche os centavos da direita para a esquerda', () {
      final e = EntradaCentavos();
      e.digitar('5');
      expect(e.valor, 0.05);
      e.digitar('9');
      expect(e.valor, 0.59);
      e.digitar('9');
      expect(e.valor, 5.99);
      // O intl separa o simbolo do valor com espaco NAO separavel (U+00A0),
      // nao com espaco comum. Comparar com espaco normal falha de um jeito
      // invisivel no terminal.
      expect(e.formatado, 'R\$ 5,99');
    });

    test('apagar volta um dígito', () {
      final e = EntradaCentavos()..definir(5.99);
      e.apagar();
      expect(e.valor, 0.59);
    });

    test('ignora tecla que não é dígito e respeita o teto', () {
      final e = EntradaCentavos();
      e.digitar('x');
      expect(e.vazio, isTrue);
      for (var i = 0; i < 12; i++) {
        e.digitar('9');
      }
      // Acima de R$ 99.999,99 é digitação errada, não compra.
      expect(e.valor, lessThanOrEqualTo(99999.99));
    });
  });

  group('TotaisLista.calcular', () {
    ListaItemModel item({
      required String id,
      double planejada = 1,
      double? estimado,
      bool comprado = false,
      double? quantidade,
      double? preco,
      OrigemItem origem = OrigemItem.planejado,
    }) {
      final total = (comprado && quantidade != null && preco != null)
          ? ((quantidade * preco) * 100).round() / 100
          : null;
      return ListaItemModel(
        id: id,
        listaId: 'lista',
        quantidadePlanejada: planejada,
        precoEstimado: estimado,
        comprado: comprado,
        quantidade: quantidade,
        precoUnitario: preco,
        total: total,
        origem: origem,
      );
    }

    test('soma só o que foi comprado', () {
      final t = TotaisLista.calcular([
        item(id: '1', estimado: 30, comprado: true, quantidade: 1, preco: 27.8),
        item(id: '2', planejada: 2, estimado: 5),
      ]);
      expect(t.totalPago, 27.8);
      expect(t.itensComprados, 1);
      expect(t.itensPendentes, 1);
    });

    test('extra soma no total geral mas é contabilizado à parte', () {
      final t = TotaisLista.calcular([
        item(id: '1', estimado: 30, comprado: true, quantidade: 1, preco: 27.8),
        item(
          id: '2',
          comprado: true,
          quantidade: 2,
          preco: 7.49,
          origem: OrigemItem.extra,
        ),
      ]);
      expect(t.totalPlanejados, 27.8);
      expect(t.totalExtras, 14.98);
      expect(t.totalPago, 42.78);
      expect(t.itensExtras, 1);
      // Extra não tem preço estimado — não pode contar como economia.
      expect(t.economia, closeTo(2.2, 0.001));
    });

    test('economia compara só os itens já comprados', () {
      final t = TotaisLista.calcular([
        item(id: '1', estimado: 10, comprado: true, quantidade: 1, preco: 8),
        // Pendente e caro: não pode entrar na economia no meio da compra.
        item(id: '2', estimado: 500),
      ]);
      expect(t.economia, 2);
    });

    test('produto por peso multiplica quantidade fracionada', () {
      final t = TotaisLista.calcular([
        item(id: '1', comprado: true, quantidade: 1.238, preco: 34.90),
      ]);
      // 1,238 kg x R$ 34,90 = R$ 43,206 -> R$ 43,21
      expect(t.totalPago, 43.21);
    });

    test('saldo do orçamento fica negativo quando estoura', () {
      final t = TotaisLista.calcular(
        [item(id: '1', comprado: true, quantidade: 1, preco: 120)],
        orcamento: 100,
      );
      expect(t.saldoOrcamento, -20);
      expect(t.estourou, isTrue);
    });

    test('sem orçamento não há barra nem saldo', () {
      final t = TotaisLista.calcular(
        [item(id: '1', comprado: true, quantidade: 1, preco: 10)],
      );
      expect(t.saldoOrcamento, isNull);
      expect(t.fracaoOrcamento, isNull);
      expect(t.estourou, isFalse);
    });
  });

  group('formatação pt-BR', () {
    test('valores em reais', () {
      //   = espaco NAO separavel: e o que o intl usa entre o simbolo
      // Atencao: o espaco depois de "R$" nas linhas abaixo e U+00A0 (nao
      // separavel), que e o que o intl usa. Com espaco comum o teste falha
      // mostrando duas strings identicas no terminal.
      expect(1234.5.emReais, 'R\$ 1.234,50');
      expect(0.emReais, 'R\$ 0,00');
    });

    test('quantidade não mostra casas à toa', () {
      expect(3.emQuantidade, '3');
      expect(1.238.emQuantidade, '1,238');
    });

    test('texto pt-BR vira número', () {
      expect(parseValorPtBr('1.234,56'), 1234.56);
      expect(parseValorPtBr(''), isNull);
    });
  });
}
