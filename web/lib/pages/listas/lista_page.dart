import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/listas_controller.dart';
import '../../extensions/num_extension.dart';
import '../../globais/parametros_globais.dart';
import '../../models/lista_model.dart';
import '../../models/produto_model.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/feedback.dart';
import '../../widget/item_lista.dart';
import '../../widget/pedir_conta.dart';
import 'folha_compartilhar.dart';
import 'folha_item.dart';

/// Planejamento da lista — a tela usada em casa, sem pressa.
///
/// Busca e código de barras compartilham o mesmo campo: em casa se digita,
/// no mercado se bipa. E cada item já mostra o último preço pago, que é a
/// estimativa que o usuário não precisa digitar.
class ListaPage extends StatefulWidget {
  const ListaPage({super.key});

  @override
  State<ListaPage> createState() => _ListaPageState();
}

class _ListaPageState extends State<ListaPage> {
  final _listas = Get.find<ListasController>();
  final _busca = TextEditingController();

  final _lista = Rxn<ListaModel>();
  final _sugestoes = <ProdutoModel>[].obs;
  final _buscando = false.obs;
  final _termo = ''.obs;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    await _listas.recarregar();
    // Sem argumento (recarga da página) cai na lista mais recente em vez de
    // ficar girando.
    final id = (Get.arguments as String?) ??
        _listas.emCompra?.id ??
        _listas.rascunhos.firstOrNull?.id;
    if (id == null) {
      Get.offAllNamed('/inicio');
      return;
    }
    _lista.value = _listas.listas.firstWhereOrNull((l) => l.id == id);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    super.dispose();
  }

  /// Espera o usuário parar de digitar antes de buscar — cada tecla disparando
  /// uma consulta deixaria a lista piscando.
  void _aoDigitar(String termo) {
    _debounce?.cancel();
    _termo.value = termo.trim();
    if (termo.trim().isEmpty) {
      _sugestoes.clear();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      _buscando.value = true;
      try {
        _sugestoes.value = await _listas.buscarProdutos(termo);
      } finally {
        _buscando.value = false;
      }
    });
  }

  Future<void> _adicionar(ProdutoModel produto) async {
    final lista = _lista.value;
    if (lista == null) return;
    _limparBusca();
    final nova = await _listas.adicionarItem(lista, produto: produto);
    _lista.value = nova;
    Aviso.sucesso('${produto.nome} entrou na lista.');
  }

  /// Item escrito na mão, sem produto do catálogo — "pão na padaria", "gelo".
  /// Nem tudo que entra no carrinho tem código de barras.
  Future<void> _adicionarPeloNome(String nome) async {
    final lista = _lista.value;
    if (lista == null || nome.trim().isEmpty) return;
    _limparBusca();
    final nova = await _listas.adicionarItem(lista, nomeLivre: nome.trim());
    _lista.value = nova;
    Aviso.sucesso('${nome.trim()} entrou na lista.');
  }

  void _limparBusca() {
    _busca.clear();
    _sugestoes.clear();
    _termo.value = '';
    FocusScope.of(context).unfocus();
  }

  /// Abre a edição do item planejado: quantidade, preço estimado, unidade.
  Future<void> _editar(ListaItemModel item) async {
    final lista = _lista.value;
    if (lista == null) return;
    await FolhaItem.abrir(
      context,
      item: item,
      aoSalvar: ({
        required double quantidade,
        double? precoEstimado,
        String? unidade,
        String? nomeLivre,
      }) async {
        _lista.value = await _listas.alterarItem(
          lista,
          item,
          quantidade: quantidade,
          precoEstimado: precoEstimado,
          unidade: unidade,
          nomeLivre: nomeLivre,
        );
      },
      aoRemover: () async {
        _lista.value = await _listas.removerItem(lista, item);
        Aviso.neutro('${item.nome} saiu da lista.');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.superficie,
      body: SafeArea(
        child: Obx(() {
          final lista = _lista.value;
          if (lista == null) {
            return const Center(
                child: CircularProgressIndicator(color: Cores.laranja));
          }

          return Column(
            children: [
              _Cabecalho(
                lista: lista,
                aoExcluir: () => _excluir(lista),
                aoCompartilhar: () => _compartilhar(lista),
              ),
              _CampoBusca(
                controle: _busca,
                aoDigitar: _aoDigitar,
                aoBipar: ParametrosGlobais.convidado
                    ? () => pedirConta(
                          context,
                          recurso: 'Bipar código de barras',
                          porque: 'A leitura consulta o catálogo de produtos no '
                              'servidor e guarda o preço no seu histórico.',
                        )
                    : () => Get.toNamed('/scanner', arguments: lista.id),
              ),
              Expanded(
                child: Obx(() => _termo.value.isNotEmpty
                    ? _Sugestoes(
                        produtos: _sugestoes,
                        carregando: _buscando.value,
                        termo: _termo.value,
                        aoEscolher: _adicionar,
                        aoEscreverNome: _adicionarPeloNome,
                      )
                    : _Itens(
                        lista: lista,
                        aoTocarItem: _editar,
                        aoRemover: (item) async {
                          _lista.value =
                              await _listas.removerItem(lista, item);
                          Aviso.neutro('${item.nome} saiu da lista.');
                        },
                      )),
              ),
              _Rodape(lista: lista),
            ],
          );
        }),
      ),
    );
  }

  Future<void> _compartilhar(ListaModel lista) async {
    if (ParametrosGlobais.convidado) {
      await pedirConta(
        context,
        recurso: 'Compartilhar a lista',
        porque: 'O convite passa pelo servidor para chegar ao celular da '
            'outra pessoa.',
      );
      return;
    }
    await FolhaCompartilhar.abrir(context, lista);
    // Membros podem ter mudado (alguém removido, você saiu).
    await _carregar();
  }

  Future<void> _excluir(ListaModel lista) async {
    final ok = await confirmar(
      context,
      titulo: 'Excluir a lista?',
      mensagem: '"${lista.nome}" e seus ${lista.itens.length} itens serão '
          'removidos. Isso não apaga o histórico de preços.',
      confirmarTexto: 'Excluir',
      destrutivo: true,
    );
    if (!ok) return;
    await _listas.excluir(lista.id);
    Get.back();
  }
}

