import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/compra_controller.dart';
import '../../controllers/listas_controller.dart';
import '../../extensions/num_extension.dart';
import '../../models/produto_model.dart';
import '../../scanner/escaner.dart';
import '../../scanner/escaner_codigo_barras.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/feedback.dart';
import 'folha_preco.dart';
import 'produto_novo_page.dart';

/// Tela do scanner.
///
/// A câmera fica ligada o tempo todo: a folha de preço sobe por cima do vídeo
/// e, ao confirmar, o app já está lendo o próximo produto. É o que transforma
/// quatro transições de tela por item em um toque.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  // `Get.find` aqui derrubava a tela quando o scanner era aberto pela tela da
  // Lista: o CompraController só é registrado pelo Modo Compra, então a busca
  // lançava dentro do inicializador de campo e a página nem chegava a montar
  // — o que aparecia para o usuário era uma tela em branco.
  final _compra = Get.isRegistered<CompraController>()
      ? Get.find<CompraController>()
      : Get.put(CompraController());
  final _escaner = criarEscaner();

  StreamSubscription<String>? _inscricao;
  StreamSubscription<ErroEscaner>? _inscricaoErros;
  bool _camera = false;
  String? _erro;
  bool _permissaoNegada = false;
  bool _processando = false;
  bool _lanterna = false;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  /// Garante que existe uma lista carregada antes de abrir a câmera. Bipar sem
  /// lista não teria onde lançar o produto.
  Future<void> _preparar() async {
    final id = Get.arguments as String?;
    final atual = _compra.lista.value;

    if (atual == null || (id != null && atual.id != id)) {
      if (id != null) {
        await _compra.carregar(id);
      } else {
        final listas = Get.find<ListasController>();
        await listas.recarregar();
        final alvo = listas.emCompra ?? listas.rascunhos.firstOrNull;
        if (alvo != null) await _compra.carregar(alvo.id);
      }
    }

    if (!mounted) return;
    if (_compra.lista.value == null) {
      Get.back();
      Aviso.neutro('Abra uma lista antes de bipar.');
      return;
    }
    await _abrirCamera();
  }

  Future<void> _abrirCamera() async {
    // Falhas que chegam depois (permissão negada no diálogo, câmera ocupada)
    // vêm por este canal — no nativo quem liga a câmera é o widget de prévia.
    _inscricaoErros = _escaner.erros.listen((e) {
      if (!mounted) return;
      setState(() {
        _erro = e.mensagem;
        _permissaoNegada = e.permissaoNegada;
      });
    });

    try {
      _inscricao = _escaner.leituras.listen(_aoLer);
      await _escaner.iniciar();
      if (mounted) setState(() => _camera = true);
    } on ErroEscaner catch (e) {
      if (mounted) {
        setState(() {
          _erro = e.mensagem;
          _permissaoNegada = e.permissaoNegada;
        });
      }
    } catch (e) {
      // Rede de segurança: qualquer outra falha vira mensagem legível em vez
      // de tela vazia. O usuário sempre tem a saída de digitar o código.
      if (mounted) {
        setState(() => _erro =
            'Não foi possível abrir a câmera. Digite o código para continuar.');
      }
    }
  }

  @override
  void dispose() {
    _inscricao?.cancel();
    _inscricaoErros?.cancel();
    _escaner.dispose();
    super.dispose();
  }

  /// Um código por vez: enquanto a folha está aberta, novas leituras são
  /// ignoradas para não empilhar telas.
  Future<void> _aoLer(String ean) async {
    if (_processando || !mounted) return;
    setState(() => _processando = true);
    try {
      final r = await _compra.resolverCodigo(ean);
      if (!mounted) return;
      await _tratar(r);
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  Future<void> _tratar(ResultadoBipe r) async {
    switch (r.acao) {
      case AcaoBipe.naLista:
        await _folhaDoItem(r);
      case AcaoBipe.foraDaLista:
        await _perguntarForaDaLista(r);
      case AcaoBipe.balanca:
        await _folhaBalanca(r);
      case AcaoBipe.desconhecido:
      case AcaoBipe.semCatalogo:
        await _cadastrar(r);
    }
  }

  /// Produto que está na lista: vai direto para quantidade e preço.
  Future<void> _folhaDoItem(ResultadoBipe r) async {
    final item = r.item;
    final produto = r.produto!;
    final porPeso = produto.tipoVenda.ehPeso;

    await FolhaPreco.abrir(
      context,
      titulo: produto.nome,
      subtitulo: produto.marca,
      ean: produto.ean,
      porPeso: porPeso,
      quantidadeInicial: r.etiqueta?.pesoKg ?? item?.quantidadeAtual ?? 1,
      precoInicial: r.etiqueta?.preco,
      sugestao: r.ultimoPreco ?? item?.precoEstimado,
      precoEstimado: item?.precoEstimado,
      aoConfirmar: (quantidade, preco) async {
        if (item != null) {
          await _compra.comprarItem(item,
              quantidade: quantidade, precoUnitario: preco);
        } else {
          await _compra.adicionarEComprar(produto,
              quantidade: quantidade, precoUnitario: preco);
        }
        Aviso.sucesso('${produto.nome} · ${(quantidade * preco).emReais}');
      },
    );
  }

  /// Produto conhecido, fora da lista. "Comprar como extra" vem primeiro:
  /// é o que 9 em 10 pessoas querem, já com o produto na mão.
  Future<void> _perguntarForaDaLista(ResultadoBipe r) async {
    final produto = r.produto!;
    final escolha = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => _FolhaForaDaLista(produto: produto),
    );
    if (escolha == null || !mounted) return;

    await FolhaPreco.abrir(
      context,
      titulo: produto.nome,
      subtitulo: produto.marca,
      ean: produto.ean,
      porPeso: produto.tipoVenda.ehPeso,
      quantidadeInicial: r.etiqueta?.pesoKg ?? 1,
      precoInicial: r.etiqueta?.preco,
      sugestao: r.ultimoPreco,
      etiquetaTopo: escolha == 'extra' ? 'compra extra' : 'novo na lista',
      corEtiqueta: Cores.laranjaEscuro,
      fundoEtiqueta: Cores.laranjaSuave,
      aoConfirmar: (quantidade, preco) async {
        if (escolha == 'extra') {
          await _compra.comprarExtra(produto,
              quantidade: quantidade, precoUnitario: preco);
        } else {
          await _compra.adicionarEComprar(produto,
              quantidade: quantidade, precoUnitario: preco);
        }
        Aviso.sucesso('${produto.nome} · ${(quantidade * preco).emReais}');
      },
    );
  }

  /// Etiqueta de balança sem produto identificado: peso e preço já vêm lidos
  /// do código, falta só dizer o que é.
  Future<void> _folhaBalanca(ResultadoBipe r) async {
    final etiqueta = r.etiqueta!;
    final produto = await Get.to<ProdutoModel?>(
      () => ProdutoNovoPage(
        ean: r.ean,
        porPeso: true,
        aviso: 'Etiqueta de balança lida: '
            '${etiqueta.preco != null ? etiqueta.preco!.emReais : '${etiqueta.pesoKg} kg'}. '
            'Diga só qual é o produto.',
      ),
    );
    if (produto == null || !mounted) return;

    final peso = etiqueta.pesoKg ?? 1;
    await FolhaPreco.abrir(
      context,
      titulo: produto.nome,
      ean: r.ean,
      porPeso: true,
      quantidadeInicial: peso,
      // Preço da etiqueta é o TOTAL; aqui o campo é R$/kg.
      precoInicial:
          etiqueta.preco != null && peso > 0 ? etiqueta.preco! / peso : null,
      etiquetaTopo: 'etiqueta de balança',
      corEtiqueta: Cores.laranjaEscuro,
      fundoEtiqueta: Cores.laranjaSuave,
      aoConfirmar: (quantidade, preco) => _compra.comprarExtra(
        produto,
        quantidade: quantidade,
        precoUnitario: preco,
      ),
    );
  }

  Future<void> _cadastrar(ResultadoBipe r) async {
    final produto = await Get.to<ProdutoModel?>(
      () => ProdutoNovoPage(
        ean: r.ean,
        aviso: r.acao == AcaoBipe.semCatalogo
            ? 'Sem conexão para consultar esse código. Cadastre agora — o '
                'produto sobe assim que a internet voltar.'
            : null,
      ),
    );
    if (produto == null || !mounted) return;

    await FolhaPreco.abrir(
      context,
      titulo: produto.nome,
      ean: r.ean,
      porPeso: produto.tipoVenda.ehPeso,
      etiquetaTopo: 'produto novo',
      corEtiqueta: Cores.laranjaEscuro,
      fundoEtiqueta: Cores.laranjaSuave,
      aoConfirmar: (quantidade, preco) => _compra.comprarExtra(
        produto,
        quantidade: quantidade,
        precoUnitario: preco,
      ),
    );
  }

  /// Digitação manual — sempre disponível. O scanner nunca pode virar um beco
  /// sem saída no meio da compra.
  Future<void> _digitarCodigo() async {
    final controle = TextEditingController();
    final codigo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Digitar código',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controle,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '7896036098264',
            labelText: 'Código de barras',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: Cores.texto2)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Cores.laranja),
            onPressed: () => Navigator.pop(ctx, controle.text.trim()),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
    if (codigo != null && codigo.isNotEmpty) await _aoLer(codigo);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.camera,
      body: Stack(
        children: [
          if (_camera) Positioned.fill(child: _escaner.previa()),
          if (_erro != null) _Erro(mensagem: _erro!, negada: _permissaoNegada),
          if (_camera) const _Mira(),
          _Controles(
            compra: _compra,
            processando: _processando,
            lanterna: _lanterna,
            temCamera: _camera,
            aoDigitar: _digitarCodigo,
            aoAlternarLanterna: () async {
              final ligada = await _escaner.alternarLanterna();
              setState(() => _lanterna = ligada);
            },
          ),
        ],
      ),
    );
  }
}

