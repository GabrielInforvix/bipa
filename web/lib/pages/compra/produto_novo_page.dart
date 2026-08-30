import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/compra_controller.dart';
import '../../controllers/listas_controller.dart';
import '../../models/produto_model.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';

/// Cadastro rápido de produto — o último degrau da cascata.
///
/// O usuário só chega aqui quando o catálogo local e o Open Food Facts
/// falharam. Por isso são quatro campos, um deles opcional: ninguém preenche
/// formulário em pé no corredor com o carrinho na frente.
class ProdutoNovoPage extends StatefulWidget {
  final String? ean;
  final bool porPeso;
  final String? aviso;

  const ProdutoNovoPage({
    super.key,
    this.ean,
    this.porPeso = false,
    this.aviso,
  });

  @override
  State<ProdutoNovoPage> createState() => _ProdutoNovoPageState();
}

class _ProdutoNovoPageState extends State<ProdutoNovoPage> {
  final _compra = Get.find<CompraController>();
  final _listas = Get.find<ListasController>();
  final _nome = TextEditingController();
  final _marca = TextEditingController();

  late TipoVenda _tipoVenda;
  String? _categoriaId;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _tipoVenda = widget.porPeso ? TipoVenda.peso : TipoVenda.unidade;
  }

  @override
  void dispose() {
    _nome.dispose();
    _marca.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_nome.text.trim().length < 2) return;
    setState(() => _salvando = true);
    final categoria =
        _listas.categorias.firstWhereOrNull((c) => c.id == _categoriaId);
    final produto = await _compra.cadastrarProduto(
      nome: _nome.text.trim(),
      ean: widget.ean,
      marca: _marca.text.trim().isEmpty ? null : _marca.text.trim(),
      tipoVenda: _tipoVenda,
      categoriaId: _categoriaId,
      categoriaNome: categoria?.nome,
    );
    Get.back(result: produto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.superficie,
      appBar: AppBar(
        backgroundColor: Cores.superficie,
        surfaceTintColor: Colors.transparent,
        title: const Text('Produto novo',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Get.back(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          if (widget.aviso != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Cores.laranjaSuave,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 18, color: Cores.laranjaEscuro),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      widget.aviso!,
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: Cores.laranjaEscuro,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (widget.ean != null) ...[
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                border: Border.all(
                    color: Cores.linhaForte, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  const Icon(Icons.barcode_reader,
                      size: 22, color: Cores.texto3),
                  const SizedBox(width: 11),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CÓDIGO LIDO · NÃO ENCONTRADO',
                          style: rotulo),
                      const SizedBox(height: 2),
                      Text(
                        widget.ean!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const Text('NOME DO PRODUTO', style: rotulo),
          const SizedBox(height: 6),
          TextField(
            controller: _nome,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoracao('Ex.: Biscoito água e sal 200g'),
            onSubmitted: (_) => _salvar(),
          ),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MARCA (OPCIONAL)', style: rotulo),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _marca,
                      textCapitalization: TextCapitalization.words,
                      decoration: _decoracao('Ex.: Piraquê'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('VENDIDO POR', style: rotulo),
                    const SizedBox(height: 6),
                    SegmentedButton<TipoVenda>(
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor: Cores.laranjaSuave,
                        selectedForegroundColor: Cores.laranjaEscuro,
                        side: const BorderSide(color: Cores.linhaForte),
                      ),
                      segments: const [
                        ButtonSegment(
                            value: TipoVenda.unidade, label: Text('un')),
                        ButtonSegment(value: TipoVenda.peso, label: Text('kg')),
                      ],
                      selected: {_tipoVenda},
                      onSelectionChanged: (s) =>
                          setState(() => _tipoVenda = s.first),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          const Text('CATEGORIA', style: rotulo),
          const SizedBox(height: 8),
          Obx(() => Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final c in _listas.categorias)
                    GestureDetector(
                      onTap: () => setState(
                          () => _categoriaId = _categoriaId == c.id ? null : c.id),
                      child: Etiqueta(
                        c.icone == null ? c.nome : '${c.icone} ${c.nome}',
                        cor: _categoriaId == c.id
                            ? Cores.laranjaEscuro
                            : Cores.texto2,
                        fundo: _categoriaId == c.id
                            ? Cores.laranjaSuave
                            : Cores.superficie2,
                      ),
                    ),
                ],
              )),
          const SizedBox(height: 18),

          // Transforma o trabalho chato em contribuição: é assim que o
          // catálogo colaborativo cresce.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Cores.verdeSuave,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.auto_awesome, size: 17, color: Cores.verde),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Ao salvar, esse código passa a ser reconhecido '
                    'automaticamente por todo mundo que usa o Bipa.',
                    style: TextStyle(
                        fontSize: 12.5, color: Cores.verde, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          BotaoPrincipal(
            'Salvar e informar preço',
            carregando: _salvando,
            aoTocar: _salvar,
          ),
        ],
      ),
    );
  }

  InputDecoration _decoracao(String dica) => InputDecoration(
        hintText: dica,
        hintStyle: const TextStyle(color: Cores.texto3, fontSize: 14),
        filled: true,
        fillColor: Cores.superficie2,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Cores.laranja, width: 1.6),
        ),
      );
}
