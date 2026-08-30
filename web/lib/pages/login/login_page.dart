import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auth_controller.dart';
import '../../widget/componentes.dart';
import '../../widget/cores.dart';

/// Entrada e cadastro na mesma tela, alternados por um botão de texto.
///
/// Duas telas separadas para uma decisão tão pequena é atrito — e cadastro
/// é onde a maioria dos apps de lista perde o usuário.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = Get.find<AuthController>();
  final _formulario = GlobalKey<FormState>();
  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();

  bool _cadastrando = false;
  bool _senhaVisivel = false;

  @override
  void dispose() {
    _nome.dispose();
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    final ok = _cadastrando
        ? await _auth.cadastrar(_nome.text, _email.text, _senha.text)
        : await _auth.entrar(_email.text, _senha.text);
    if (ok) Get.offAllNamed('/inicio');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.fundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Marca(),
                    const SizedBox(height: 28),
                    Text(
                      _cadastrando ? 'Criar conta' : 'Entrar',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cadastrando
                          ? 'Suas listas ficam salvas e sincronizadas.'
                          : 'Bem-vindo de volta.',
                      style: const TextStyle(color: Cores.texto2, fontSize: 14),
                    ),
                    const SizedBox(height: 22),

                    if (_cadastrando) ...[
                      _Campo(
                        controle: _nome,
                        rotulo: 'Seu nome',
                        icone: Icons.person_outline,
                        validador: (v) => (v == null || v.trim().length < 2)
                            ? 'Informe seu nome.'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],

                    _Campo(
                      controle: _email,
                      rotulo: 'E-mail',
                      icone: Icons.alternate_email,
                      tipo: TextInputType.emailAddress,
                      validador: (v) => (v == null || !v.contains('@'))
                          ? 'Informe um e-mail válido.'
                          : null,
                    ),
                    const SizedBox(height: 12),

                    _Campo(
                      controle: _senha,
                      rotulo: 'Senha',
                      icone: Icons.lock_outline,
                      oculto: !_senhaVisivel,
                      sufixo: IconButton(
                        icon: Icon(
                          _senhaVisivel
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: Cores.texto3,
                        ),
                        onPressed: () =>
                            setState(() => _senhaVisivel = !_senhaVisivel),
                      ),
                      validador: (v) => (v == null || v.length < 6)
                          ? 'A senha precisa ter ao menos 6 caracteres.'
                          : null,
                    ),

                    Obx(() {
                      final erro = _auth.erro.value;
                      if (erro == null) return const SizedBox(height: 20);
                      return Padding(
                        padding: const EdgeInsets.only(top: 14, bottom: 6),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Cores.carmimSuave,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 18, color: Cores.carmim),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  erro,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: Cores.carmim,
                                      height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    Obx(() => BotaoPrincipal(
                          _cadastrando ? 'Criar conta' : 'Entrar',
                          carregando: _auth.carregando.value,
                          aoTocar: _enviar,
                        )),
                    const SizedBox(height: 14),

                    TextButton(
                      onPressed: () {
                        _auth.erro.value = null;
                        setState(() => _cadastrando = !_cadastrando);
                      },
                      child: Text(
                        _cadastrando
                            ? 'Já tenho conta · Entrar'
                            : 'Criar uma conta',
                        style: const TextStyle(
                          color: Cores.laranjaEscuro,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Cadastro na primeira tela é onde a maioria dos apps de
                    // lista perde o usuário. Aqui dá para experimentar antes.
                    if (!_cadastrando) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Divider(color: Cores.linha)),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text('ou',
                                  style: TextStyle(
                                      fontSize: 12, color: Cores.texto3)),
                            ),
                            Expanded(child: Divider(color: Cores.linha)),
                          ],
                        ),
                      ),
                      BotaoSecundario(
                        'Usar sem conta',
                        icone: Icons.flash_on_outlined,
                        aoTocar: _auth.usarSemConta,
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Suas listas ficam só neste aparelho. Bipar código de '
                          'barras e sincronizar precisam de conta — e o que você '
                          'já criou sobe junto quando ela existir.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 11.5,
                              color: Cores.texto3,
                              height: 1.45),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          decoration: BoxDecoration(
            color: Cores.laranja,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconeBarras(tamanho: 21),
              SizedBox(width: 9),
              Text(
                'Bipa',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController controle;
  final String rotulo;
  final IconData icone;
  final bool oculto;
  final TextInputType? tipo;
  final Widget? sufixo;
  final String? Function(String?)? validador;

  const _Campo({
    required this.controle,
    required this.rotulo,
    required this.icone,
    this.oculto = false,
    this.tipo,
    this.sufixo,
    this.validador,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controle,
      obscureText: oculto,
      keyboardType: tipo,
      autocorrect: false,
      validator: validador,
      decoration: InputDecoration(
        labelText: rotulo,
        prefixIcon: Icon(icone, size: 20, color: Cores.texto3),
        suffixIcon: sufixo,
        filled: true,
        fillColor: Cores.superficie,
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
          borderSide: const BorderSide(color: Cores.laranja, width: 1.6),
        ),
      ),
    );
  }
}
