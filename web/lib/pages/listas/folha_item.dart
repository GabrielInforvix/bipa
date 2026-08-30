import 'package:flutter/material.dart';

import '../../extensions/num_extension.dart';
import '../../models/lista_model.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/teclado_preco.dart';

/// Edição do que foi **planejado** para um item: quantidade, preço estimado e,
/// quando o item foi escrito na mão, o nome e a unidade.
///
/// Não mexe no que já foi comprado — preço pago é registrado no Modo Compra e
/// fica congelado no item (regra 7). Por isso um item já comprado abre aqui
/// só para consulta e remoção.
class FolhaItem extends StatefulWidget {
  final ListaItemModel item;
  final Future<void> Function({
    required double quantidade,
    double? precoEstimado,
    String? unidade,
    String? nomeLivre,
  }) aoSalvar;
  final Future<void> Function() aoRemover;

  const FolhaItem({
    super.key,
    required this.item,
    required this.aoSalvar,
    required this.aoRemover,
  });

  static Future<bool?> abrir(
    BuildContext context, {
    required ListaItemModel item,
    required Future<void> Function({
      required double quantidade,
      double? precoEstimado,
      String? unidade,
      String? nomeLivre,
    }) aoSalvar,
    required Future<void> Function() aoRemover,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FolhaItem(
        item: item,
        aoSalvar: aoSalvar,
        aoRemover: aoRemover,
      ),
    );
  }

  @override
  State<FolhaItem> createState() => _FolhaItemState();
}

class _FolhaItemState extends State<FolhaItem> {
  late EntradaCentavos _preco;
  late double _quantidade;
  late bool _porPeso;
  late TextEditingController _nome;
  bool _salvando = false;

  /// Item sem produto do catálogo: o usuário escreveu o nome, então pode
  /// editá-lo e escolher a unidade.
  bool get _escritoNaMao => widget.item.produtoId == null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _quantidade = item.quantidadePlanejada;
    _porPeso = item.ehPeso;
    _nome = TextEditingController(text: item.nomeLivre ?? item.nome);
    _preco = EntradaCentavos();
    if (item.precoEstimado != null) _preco.definir(item.precoEstimado!);
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    await widget.aoSalvar(
      quantidade: _quantidade,
      precoEstimado: _preco.vazio ? null : _preco.valor,
      unidade: _escritoNaMao ? (_porPeso ? 'kg' : 'un') : null,
      nomeLivre:
          _escritoNaMao && _nome.text.trim().isNotEmpty ? _nome.text.trim() : null,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final total = _preco.valor * _quantidade;

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
      child: SingleChildScrollView(
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

            if (_escritoNaMao)
              TextField(
                controller: _nome,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Cores.superficie2,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 13, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Cores.laranja, width: 1.5),
                  ),
                ),
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nome,
                      style: const TextStyle(
                          fontSize: 16.5, fontWeight: FontWeight.w700),
                    ),
                    if (item.marca != null)
                      Text(
                        item.marca!,
                        style: const TextStyle(
                            fontSize: 12, color: Cores.texto3),
                      ),
                  ],
                ),
              ),

            if (item.comprado) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Cores.verdeSuave,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Já comprado por ${(item.total ?? 0).emReais}. O preço pago '
                  'não muda aqui — use o Modo Compra para corrigir.',
                  style: const TextStyle(
                      fontSize: 12.5, color: Cores.verde, height: 1.4),
                ),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                ContadorQuantidade(
                  valor: _quantidade,
                  porPeso: _porPeso,
                  aoMudar: (v) => setState(() => _quantidade = v),
                ),
                const SizedBox(width: 10),
                if (_escritoNaMao)
                  SegmentedButton<bool>(
                    style: SegmentedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      selectedBackgroundColor: Cores.laranjaSuave,
                      selectedForegroundColor: Cores.laranjaEscuro,
                      side: const BorderSide(color: Cores.linhaForte),
                    ),
                    segments: const [
                      ButtonSegment(value: false, label: Text('un')),
                      ButtonSegment(value: true, label: Text('kg')),
                    ],
                    selected: {_porPeso},
                    onSelectionChanged: (s) =>
                        setState(() => _porPeso = s.first),
                  )
                else
                  Text(
                    item.ehPeso ? 'kg' : 'un',
                    style:
                        const TextStyle(fontSize: 13, color: Cores.texto3),
                  ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _porPeso ? 'PREÇO POR KG' : 'PREÇO ESTIMADO',
                      style: rotulo,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _preco.formatado,
                      style: estiloValor(24, cor: Cores.laranjaEscuro),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: Cores.superficie2,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ESTIMADO PARA ESSE ITEM', style: rotulo),
                  Text(total.emReais, style: estiloValor(22)),
                ],
              ),
            ),

            const SizedBox(height: 12),
            TecladoPreco(
              entrada: _preco,
              textoConfirmar: _salvando ? '···' : 'OK',
              aoMudar: (nova) => setState(() => _preco = nova),
              aoConfirmar: _salvando ? () {} : _salvar,
            ),

            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: BotaoSecundario(
                    'Remover da lista',
                    icone: Icons.delete_outline,
                    cor: Cores.carmim,
                    aoTocar: () async {
                      await widget.aoRemover();
                      if (context.mounted) Navigator.pop(context, true);
                    },
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: BotaoPrincipal(
                    'Salvar',
                    altura: 46,
                    carregando: _salvando,
                    aoTocar: _salvar,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
