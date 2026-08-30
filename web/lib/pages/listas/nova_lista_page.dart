import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/listas_controller.dart';
import '../../extensions/data_extension.dart';
import '../../extensions/num_extension.dart';
import '../../models/lista_model.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';

/// Criação de lista.
///
/// Orçamento e mercado entram aqui: dois campos que destravam a barra de gasto
/// no Modo Compra e o histórico de preço por loja. Nome ocupa linha inteira;
/// data e mercado dividem a mesma linha porque são secundários.
class NovaListaPage extends StatefulWidget {
  const NovaListaPage({super.key});

  @override
  State<NovaListaPage> createState() => _NovaListaPageState();
}

class _NovaListaPageState extends State<NovaListaPage> {
  final _listas = Get.find<ListasController>();
  final _nome = TextEditingController(text: 'Compras do mês');
  final _observacao = TextEditingController();
  final _orcamento = EntradaCentavos();

  DateTime _data = DateTime.now();
  String? _mercadoId;
  ListaModel? _copiarDe;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    // "Repetir lista" embutido na criação: é como quase toda lista mensal
    // nasce, então não merece uma tela separada.
    _copiarDe = _listas.ultimaFinalizada;
    _mercadoId = _copiarDe?.mercadoId;
    if (_copiarDe?.orcamento != null) _orcamento.definir(_copiarDe!.orcamento!);
  }

  @override
  void dispose() {
    _nome.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    if (_nome.text.trim().isEmpty) return;
    setState(() => _salvando = true);
    final lista = await _listas.criar(
      nome: _nome.text.trim(),
      data: _data,
      observacao:
          _observacao.text.trim().isEmpty ? null : _observacao.text.trim(),
      orcamento: _orcamento.vazio ? null : _orcamento.valor,
      mercadoId: _mercadoId,
      copiarDe: _copiarDe,
    );
    Get.offNamed('/lista', arguments: lista.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.superficie,
      appBar: AppBar(
        backgroundColor: Cores.superficie,
        surfaceTintColor: Colors.transparent,
        title: const Text('Nova lista',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          const Text('NOME DA LISTA', style: rotulo),
          const SizedBox(height: 6),
          TextField(
            controller: _nome,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoracao('Ex.: Compras do mês'),
          ),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DATA', style: rotulo),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: _escolherData,
                      child: Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.centerLeft,
                        decoration: BoxDecoration(
                          color: Cores.superficie2,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Text(_data.emDataBr,
                            style: const TextStyle(fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('MERCADO (OPCIONAL)', style: rotulo),
                    const SizedBox(height: 6),
                    Obx(() => Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Cores.superficie2,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              value: _mercadoId,
                              isExpanded: true,
                              hint: const Text('Escolher',
                                  style: TextStyle(
                                      fontSize: 14, color: Cores.texto3)),
                              items: [
                                const DropdownMenuItem(
                                    value: null, child: Text('Sem mercado')),
                                for (final m in _listas.mercados)
                                  DropdownMenuItem(
                                      value: m.id,
                                      child: Text(m.nome,
                                          overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) => setState(() => _mercadoId = v),
                            ),
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Um campo só, e responde a pergunta real do corredor: dá pra levar?
          const Text('ORÇAMENTO DA COMPRA', style: rotulo),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Cores.laranjaSuave,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Cores.laranja, width: 1.5),
            ),
            child: Row(
              children: [
                Text(_orcamento.formatado,
                    style: estiloValor(26, cor: Cores.laranjaEscuro)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.backspace_outlined,
                      size: 20, color: Cores.laranjaEscuro),
                  onPressed: () => setState(() => _orcamento.apagar()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _TecladoOrcamento(
            aoDigitar: (d) => setState(() => _orcamento.digitar(d)),
          ),
          const SizedBox(height: 6),
          const Text(
            'Usado para a barra de gasto no Modo Compra. Pode ficar em branco.',
            style: TextStyle(fontSize: 11.5, color: Cores.texto3, height: 1.4),
          ),
          const SizedBox(height: 16),

          const Text('OBSERVAÇÃO', style: rotulo),
          const SizedBox(height: 6),
          TextField(
            controller: _observacao,
            decoration: _decoracao('Ex.: passar na feira antes'),
          ),

          if (_listas.ultimaFinalizada != null) ...[
            const TituloCategoria('Começar a partir de'),
            _OpcaoBase(
              titulo: _listas.ultimaFinalizada!.nome,
              descricao:
                  '${_listas.ultimaFinalizada!.itens.length} itens · preços de referência',
              selecionada: _copiarDe != null,
              aoTocar: () =>
                  setState(() => _copiarDe = _listas.ultimaFinalizada),
            ),
            _OpcaoBase(
              titulo: 'Lista em branco',
              descricao: 'Adicionar os produtos do zero',
              selecionada: _copiarDe == null,
              aoTocar: () => setState(() => _copiarDe = null),
            ),
          ],

          const SizedBox(height: 22),
          BotaoPrincipal('Criar lista',
              carregando: _salvando, aoTocar: _criar),
        ],
      ),
    );
  }

  Future<void> _escolherData() async {
    final escolhida = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
      locale: const Locale('pt', 'BR'),
    );
    if (escolhida != null) setState(() => _data = escolhida);
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

/// Mesmo teclado de centavos do Modo Compra — consistência vale mais que
/// economizar código aqui.
class _TecladoOrcamento extends StatelessWidget {
  final ValueChanged<String> aoDigitar;

  const _TecladoOrcamento({required this.aoDigitar});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'])
          SizedBox(
            width: (MediaQuery.of(context).size.width - 32 - 6 * 4) / 5,
            height: 42,
            child: Material(
              color: Cores.superficie2,
              borderRadius: BorderRadius.circular(11),
              child: InkWell(
                onTap: () => aoDigitar(d),
                borderRadius: BorderRadius.circular(11),
                child: Center(
                  child: Text(d,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _OpcaoBase extends StatelessWidget {
  final String titulo;
  final String descricao;
  final bool selecionada;
  final VoidCallback aoTocar;

  const _OpcaoBase({
    required this.titulo,
    required this.descricao,
    required this.selecionada,
    required this.aoTocar,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Cartao(
        cor: Cores.superficie,
        borda: Border.all(
          color: selecionada ? Cores.laranja : Cores.linha,
          width: selecionada ? 1.5 : 1,
        ),
        aoTocar: aoTocar,
        child: Row(
          children: [
            Icon(
              selecionada
                  ? Icons.check_circle
                  : Icons.radio_button_unchecked,
              color: selecionada ? Cores.verde : Cores.linhaForte,
              size: 22,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text(descricao,
                      style: const TextStyle(
                          fontSize: 11.5, color: Cores.texto3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
