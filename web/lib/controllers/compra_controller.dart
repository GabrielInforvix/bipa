import 'dart:async';

import 'package:get/get.dart';

import '../globais/http_interceptor.dart';
import '../globais/parametros_globais.dart';
import '../models/lista_model.dart';
import '../models/produto_model.dart';
import '../offline/repositorio_listas.dart';
import '../services/api_service.dart';
import '../widget/feedback.dart';
import 'conexao_controller.dart';

/// O que fazer depois de bipar um código.
enum AcaoBipe {
  /// Está na lista: abre a folha de preço direto.
  naLista,

  /// Conhecido, mas fora da lista: pergunta se é compra extra.
  foraDaLista,

  /// Etiqueta de balança com preço/peso lidos, produto não identificado.
  balanca,

  /// Ninguém conhece esse código: abre o cadastro rápido.
  desconhecido,

  /// Sem conexão e sem catálogo local para esse código.
  semCatalogo,
}

class ResultadoBipe {
  final AcaoBipe acao;
  final String ean;
  final ProdutoModel? produto;
  final ListaItemModel? item;
  final EtiquetaBalanca? etiqueta;
  final double? ultimoPreco;

  const ResultadoBipe({
    required this.acao,
    required this.ean,
    this.produto,
    this.item,
    this.etiqueta,
    this.ultimoPreco,
  });
}

/// Estado do Modo Compra.
///
/// Toda alteração passa pelo repositório offline-first: grava local, enfileira
/// e devolve na hora. A tela nunca espera a rede para mostrar o total novo.
class CompraController extends GetxController {
  final _api = ApiService();

  final lista = Rxn<ListaModel>();
  final carregando = false.obs;
  final aba = 0.obs; // 0 pendentes · 1 comprados · 2 extras

  /// Pulso da compra compartilhada: com outra pessoa na mesma lista, o app
  /// sincroniza a cada 15 s para o total dos dois andar junto. No corredor
  /// isso é indistinguível de instantâneo — e não custa nenhuma
  /// infraestrutura nova (decisão aprovada; WebSocket fica para a fase B).
  Timer? _pulso;

  TotaisLista get totais => lista.value?.totais ?? const TotaisLista();

  @override
  void onClose() {
    _pulso?.cancel();
    super.onClose();
  }

  void _ajustarPulso() {
    final l = lista.value;
    final precisa = l != null &&
        l.compartilhada &&
        l.status == StatusLista.emCompra &&
        ParametrosGlobais.temConta;
    if (precisa && _pulso == null) {
      _pulso = Timer.periodic(const Duration(seconds: 15), (_) async {
        if (!Get.isRegistered<ConexaoController>()) return;
        final conexao = Get.find<ConexaoController>();
        if (!conexao.online.value) return;
        await conexao.sincronizar();
        // O que a outra pessoa bipou está no banco local agora; a tela só
        // precisa reler — sem spinner, sem pular.
        final atual = lista.value;
        if (atual != null) {
          lista.value = await RepositorioListas.lista(atual.id) ?? atual;
        }
      });
    } else if (!precisa && _pulso != null) {
      _pulso?.cancel();
      _pulso = null;
    }
  }

  Future<void> carregar(String listaId) async {
    carregando.value = true;
    try {
      lista.value = await RepositorioListas.lista(listaId);
      _ajustarPulso();
    } finally {
      carregando.value = false;
    }
  }

  Future<void> iniciarCompra() async {
    final l = lista.value;
    if (l == null || l.status == StatusLista.emCompra) return;
    lista.value = await RepositorioListas.atualizarLista(
      l,
      status: StatusLista.emCompra,
    );
    _ajustarPulso();
  }

  // ── Bipe ───────────────────────────────────────────────────────────

  /// Resolve um código lido.
  ///
  /// Tenta primeiro o catálogo local — instantâneo e funciona offline, e cobre
  /// o caso comum de quem compra as mesmas coisas todo mês. Só depois vai à
  /// rede, onde o servidor roda o resto da cascata.
  Future<ResultadoBipe> resolverCodigo(String ean) async {
    final l = lista.value;

    final local = await RepositorioListas.produtoPorEan(ean);
    if (local != null) return _classificar(ean, local, null, null);

    try {
      final r = await _api.buscarPorEan(ean);
      if (r.produto != null) {
        await RepositorioListas.salvarProdutos([r.produto!]);
      }
      if (r.origem == OrigemBusca.balanca) {
        return ResultadoBipe(
          acao: r.produto != null ? AcaoBipe.naLista : AcaoBipe.balanca,
          ean: ean,
          produto: r.produto,
          item: r.produto == null ? null : l?.itemDoProduto(r.produto!.id),
          etiqueta: r.etiqueta,
          ultimoPreco: r.ultimoPreco,
        );
      }
      if (r.produto == null) {
        return ResultadoBipe(acao: AcaoBipe.desconhecido, ean: ean);
      }
      return _classificar(ean, r.produto!, r.etiqueta, r.ultimoPreco);
    } on SemConexaoException {
      // Offline e sem esse código no catálogo local: o usuário ainda pode
      // cadastrar na hora e a fila sobe depois.
      return ResultadoBipe(acao: AcaoBipe.semCatalogo, ean: ean);
    } catch (_) {
      return ResultadoBipe(acao: AcaoBipe.desconhecido, ean: ean);
    }
  }

