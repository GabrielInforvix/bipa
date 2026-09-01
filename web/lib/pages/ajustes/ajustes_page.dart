import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../controllers/conexao_controller.dart';
import '../../extensions/data_extension.dart';
import '../../globais/parametros_globais.dart';
import '../../offline/fila_sincronizacao.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/feedback.dart';

/// Ajustes e estado da sincronização.
///
/// A fila é inspecionável de propósito: se algo não subiu, o usuário vê
/// exatamente o quê, com hora. O identificador de cada operação não é enfeite
/// — é a garantia de idempotência que impede item duplicado no reenvio.
class AjustesPage extends StatefulWidget {
  const AjustesPage({super.key});

  @override
  State<AjustesPage> createState() => _AjustesPageState();
}

class _AjustesPageState extends State<AjustesPage> {
  final _conexao = Get.find<ConexaoController>();
  final _auth = Get.find<AuthController>();
  List<OperacaoPendente> _fila = [];

  @override
  void initState() {
    super.initState();
    _carregarFila();
  }

  Future<void> _carregarFila() async {
    final fila = await FilaSincronizacao.pendentes(limite: 40);
    if (mounted) setState(() => _fila = fila);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.superficie,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const Text('Ajustes',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            Obx(() => _conexao.online.value
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: Cores.laranjaSuave,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off,
                              size: 20, color: Cores.laranjaEscuro),
                          SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sem conexão',
                                    style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: Cores.laranjaEscuro)),
                                Text('Tudo continua funcionando normalmente.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Cores.laranjaEscuro)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )),

            if (!ParametrosGlobais.convidado)
              const Text('SINCRONIZAÇÃO', style: rotulo),
            const SizedBox(height: 8),
            if (!ParametrosGlobais.convidado)
              Obx(() => Cartao(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('AGUARDANDO ENVIO', style: rotulo),
                                const SizedBox(height: 3),
                                Text(
                                  _conexao.ultimaSincronizacao.value == null
                                      ? 'Nunca sincronizado neste aparelho'
                                      : 'Última: ${_conexao.ultimaSincronizacao.value!.emDataHoraBr}',
                                  style: const TextStyle(
                                      fontSize: 11.5, color: Cores.texto3),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${_conexao.pendentes.value}',
                            style: estiloValor(28,
                                cor: _conexao.pendentes.value > 0
                                    ? Cores.laranjaEscuro
                                    : Cores.verde),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      BotaoSecundario(
                        _conexao.sincronizando.value
                            ? 'Enviando…'
                            : 'Sincronizar agora',
                        icone: Icons.sync,
                        aoTocar: _conexao.sincronizando.value
                            ? null
                            : () async {
                                await _conexao.sincronizar();
                                await _carregarFila();
                              },
                      ),
                    ],
                  ),
                )),

            if (_fila.isNotEmpty) ...[
              TituloCategoria('Fila de alterações', quantidade: _fila.length),
              for (final op in _fila)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Cores.linha)),
                  ),
                  child: Row(
                    children: [
                      Etiqueta(
                        op.entidade.chave.replaceAll('_', ' '),
                        cor: Cores.laranjaEscuro,
                        fundo: Cores.laranjaSuave,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(op.descricao,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)),
                            Text(
                              '${op.ocorridoEm.emDataHoraBr} · op ${op.id.substring(0, 8)}…',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Cores.texto3,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Cores.linha),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Cores.texto3),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Cada alteração tem um identificador próprio. Se o envio '
                        'for repetido, o servidor ignora — nada duplica.',
                        style: TextStyle(
                            fontSize: 12, color: Cores.texto2, height: 1.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const TituloCategoria('Compras'),
            Cartao(
              cor: Cores.superficie,
              borda: Border.all(color: Cores.linha),
              aoTocar: () => Get.toNamed('/categorias'),
              child: const Row(
                children: [
                  Icon(Icons.route_outlined, size: 21, color: Cores.texto2),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ordem do corredor',
                            style: TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600)),
                        Text(
                          'Arraste as categorias para a sequência do seu mercado',
                          style:
                              TextStyle(fontSize: 11.5, color: Cores.texto3),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 20, color: Cores.texto3),
                ],
              ),
            ),

            const TituloCategoria('Conta'),
            if (ParametrosGlobais.convidado) ...[
              Cartao(
                cor: Cores.laranjaSuave,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Você está usando sem conta',
                        style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: Cores.laranjaEscuro)),
                    SizedBox(height: 4),
                    Text(
                      'Tudo fica só neste aparelho. Se você trocar de celular '
                      'ou limpar os dados do app, as listas se perdem.',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: Cores.laranjaEscuro,
                          height: 1.45),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              BotaoPrincipal(
                'Criar conta e sincronizar',
                icone: Icons.cloud_upload_outlined,
                altura: 46,
                aoTocar: () => Get.toNamed('/login'),
              ),
            ] else ...[
            Cartao(
              cor: Cores.superficie,
              borda: Border.all(color: Cores.linha),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Cores.laranjaSuave,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        (_auth.usuario?.primeiroNome ?? '?')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Cores.laranjaEscuro,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_auth.usuario?.nome ?? '',
                            style: const TextStyle(
                                fontSize: 14.5, fontWeight: FontWeight.w600)),
                        Text(_auth.usuario?.email ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: Cores.texto3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            BotaoSecundario(
              'Sair da conta',
              icone: Icons.logout,
              cor: Cores.carmim,
              aoTocar: () async {
                final ok = await confirmar(
                  context,
                  titulo: 'Sair da conta?',
                  mensagem: _conexao.pendentes.value > 0
                      ? 'Você tem ${_conexao.pendentes.value} alterações que ainda '
                          'não subiram. Sair agora perde essas alterações.'
                      : 'Suas listas continuam salvas no servidor.',
                  confirmarTexto: 'Sair',
                  destrutivo: true,
                );
                if (ok) await _auth.sair();
              },
            ),
            ],

            const SizedBox(height: 22),
            Center(
              child: Text(
                'Bipa · versão 0.1\n${ParametrosGlobais.apiBase}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: Cores.texto3, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