class _Cabecalho extends StatelessWidget {
  final ListaModel lista;
  final VoidCallback aoExcluir;
  final VoidCallback aoCompartilhar;

  const _Cabecalho({
    required this.lista,
    required this.aoExcluir,
    required this.aoCompartilhar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 22),
            onPressed: () => Get.back(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  lista.nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  [
                    if (lista.rotuloPessoas != null) lista.rotuloPessoas!,
                    '${lista.itens.length} itens',
                    'estimado ${lista.totais.totalEstimado.emReais}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 11.5, color: Cores.texto3),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.group_add_outlined,
                size: 22, color: Cores.laranjaEscuro),
            tooltip: 'Compartilhar',
            onPressed: aoCompartilhar,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 22),
            onSelected: (v) {
              if (v == 'excluir') aoExcluir();
              if (v == 'compartilhar') aoCompartilhar();
            },
            itemBuilder: (_) => [
              // Icone sem rotulo nao se acha: a palavra fica no menu tambem.
              const PopupMenuItem(
                value: 'compartilhar',
                child: Row(
                  children: [
                    Icon(Icons.group_add_outlined,
                        size: 19, color: Cores.texto2),
                    SizedBox(width: 10),
                    Text('Compartilhar lista'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'excluir',
                child: Text(
                  // Membro nao apaga a lista da familia: ele sai dela.
                  lista.compartilhada &&
                          lista.donoId != ParametrosGlobais.usuario?.id
                      ? 'Sair da lista'
                      : 'Excluir lista',
                  style: const TextStyle(color: Cores.carmim),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CampoBusca extends StatelessWidget {
  final TextEditingController controle;
  final ValueChanged<String> aoDigitar;
  final VoidCallback? aoBipar;

  const _CampoBusca({
    required this.controle,
    required this.aoDigitar,
    this.aoBipar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextField(
        controller: controle,
        onChanged: aoDigitar,
        decoration: InputDecoration(
          hintText: 'Buscar produto ou bipar',
          hintStyle: const TextStyle(color: Cores.texto3, fontSize: 14),
          prefixIcon: const Icon(Icons.search, size: 20, color: Cores.texto3),
          suffixIcon: IconButton(
            icon: const IconeBarras(tamanho: 21, cor: Cores.laranja),
            onPressed: aoBipar,
          ),
          filled: true,
          fillColor: Cores.superficie2,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Cores.laranja, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _Sugestoes extends StatelessWidget {
  final List<ProdutoModel> produtos;
  final bool carregando;
  final String termo;
  final ValueChanged<ProdutoModel> aoEscolher;
  final ValueChanged<String> aoEscreverNome;

  const _Sugestoes({
    required this.produtos,
    required this.carregando,
    required this.termo,
    required this.aoEscolher,
    required this.aoEscreverNome,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (carregando)
          const LinearProgressIndicator(
              minHeight: 2,
              color: Cores.laranja,
              backgroundColor: Cores.superficie2),
        for (final p in produtos)
          InkWell(
            onTap: () => aoEscolher(p),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Cores.linha)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(
                          [
                            p.marca,
                            if (p.tipoVenda.ehPeso) 'por peso',
                            p.categoriaNome,
                          ].where((e) => e != null && e.isNotEmpty).join(' · '),
                          style: const TextStyle(
                              fontSize: 11.5, color: Cores.texto3),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.add_circle_outline,
                      size: 22, color: Cores.laranja),
                ],
              ),
            ),
          ),

        // Nem tudo que entra no carrinho está no catálogo — "pão na padaria",
        // "gelo", "flores". Esta linha existe para o usuário nunca ficar preso
        // esperando que o produto exista em algum lugar.
        if (!carregando)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: InkWell(
              onTap: () => aoEscreverNome(termo),
              borderRadius: BorderRadius.circular(13),
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Cores.laranjaSuave,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_outlined,
                        size: 19, color: Cores.laranjaEscuro),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            produtos.isEmpty
                                ? 'Nenhum produto encontrado'
                                : 'Não é nenhum desses?',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Cores.laranjaEscuro,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Adicionar "$termo" pelo nome',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Cores.laranjaEscuro,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Itens extends StatelessWidget {
  final ListaModel lista;
  final ValueChanged<ListaItemModel> aoTocarItem;
  final Future<void> Function(ListaItemModel) aoRemover;

  const _Itens({
    required this.lista,
    required this.aoTocarItem,
    required this.aoRemover,
  });

  @override
  Widget build(BuildContext context) {
    if (lista.itens.isEmpty) {
      return const VazioComAcao(
        icone: Icons.playlist_add,
        titulo: 'Lista vazia',
        descricao:
            'Busque um produto no campo acima, ou escreva o nome de algo que '
            'não tem código de barras. O último preço que você pagou já entra '
            'como estimativa.',
      );
    }

    final grupos = lista.agrupadoPorCategoria(lista.itens);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        for (final grupo in grupos) ...[
          TituloCategoria(grupo.key, quantidade: grupo.value.length),
          for (final item in grupo.value)
            Dismissible(
              key: ValueKey(item.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 16),
                color: Cores.carmimSuave,
                child: const Icon(Icons.delete_outline, color: Cores.carmim),
              ),
              onDismissed: (_) => aoRemover(item),
              child: LinhaItem(
                item,
                mostrarEstimado: true,
                inicialOutro: lista.inicialDe(
                    item.comprado ? item.compradoPorId : item.criadoPorId),
                aoTocar: () => aoTocarItem(item),
              ),
            ),
        ],
      ],
    );
  }
}

class _Rodape extends StatelessWidget {
  final ListaModel lista;

  const _Rodape({required this.lista});

  @override
  Widget build(BuildContext context) {
    final emCompra = lista.status == StatusLista.emCompra;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: Cores.superficie,
        border: Border(top: BorderSide(color: Cores.linha)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ESTIMADO · ${lista.itens.length} ITENS', style: rotulo),
              Text(lista.totais.totalEstimado.emReais, style: estiloValor(21)),
            ],
          ),
          const SizedBox(height: 10),
          BotaoPrincipal(
            emCompra ? 'Voltar ao Modo Compra' : 'Iniciar compra',
            icone: Icons.shopping_cart_outlined,
            aoTocar: lista.itens.isEmpty
                ? null
                : () => Get.toNamed('/compra', arguments: lista.id),
          ),
        ],
      ),
    );
  }
}
