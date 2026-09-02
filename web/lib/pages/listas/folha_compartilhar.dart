import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/listas_controller.dart';
import '../../globais/parametros_globais.dart';
import '../../models/lista_model.dart';
import '../../services/api_service.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/feedback.dart';

/// Folha de compartilhamento da lista.
///
/// Convite por código curto, sem sistema de amigos: o código viaja pelo
/// WhatsApp, que é onde a família já está. Só o dono convida, revoga e remove
/// gente; o membro vê quem participa e pode sair.
class FolhaCompartilhar extends StatefulWidget {
  final ListaModel lista;

  const FolhaCompartilhar({super.key, required this.lista});

  static Future<void> abrir(BuildContext context, ListaModel lista) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FolhaCompartilhar(lista: lista),
    );
  }

  @override
  State<FolhaCompartilhar> createState() => _FolhaCompartilharState();
}

class _FolhaCompartilharState extends State<FolhaCompartilhar> {
  final _api = ApiService();

  String? _codigo;
  bool _gerando = false;
  String? _erro;

  bool get _souDono =>
      widget.lista.donoId == null ||
      widget.lista.donoId == ParametrosGlobais.usuario?.id;

  @override
  void initState() {
    super.initState();
    if (_souDono) _gerar();
  }

  Future<void> _gerar() async {
    setState(() {
      _gerando = true;
      _erro = null;
    });
    try {
      final convite = await _api.criarConvite(widget.lista.id);
      if (mounted) setState(() => _codigo = convite.codigo);
    } catch (e) {
      if (mounted) {
        setState(() => _erro =
            'Não deu para gerar o convite agora. Convidar precisa de conexão.');
      }
    } finally {
      if (mounted) setState(() => _gerando = false);
    }
  }

  /// "K4M2VD" → "K4M-2VD": mais fácil de ditar e de digitar.
  String get _codigoBonito {
    final c = _codigo ?? '';
    return c.length == 6 ? '${c.substring(0, 3)}-${c.substring(3)}' : c;
  }

  Future<void> _enviar() async {
    final texto = 'Vem montar a lista "${widget.lista.nome}" comigo no Bipa!\n'
        'Abra o app, toque em "Entrar numa lista" e use o código '
        '$_codigoBonito';
    try {
      await SharePlus.instance.share(ShareParams(text: texto));
    } catch (_) {
      // Sem menu de compartilhar (desktop): o código na tela já resolve.
    }
  }

  Future<void> _revogar() async {
    final ok = await confirmar(
      context,
      titulo: 'Revogar o código?',
      mensagem: 'O código atual deixa de funcionar na hora. Quem já entrou '
          'continua na lista.',
      confirmarTexto: 'Revogar',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      await _api.revogarConvite(widget.lista.id);
      setState(() => _codigo = null);
      await _gerar(); // já nasce um código novo no lugar
      Aviso.sucesso('Código trocado.');
    } catch (_) {
      Aviso.erro('Não deu para revogar agora. Tente com conexão.');
    }
  }

  Future<void> _remover(MembroModel membro) async {
    final ok = await confirmar(
      context,
      titulo: 'Remover ${membro.nome.split(' ').first}?',
      mensagem: 'A pessoa deixa de ver e editar esta lista.',
      confirmarTexto: 'Remover',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      await _api.removerMembro(widget.lista.id, membro.usuarioId);
      await Get.find<ListasController>().atualizarDoServidor();
      if (mounted) Navigator.pop(context);
      Aviso.neutro('${membro.nome.split(' ').first} saiu da lista.');
    } catch (_) {
      Aviso.erro('Não deu para remover agora. Tente com conexão.');
    }
  }

  Future<void> _sair() async {
    final ok = await confirmar(
      context,
      titulo: 'Sair desta lista?',
      mensagem: 'Ela some do seu app, mas continua existindo para os outros. '
          'Para voltar, é só entrar com um código novo.',
      confirmarTexto: 'Sair da lista',
      destrutivo: true,
    );
    if (!ok) return;
    try {
      await _api.removerMembro(
          widget.lista.id, ParametrosGlobais.usuario!.id);
      await Get.find<ListasController>().atualizarDoServidor();
      if (mounted) {
        Navigator.pop(context);
        Get.offAllNamed('/inicio');
      }
    } catch (_) {
      Aviso.erro('Não deu para sair agora. Tente com conexão.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = widget.lista;
    final meuId = ParametrosGlobais.usuario?.id;

    return Container(
      decoration: const BoxDecoration(
        color: Cores.superficie,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 18,
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
            const SizedBox(height: 16),
            const Text('Compartilhar lista',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'Quem entrar com o código passa a ver e editar esta lista — '
              'e a bipar junto.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5, color: Cores.texto2, height: 1.45),
            ),

            if (_souDono) ...[
              const SizedBox(height: 16),
              Cartao(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('CÓDIGO DO CONVITE', style: rotulo),
                    const SizedBox(height: 6),
                    if (_gerando)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Cores.laranja),
                        ),
                      )
                    else if (_erro != null)
                      Text(
                        _erro!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 12.5,
                            color: Cores.carmim,
                            height: 1.4),
                      )
                    else
                      Text(
                        _codigoBonito,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 4,
                          color: Cores.laranjaEscuro,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    const SizedBox(height: 4),
                    const Text(
                      'vale por 7 dias · quantas pessoas você quiser',
                      style: TextStyle(fontSize: 10.5, color: Cores.texto3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              BotaoPrincipal(
                'Enviar convite',
                icone: Icons.share_outlined,
                altura: 46,
                aoTocar: _codigo == null ? null : _enviar,
              ),
            ],

            const TituloCategoria('Quem está na lista'),
            _Pessoa(
              nome: lista.donoNome ?? 'Dono',
              papel: 'dono da lista',
              inicial: (lista.donoNome ?? 'D')[0].toUpperCase(),
              destaque: lista.donoId == meuId,
            ),
            for (final m in lista.membros)
              _Pessoa(
                nome: m.nome,
                papel: 'edita e bipa',
                inicial: m.nome.isEmpty ? '?' : m.nome[0].toUpperCase(),
                destaque: m.usuarioId == meuId,
                aoRemover:
                    _souDono && m.usuarioId != meuId ? () => _remover(m) : null,
              ),

            const SizedBox(height: 12),
            if (_souDono && _codigo != null)
              TextButton(
                onPressed: _revogar,
                child: const Text('Revogar código',
                    style: TextStyle(fontSize: 12.5, color: Cores.texto3)),
              )
            else if (!_souDono)
              BotaoSecundario(
                'Sair desta lista',
                icone: Icons.logout,
                cor: Cores.carmim,
                aoTocar: _sair,
              ),
          ],
        ),
      ),
    );
  }
}

class _Pessoa extends StatelessWidget {
  final String nome;
  final String papel;
  final String inicial;
  final bool destaque;
  final VoidCallback? aoRemover;

  const _Pessoa({
    required this.nome,
    required this.papel,
    required this.inicial,
    this.destaque = false,
    this.aoRemover,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Cores.linha)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: destaque ? Cores.laranjaSuave : Cores.superficie3,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                inicial,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: destaque ? Cores.laranjaEscuro : Cores.texto2,
                ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  destaque ? '$nome (você)' : nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                Text(papel,
                    style:
                        const TextStyle(fontSize: 11, color: Cores.texto3)),
              ],
            ),
          ),
          if (aoRemover != null)
            TextButton(
              onPressed: aoRemover,
              child: const Text('remover',
                  style: TextStyle(fontSize: 12, color: Cores.carmim)),
            ),
        ],
      ),
    );
  }
}