  ResultadoBipe _classificar(
    String ean,
    ProdutoModel produto,
    EtiquetaBalanca? etiqueta,
    double? ultimoPreco,
  ) {
    final item = lista.value?.itemDoProduto(produto.id);
    return ResultadoBipe(
      acao: item != null && !item.origem.ehExtra
          ? AcaoBipe.naLista
          : AcaoBipe.foraDaLista,
      ean: ean,
      produto: produto,
      item: item,
      etiqueta: etiqueta,
      ultimoPreco: ultimoPreco,
    );
  }

  // ── Registro da compra ─────────────────────────────────────────────

  Future<void> comprarItem(
    ListaItemModel item, {
    required double quantidade,
    required double precoUnitario,
  }) async {
    final l = lista.value;
    if (l == null) return;
    lista.value = await RepositorioListas.registrarCompra(
      l,
      item,
      quantidade: quantidade,
      precoUnitario: precoUnitario,
    );
    _sincronizarEmSegundoPlano();
  }

  /// Produto fora da lista, comprado assim mesmo. Entra como EXTRA e aparece
  /// separado no resumo (regra 12).
  Future<void> comprarExtra(
    ProdutoModel produto, {
    required double quantidade,
    required double precoUnitario,
  }) async {
    final l = lista.value;
    if (l == null) return;

    var atualizada = await RepositorioListas.adicionarItem(
      l,
      produto: produto,
      quantidade: quantidade,
      origem: OrigemItem.extra,
    );
    final novo = atualizada.itens.last;
    lista.value = await RepositorioListas.registrarCompra(
      atualizada,
      novo,
      quantidade: quantidade,
      precoUnitario: precoUnitario,
    );
    _sincronizarEmSegundoPlano();
  }

  /// Adiciona à lista e já registra a compra — é o caminho de quem lembrou
  /// do produto no corredor.
  Future<void> adicionarEComprar(
    ProdutoModel produto, {
    required double quantidade,
    required double precoUnitario,
    double? precoEstimado,
  }) async {
    final l = lista.value;
    if (l == null) return;

    var atualizada = await RepositorioListas.adicionarItem(
      l,
      produto: produto,
      quantidade: quantidade,
      precoEstimado: precoEstimado,
    );
    final novo = atualizada.itens.last;
    lista.value = await RepositorioListas.registrarCompra(
      atualizada,
      novo,
      quantidade: quantidade,
      precoUnitario: precoUnitario,
    );
    _sincronizarEmSegundoPlano();
  }

  /// Desfazer. Marcar comprado por engano é o erro mais comum do corredor —
  /// precisa ser um toque para voltar atrás.
  Future<void> desfazerCompra(ListaItemModel item) async {
    final l = lista.value;
    if (l == null) return;
    lista.value = await RepositorioListas.desmarcarCompra(l, item);
    _sincronizarEmSegundoPlano();
  }

  Future<void> removerItem(ListaItemModel item) async {
    final l = lista.value;
    if (l == null) return;
    lista.value = await RepositorioListas.removerItem(l, item);
    _sincronizarEmSegundoPlano();
  }

  Future<void> alterarPlanejado(
    ListaItemModel item, {
    double? quantidade,
    double? precoEstimado,
  }) async {
    final l = lista.value;
    if (l == null) return;
    lista.value = await RepositorioListas.alterarPlanejado(
      l,
      item,
      quantidadePlanejada: quantidade,
      precoEstimado: precoEstimado,
    );
  }

  /// Fecha a compra. O status muda localmente na hora; o histórico de preços
  /// é gravado pelo servidor assim que a fila subir.
  Future<bool> finalizar() async {
    final l = lista.value;
    if (l == null) return false;

    lista.value = await RepositorioListas.atualizarLista(
      l,
      status: StatusLista.finalizada,
    );

    try {
      final conexao = Get.find<ConexaoController>();
      await conexao.sincronizar();
      if (conexao.online.value) await _api.finalizar(l.id);
    } catch (_) {
      // Sem conexão: a lista já está finalizada localmente e o histórico é
      // gravado quando a fila chegar ao servidor.
    }
    return true;
  }

  void _sincronizarEmSegundoPlano() {
    if (!Get.isRegistered<ConexaoController>()) return;
    final conexao = Get.find<ConexaoController>();
    conexao.atualizarPendentes();
    // Sem await: o usuário não espera a rede para ver o total mudar.
    if (conexao.online.value) conexao.sincronizar();
  }

  /// Cadastro rápido no corredor, funciona offline.
  Future<ProdutoModel> cadastrarProduto({
    required String nome,
    String? ean,
    String? marca,
    TipoVenda tipoVenda = TipoVenda.unidade,
    String? categoriaId,
    String? categoriaNome,
  }) async {
    final produto = await RepositorioListas.criarProdutoLocal(
      nome: nome,
      ean: ean,
      marca: marca,
      tipoVenda: tipoVenda,
      categoriaId: categoriaId,
      categoriaNome: categoriaNome,
    );
    _sincronizarEmSegundoPlano();
    Aviso.sucesso('Produto salvo. Agora ele é reconhecido por esse código.');
    return produto;
  }
}
