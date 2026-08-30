import 'package:bipa_web/models/lista_model.dart';
import 'package:bipa_web/pages/listas/folha_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Teste de interação da folha de edição do item.
///
/// Existe porque o teclado de preço não é o do sistema: é um widget nosso, com
/// entrada em centavos da direita para a esquerda. Se ele quebrar, o usuário
/// digita um preço e outro entra na lista — e ninguém percebe até fechar a
/// compra com o total errado.
/// O `intl` separa "R$" do valor com espaço NÃO separável (U+00A0). Procurar
/// com espaço comum falha mostrando duas strings idênticas no terminal — por
/// isso todo valor em reais é procurado por aqui.
Finder acharReais(String valor) => find.text('R\$ $valor');

void main() {
  ListaItemModel item({
    String? produtoId = 'produto-1',
    String? nomeLivre,
    double quantidade = 1,
    double? precoEstimado,
    bool comprado = false,
  }) =>
      ListaItemModel(
        id: 'item-1',
        listaId: 'lista-1',
        produtoId: produtoId,
        nomeLivre: nomeLivre,
        quantidadePlanejada: quantidade,
        precoEstimado: precoEstimado,
        comprado: comprado,
        total: comprado ? 10 : null,
      );

  /// Monta a folha isolada e devolve o que o "Salvar" entregou.
  Future<Map<String, dynamic>> abrir(
    WidgetTester tester,
    ListaItemModel alvo, {
    bool removerEmVez = false,
  }) async {
    final capturado = <String, dynamic>{};

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FolhaItem(
          item: alvo,
          aoSalvar: ({
            required double quantidade,
            double? precoEstimado,
            String? unidade,
            String? nomeLivre,
          }) async {
            capturado['quantidade'] = quantidade;
            capturado['precoEstimado'] = precoEstimado;
            capturado['unidade'] = unidade;
            capturado['nomeLivre'] = nomeLivre;
          },
          aoRemover: () async => capturado['removido'] = true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return capturado;
  }

  testWidgets('teclado monta o preço em centavos, da direita para a esquerda',
      (tester) async {
    final capturado = await abrir(tester, item());

    // 5 -> 0,05 · 9 -> 0,59 · 9 -> 5,99
    // Com quantidade 1, preço unitário e total mostram o mesmo valor — daí
    // `findsWidgets`. A conferência exata é no que chega ao `aoSalvar`.
    await tester.tap(find.widgetWithText(SizedBox, '5').first);
    await tester.pump();
    expect(acharReais('0,05'), findsWidgets);

    await tester.tap(find.widgetWithText(SizedBox, '9').first);
    await tester.pump();
    await tester.tap(find.widgetWithText(SizedBox, '9').first);
    await tester.pump();
    expect(acharReais('5,99'), findsWidgets);

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(capturado['precoEstimado'], 5.99);
    expect(capturado['quantidade'], 1);
  });

  testWidgets('somar quantidade recalcula o estimado do item', (tester) async {
    await abrir(tester, item(precoEstimado: 5));

    // Começa em 1 x R$ 5,00.
    expect(acharReais('5,00'), findsWidgets);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // 3 x R$ 5,00 = R$ 15,00
    expect(find.text('3'), findsWidgets);
    expect(acharReais('15,00'), findsOneWidget);
  });

  testWidgets('quantidade nunca desce abaixo do passo', (tester) async {
    await abrir(tester, item());
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
    }
    // Item com quantidade zero não faria sentido na lista.
    expect(find.text('1'), findsWidgets);
  });

  testWidgets('item escrito na mão permite editar nome e trocar para kg',
      (tester) async {
    final capturado = await abrir(
      tester,
      item(produtoId: null, nomeLivre: 'Pão'),
    );

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Pão francês');

    await tester.tap(find.text('kg'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(capturado['nomeLivre'], 'Pão francês');
    expect(capturado['unidade'], 'kg');
  });

  testWidgets('item do catálogo não deixa editar o nome', (tester) async {
    // O nome vem do catálogo global; mudar ali afetaria todo mundo. Quem quer
    // outro nome usa o apelido, não esta tela.
    await abrir(tester, item(produtoId: 'produto-1'));
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('item já comprado avisa que o preço pago não muda aqui',
      (tester) async {
    await abrir(tester, item(comprado: true));
    expect(find.textContaining('Já comprado'), findsOneWidget);
    expect(find.textContaining('Modo Compra'), findsOneWidget);
  });

  testWidgets('remover avisa quem chamou', (tester) async {
    final capturado = await abrir(tester, item());
    await tester.tap(find.text('Remover da lista'));
    await tester.pumpAndSettle();
    expect(capturado['removido'], true);
  });
}
