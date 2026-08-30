import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/conexao_controller.dart';
import '../../controllers/listas_controller.dart';
import '../../extensions/data_extension.dart';
import '../../extensions/num_extension.dart';
import '../../models/lista_model.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';

/// Tela de início.
///
/// A compra em andamento ocupa a tela inteira e leva direto ao Modo Compra:
/// é o único estado em que abrir o app tem urgência.
class InicioPage extends StatelessWidget {
  const InicioPage({super.key});

  @override
  Widget build(BuildContext context) {
    final listas = Get.find<ListasController>();
    final auth = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: Cores.fundo,
      body: SafeArea(
        child: RefreshIndicator(
          color: Cores.laranja,
          onRefresh: listas.atualizarDoServidor,
          child: Obx(() {
            final emCompra = listas.emCompra;
            final ultima = listas.ultimaFinalizada;

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _Cabecalho(nome: auth.usuario?.primeiroNome ?? ''),
                const SizedBox(height: 14),

                if (emCompra != null)
                  _CartaoEmCompra(emCompra)
                else
                  _CartaoNovaCompra(listas: listas, ultima: ultima),

                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: BotaoSecundario(
                        'Nova lista',
                        icone: Icons.add,
                        aoTocar: () => Get.toNamed('/nova-lista'),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: BotaoSecundario(
                        'Repetir última',
                        icone: Icons.refresh,
                        aoTocar: ultima == null
                            ? null
                            : () async {
                                final nova = await listas.repetir(ultima);
                                Get.toNamed('/lista', arguments: nova.id);
                              },
                      ),
                    ),
                  ],
                ),

                if (ultima != null) ...[
                  const TituloCategoria('Última compra'),
                  _CartaoUltima(ultima),
                ],

                if (listas.rascunhos.isNotEmpty) ...[
                  TituloCategoria('Suas listas',
                      quantidade: listas.rascunhos.length),
                  ...listas.rascunhos.take(5).map(
                        (l) => _LinhaLista(l),
                      ),
                ],

                if (emCompra == null &&
                    ultima == null &&
                    listas.rascunhos.isEmpty &&
                    !listas.carregando.value)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: VazioComAcao(
                      icone: Icons.shopping_cart_outlined,
                      titulo: 'Sua primeira lista',
                      descricao:
                          'Monte a lista em casa e, no mercado, bipe os produtos '
                          'para ver o total subindo em tempo real.',
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final String nome;

  const _Cabecalho({required this.nome});

  @override
  Widget build(BuildContext context) {
    final conexao = Get.find<ConexaoController>();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nome.isEmpty ? saudacao() : '${saudacao()}, $nome',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              Text(
                DateTime.now().porExtenso,
                style: const TextStyle(fontSize: 12.5, color: Cores.texto3),
              ),
            ],
          ),
        ),
        Obx(() {
          final online = conexao.online.value;
          final pendentes = conexao.pendentes.value;
          final ok = online && pendentes == 0;
          return Etiqueta(
            conexao.rotulo,
            cor: ok ? Cores.verde : Cores.laranjaEscuro,
            fundo: ok ? Cores.verdeSuave : Cores.laranjaSuave,
            icone: ok ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
          );
        }),
      ],
    );
  }
}

/// Compra em andamento — o estado que manda na tela.
class _CartaoEmCompra extends StatelessWidget {
  final ListaModel lista;

  const _CartaoEmCompra(this.lista);

  @override
  Widget build(BuildContext context) {
    final t = lista.totais;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cores.laranja,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'COMPRA EM ANDAMENTO',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white70,
                ),
              ),
              if (lista.mercadoNome != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    lista.mercadoNome!,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            lista.nome,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  t.totalPago.emReais,
                  style: estiloValor(36, cor: Colors.white),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${t.itensComprados} de ${t.itensComprados + t.itensPendentes}',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
            ],
          ),
          if (t.orcamento != null) ...[
            const SizedBox(height: 12),
            _BarraClara(fracao: t.fracaoOrcamento ?? 0),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${((t.fracaoOrcamento ?? 0) * 100).round()}% do orçamento',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                Text(
                  'teto ${t.orcamento!.emReais}',
                  style:
                      const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Cores.laranja,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              onPressed: () => Get.toNamed('/compra', arguments: lista.id),
              child: const Text('Continuar comprando',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarraClara extends StatelessWidget {
  final double fracao;

  const _BarraClara({required this.fracao});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: LinearProgressIndicator(
        value: fracao.clamp(0.0, 1.0),
        minHeight: 7,
        backgroundColor: Colors.white.withValues(alpha: 0.28),
        valueColor: const AlwaysStoppedAnimation(Colors.white),
      ),
    );
  }
}

class _CartaoNovaCompra extends StatelessWidget {
  final ListasController listas;
  final ListaModel? ultima;

  const _CartaoNovaCompra({required this.listas, this.ultima});

  @override
  Widget build(BuildContext context) {
    final rascunho = listas.rascunhos.isEmpty ? null : listas.rascunhos.first;
    return Cartao(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nenhuma compra em andamento',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            rascunho != null
                ? 'A lista "${rascunho.nome}" está pronta para começar.'
                : 'Crie uma lista para começar a comprar.',
            style: const TextStyle(fontSize: 13.5, color: Cores.texto2),
          ),
          const SizedBox(height: 14),
          BotaoPrincipal(
            rascunho != null ? 'Iniciar compra' : 'Criar lista',
            icone: rascunho != null ? Icons.play_arrow : Icons.add,
            altura: 46,
            aoTocar: () => rascunho != null
                ? Get.toNamed('/compra', arguments: rascunho.id)
                : Get.toNamed('/nova-lista'),
          ),
        ],
      ),
    );
  }
}

class _CartaoUltima extends StatelessWidget {
  final ListaModel lista;

  const _CartaoUltima(this.lista);

  @override
  Widget build(BuildContext context) {
    final t = lista.totais;
    return Cartao(
      cor: Cores.superficie,
      borda: Border.all(color: Cores.linha),
      aoTocar: () => Get.toNamed('/resumo', arguments: lista.id),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lista.nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${(lista.finalizadaEm ?? lista.data).emDiaMes}'
                  '${lista.mercadoNome != null ? ' · ${lista.mercadoNome}' : ''}'
                  ' · ${t.itensComprados} itens',
                  style: const TextStyle(fontSize: 11.5, color: Cores.texto3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(t.totalPago.emReais, style: estiloValor(17)),
              if (t.economia.abs() >= 0.01) ...[
                const SizedBox(height: 3),
                DeltaValor(
                  t.economia,
                  tamanho: 10.5,
                  ehTotal: true,
                  sufixo: t.economia > 0 ? 'abaixo' : 'acima',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LinhaLista extends StatelessWidget {
  final ListaModel lista;

  const _LinhaLista(this.lista);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Get.toNamed('/lista', arguments: lista.id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Cores.linha)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Cores.superficie3,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.list_alt,
                  size: 19, color: Cores.texto2),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lista.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(
                    '${lista.itens.length} itens · ${lista.status.rotulo}',
                    style:
                        const TextStyle(fontSize: 11.5, color: Cores.texto3),
                  ),
                ],
              ),
            ),
            if (lista.totais.totalEstimado > 0)
              Text(
                lista.totais.totalEstimado.emReais,
                style: estiloValor(13.5, cor: Cores.texto3),
              ),
          ],
        ),
      ),
    );
  }
}
