import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/listas_controller.dart';
import '../../services/api_service.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';
import '../../widget/feedback.dart';

/// Entrar numa lista com o código recebido.
///
/// Prévia antes de entrar — nome, dono, tamanho — porque ninguém deve entrar
/// numa lista às cegas por causa de um link.
class FolhaEntrar extends StatefulWidget {
  const FolhaEntrar({super.key});

  static Future<void> abrir(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FolhaEntrar(),
    );
  }

  @override
  State<FolhaEntrar> createState() => _FolhaEntrarState();
}

class _FolhaEntrarState extends State<FolhaEntrar> {
  final _api = ApiService();
  final _codigo = TextEditingController();

  ({String nome, String dono, int itens})? _previa;
  bool _buscando = false;
  bool _entrando = false;
  String? _erro;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  String get _limpo =>
      _codigo.text.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  Future<void> _buscar() async {
    if (_limpo.length < 6) return;
    setState(() {
      _buscando = true;
      _erro = null;
      _previa = null;
    });
    try {
      final p = await _api.previaConvite(_limpo);
      if (mounted) setState(() => _previa = p);
    } catch (e) {
      if (mounted) {
        setState(() =>
            _erro = e.toString().replaceFirst('Exception: ', '').trim());
      }
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _entrar() async {
    setState(() => _entrando = true);
    try {
      await _api.aceitarConvite(_limpo);
      await Get.find<ListasController>().atualizarDoServidor();
      if (mounted) Navigator.pop(context);
      Aviso.sucesso('Você entrou em "${_previa?.nome}".');
    } catch (e) {
      if (mounted) {
        setState(() {
          _entrando = false;
          _erro = e.toString().replaceFirst('Exception: ', '').trim();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          const Text('Entrar numa lista',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'Digite o código que você recebeu.',
            style: TextStyle(fontSize: 12.5, color: Cores.texto2),
          ),
          const SizedBox(height: 14),

          TextField(
            controller: _codigo,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: 8, // 6 + o traço que a pessoa pode digitar junto
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              hintText: 'K4M-2VD',
              counterText: '',
              hintStyle: TextStyle(
                fontSize: 24,
                letterSpacing: 4,
                color: Cores.texto3.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: Cores.laranjaSuave,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Cores.laranja),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: Cores.laranja),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide:
                    const BorderSide(color: Cores.laranja, width: 1.8),
              ),
            ),
            onChanged: (_) {
              if (_limpo.length >= 6) _buscar();
            },
            onSubmitted: (_) => _buscar(),
          ),

          if (_buscando) ...[
            const SizedBox(height: 14),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  strokeWidth: 2.5, color: Cores.laranja),
            ),
          ],

          if (_erro != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Cores.carmimSuave,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Text(
                _erro!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5, color: Cores.carmim, height: 1.4),
              ),
            ),
          ],

          if (_previa != null) ...[
            const SizedBox(height: 12),
            Cartao(
              cor: Cores.superficie,
              borda: Border.all(color: Cores.linha),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Cores.superficie3,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.shopping_cart_outlined,
                        size: 20, color: Cores.texto2),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_previa!.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(
                          'de ${_previa!.dono} · ${_previa!.itens} itens',
                          style: const TextStyle(
                              fontSize: 11.5, color: Cores.texto3),
                        ),
                      ],
                    ),
                  ),
                  const Etiqueta('encontrada',
                      cor: Cores.verde, fundo: Cores.verdeSuave),
                ],
              ),
            ),
            const SizedBox(height: 12),
            BotaoPrincipal(
              'Entrar na lista',
              carregando: _entrando,
              aoTocar: _entrar,
            ),
          ],
        ],
      ),
    );
  }
}