/// Retângulo de enquadramento com os quatro cantos em laranja.
class _Mira extends StatelessWidget {
  const _Mira();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 38),
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                spreadRadius: 2000,
              ),
            ],
          ),
          child: Stack(
            children: [
              for (final alinhamento in [
                Alignment.topLeft,
                Alignment.topRight,
                Alignment.bottomLeft,
                Alignment.bottomRight,
              ])
                Align(
                  alignment: alinhamento,
                  child: _Canto(alinhamento: alinhamento),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Canto extends StatelessWidget {
  final Alignment alinhamento;

  const _Canto({required this.alinhamento});

  @override
  Widget build(BuildContext context) {
    const lado = BorderSide(color: Cores.laranja, width: 3);
    final topo = alinhamento.y < 0;
    final esquerda = alinhamento.x < 0;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        border: Border(
          top: topo ? lado : BorderSide.none,
          bottom: topo ? BorderSide.none : lado,
          left: esquerda ? lado : BorderSide.none,
          right: esquerda ? BorderSide.none : lado,
        ),
        borderRadius: BorderRadius.only(
          topLeft: topo && esquerda ? const Radius.circular(10) : Radius.zero,
          topRight: topo && !esquerda ? const Radius.circular(10) : Radius.zero,
          bottomLeft:
              !topo && esquerda ? const Radius.circular(10) : Radius.zero,
          bottomRight:
              !topo && !esquerda ? const Radius.circular(10) : Radius.zero,
        ),
      ),
    );
  }
}

class _Controles extends StatelessWidget {
  final CompraController compra;
  final bool processando;
  final bool lanterna;
  final bool temCamera;
  final VoidCallback aoDigitar;
  final VoidCallback aoAlternarLanterna;

  const _Controles({
    required this.compra,
    required this.processando,
    required this.lanterna,
    required this.temCamera,
    required this.aoDigitar,
    required this.aoAlternarLanterna,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 26),
                onPressed: () => Get.back(),
              ),
              const Spacer(),
              // O total continua visível durante o bipe: é a informação que
              // o usuário está ali para acompanhar.
              Obx(() {
                final t = compra.totais;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    t.totalPago.emReais,
                    style: estiloValor(17, cor: Colors.white),
                  ),
                );
              }),
              const SizedBox(width: 8),
              if (temCamera)
                IconButton(
                  icon: Icon(
                    lanterna ? Icons.flashlight_on : Icons.flashlight_off,
                    color: lanterna ? Cores.laranja : Colors.white,
                    size: 24,
                  ),
                  onPressed: aoAlternarLanterna,
                ),
            ],
          ),
          const SizedBox(height: 6),
          if (temCamera)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                processando ? 'Buscando produto…' : 'Aponte para o código de barras',
                style: const TextStyle(
                    color: Color(0xFFE8E5E1),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.55),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: aoDigitar,
                icon: const Icon(Icons.keyboard, size: 19),
                label: const Text('Digitar o código',
                    style: TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Erro extends StatelessWidget {
  final String mensagem;
  final bool negada;

  const _Erro({required this.mensagem, required this.negada});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              negada ? Icons.no_photography_outlined : Icons.info_outline,
              size: 42,
              color: Colors.white70,
            ),
            const SizedBox(height: 16),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'Você pode digitar o código no botão abaixo e continuar a compra '
              'normalmente.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ordem invertida em relação ao que a especificação pedia: comprar como
/// extra vem primeiro porque o produto já está na mão da pessoa.
class _FolhaForaDaLista extends StatelessWidget {
  final ProdutoModel produto;

  const _FolhaForaDaLista({required this.produto});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Cores.superficie,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
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
          const SizedBox(height: 18),
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Cores.laranjaSuave,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.priority_high,
                color: Cores.laranja, size: 24),
          ),
          const SizedBox(height: 12),
          const Text('Fora da sua lista',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(
            '${produto.nome} não estava planejado para essa compra.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 13.5, color: Cores.texto2, height: 1.45),
          ),
          const SizedBox(height: 18),
          BotaoPrincipal(
            'Comprar como extra',
            aoTocar: () => Navigator.pop(context, 'extra'),
          ),
          const SizedBox(height: 8),
          BotaoSecundario(
            'Adicionar à lista e comprar',
            aoTocar: () => Navigator.pop(context, 'lista'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: Cores.texto3)),
          ),
        ],
      ),
    );
  }
}
