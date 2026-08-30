import 'package:get/get.dart';

import '../models/basicos_model.dart';
import '../models/lista_model.dart';
import '../models/produto_model.dart';
import '../offline/repositorio_listas.dart';
import '../services/api_service.dart';
import 'conexao_controller.dart';

/// Listas, catálogo e o resumo da tela de início.
///
/// Tudo é lido do banco local — a tela abre pronta mesmo sem conexão.
class ListasController extends GetxController {
  final _api = ApiService();

  final listas = <ListaModel>[].obs;
  final categorias = <CategoriaModel>[].obs;
  final mercados = <MercadoModel>[].obs;
  final carregando = false.obs;

  ListaModel? get emCompra {
    for (final l in listas) {
      if (l.status == StatusLista.emCompra) return l;
    }
    return null;
  }

  ListaModel? get ultimaFinalizada {
    final f = listas.where((l) => l.status == StatusLista.finalizada).toList()
      ..sort((a, b) =>
          (b.finalizadaEm ?? b.data).compareTo(a.finalizadaEm ?? a.data));
    return f.isEmpty ? null : f.first;
  }

  List<ListaModel> get rascunhos =>
      listas.where((l) => l.status == StatusLista.rascunho).toList();

  @override
  void onInit() {
    super.onInit();
    recarregar();
  }

  Future<void> recarregar() async {
    carregando.value = true;
    try {
      listas.value = await RepositorioListas.listas();
      categorias.value = await RepositorioListas.categorias();
      mercados.value = await RepositorioListas.mercados();
    } finally {
      carregando.value = false;
    }
  }

  /// Puxa do servidor e recarrega da base local.
  Future<void> atualizarDoServidor() async {
    if (Get.isRegistered<ConexaoController>()) {
      await Get.find<ConexaoController>().sincronizar();
    }
    await recarregar();
  }

  Future<ListaModel> criar({
    required String nome,
    DateTime? data,
    String? observacao,
    double? orcamento,
    String? mercadoId,
    ListaModel? copiarDe,
  }) async {
    final mercado = mercadoId == null
        ? null
        : mercados.firstWhereOrNull((m) => m.id == mercadoId);
    final lista = await RepositorioListas.criarLista(
      nome: nome,
      data: data,
      observacao: observacao,
      orcamento: orcamento,
      mercadoId: mercadoId,
      mercadoNome: mercado?.nome,
      copiarDe: copiarDe,
    );
    await recarregar();
    _sincronizar();
    return lista;
  }

  Future<void> excluir(String id) async {
    await RepositorioListas.excluirLista(id);
    await recarregar();
    _sincronizar();
  }

  /// Repetir lista: novos itens, preço anterior só como referência.
  Future<ListaModel> repetir(ListaModel origem) async {
    final lista = await criar(
      nome: origem.nome,
      orcamento: origem.orcamento,
      mercadoId: origem.mercadoId,
      copiarDe: origem,
    );
    return lista;
  }

  Future<ListaModel> adicionarItem(
    ListaModel lista, {
    ProdutoModel? produto,
    String? nomeLivre,
    double quantidade = 1,
    double? precoEstimado,
  }) async {
    final nova = await RepositorioListas.adicionarItem(
      lista,
      produto: produto,
      nomeLivre: nomeLivre,
      quantidade: quantidade,
      precoEstimado: precoEstimado ?? await _ultimoPreco(produto),
    );
    await recarregar();
    _sincronizar();
    return nova;
  }

  /// Edita o que foi planejado para o item: quantidade, preço estimado,
  /// unidade e — quando o item foi escrito na mão — o próprio nome.
  Future<ListaModel> alterarItem(
    ListaModel lista,
    ListaItemModel item, {
    double? quantidade,
    double? precoEstimado,
    String? unidade,
    String? nomeLivre,
  }) async {
    final nova = await RepositorioListas.alterarPlanejado(
      lista,
      item,
      quantidadePlanejada: quantidade,
      precoEstimado: precoEstimado,
      unidade: unidade,
      nomeLivre: nomeLivre,
    );
    await recarregar();
    _sincronizar();
    return nova;
  }

  Future<ListaModel> removerItem(ListaModel lista, ListaItemModel item) async {
    final nova = await RepositorioListas.removerItem(lista, item);
    await recarregar();
    _sincronizar();
    return nova;
  }

  /// Preço de referência do item: o último que a pessoa pagou. É a estimativa
  /// que ela não precisa digitar.
  Future<double?> _ultimoPreco(ProdutoModel? produto) async {
    if (produto == null) return null;
    try {
      final h = await _api.historicoPrecos(produto.id);
      return h.ultimo;
    } catch (_) {
      return null;
    }
  }

  /// Busca de produto para montar a lista. Em casa se digita; no mercado se
  /// bipa — por isso o campo é o mesmo nas duas telas.
  Future<List<ProdutoModel>> buscarProdutos(String termo) async {
    final locais = await RepositorioListas.buscarProdutos(termo);
    if (locais.length >= 8 || termo.trim().length < 3) return locais;
    try {
      final remotos = await _api.buscarProdutos(termo);
      await RepositorioListas.salvarProdutos(remotos);
      final ids = locais.map((p) => p.id).toSet();
      return [...locais, ...remotos.where((p) => !ids.contains(p.id))];
    } catch (_) {
      return locais; // offline: o catálogo local basta
    }
  }

  Future<MercadoModel?> criarMercado(String nome) async {
    try {
      final m = await _api.criarMercado(nome);
      await RepositorioListas.salvarMercados([m]);
      mercados.value = await RepositorioListas.mercados();
      return m;
    } catch (_) {
      return null;
    }
  }

  Future<HistoricoPrecos> historico(String produtoId) =>
      _api.historicoPrecos(produtoId);

  void _sincronizar() {
    if (!Get.isRegistered<ConexaoController>()) return;
    final c = Get.find<ConexaoController>();
    c.atualizarPendentes();
    if (c.online.value) c.sincronizar();
  }
}
