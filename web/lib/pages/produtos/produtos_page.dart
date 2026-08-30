import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/listas_controller.dart';
import '../../models/produto_model.dart';
import '../../offline/repositorio_listas.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import 'historico_produto_page.dart';

/// Catálogo do usuário. Tocar num produto abre o histórico de preços dele.
class ProdutosPage extends StatefulWidget {
  const ProdutosPage({super.key});

  @override
  State<ProdutosPage> createState() => _ProdutosPageState();
}

class _ProdutosPageState extends State<ProdutosPage> {
  final _listas = Get.find<ListasController>();
  final _busca = TextEditingController();
  final _produtos = <ProdutoModel>[].obs;
  final _carregando = false.obs;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _carregar('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar(String termo) async {
    _carregando.value = true;
    try {
      _produtos.value = termo.trim().isEmpty
          ? await RepositorioListas.buscarProdutos('', limite: 200)
          : await _listas.buscarProdutos(termo);
    } finally {
      _carregando.value = false;
    }
  }

  void _aoDigitar(String termo) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), () => _carregar(termo));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.fundo,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Produtos',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _busca,
                    onChanged: _aoDigitar,
                    decoration: InputDecoration(
                      hintText: 'Buscar no catálogo',
                      hintStyle:
                          const TextStyle(color: Cores.texto3, fontSize: 14),
                      prefixIcon: const Icon(Icons.search,
                          size: 20, color: Cores.texto3),
                      filled: true,
                      fillColor: Cores.superficie,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(color: Cores.linha),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(color: Cores.linha),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide:
                            const BorderSide(color: Cores.laranja, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Obx(() {
                if (_carregando.value && _produtos.isEmpty) {
                  return const Center(
                      child: CircularProgressIndicator(color: Cores.laranja));
                }
                if (_produtos.isEmpty) {
                  return const VazioComAcao(
                    icone: Icons.inventory_2_outlined,
                    titulo: 'Catálogo vazio',
                    descricao:
                        'Os produtos aparecem aqui conforme você bipa ou '
                        'adiciona itens às listas.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: _produtos.length,
                  itemBuilder: (_, i) => _Linha(_produtos[i]),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final ProdutoModel produto;

  const _Linha(this.produto);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.to(() => HistoricoProdutoPage(produto: produto)),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Cores.linha)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(produto.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      produto.marca,
                      produto.categoriaNome,
                      produto.ean,
                    ].where((e) => e != null && e.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 11.5, color: Cores.texto3),
                  ),
                ],
              ),
            ),
            if (produto.tipoVenda.ehPeso) ...[
              const Etiqueta('por peso'),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_right, size: 20, color: Cores.texto3),
          ],
        ),
      ),
    );
  }
}
