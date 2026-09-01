import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'controllers/auth_controller.dart';
import 'controllers/conexao_controller.dart';
import 'controllers/listas_controller.dart';
import 'globais/parametros_globais.dart';
import 'navigation/auth_middleware.dart';
import 'offline/sincronizador.dart';
import 'pages/ajustes/ajustes_page.dart';
import 'pages/ajustes/categorias_page.dart';
import 'pages/compra/modo_compra_page.dart';
import 'pages/compra/resumo_page.dart';
import 'pages/compra/scanner_page.dart';
import 'pages/inicio/casca.dart';
import 'pages/listas/lista_page.dart';
import 'pages/listas/nova_lista_page.dart';
import 'pages/login/login_page.dart';
import 'widget/cores.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _instalarTelaDeErro();
  await initializeDateFormatting('pt_BR');
  await Sessao.carregar();

  Get.put(AuthController(), permanent: true);
  Get.put(ConexaoController(), permanent: true);
  Get.put(ListasController(), permanent: true);

  // Sincroniza ao abrir. Além de trazer o que mudou em outro aparelho, é a
  // defesa contra a limpeza de IndexedDB do iOS: quanto antes os dados
  // chegarem ao servidor, menor a janela de perda.
  if (ParametrosGlobais.logado) {
    Sincronizador.sincronizar().then((_) {
      if (Get.isRegistered<ListasController>()) {
        Get.find<ListasController>().recarregar();
      }
    });
  }

  runApp(const BipaApp());
}

/// Substitui o retângulo cinza que o Flutter mostra quando uma tela falha ao
/// construir. Em versão de release aquilo aparece como uma tela em branco, sem
/// dizer nada — o usuário fica sem saber se travou e sem caminho de volta.
void _instalarTelaDeErro() {
  ErrorWidget.builder = (detalhes) => Material(
        color: Cores.fundo,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 42, color: Cores.carmim),
                const SizedBox(height: 14),
                const Text(
                  'Essa tela não abriu',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Seus dados estão salvos. Volte e tente de novo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, color: Cores.texto2, height: 1.45),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Cores.laranja),
                  onPressed: () => Get.offAllNamed('/inicio'),
                  child: const Text('Voltar ao início'),
                ),
              ],
            ),
          ),
        ),
      );
}

class BipaApp extends StatelessWidget {
  const BipaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Bipa',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Cores.laranja,
          primary: Cores.laranja,
          surface: Cores.superficie,
        ),
        scaffoldBackgroundColor: Cores.fundo,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Cores.superficie,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Cores.tinta,
        ),
        splashFactory: InkSparkle.splashFactory,
      ),
      initialRoute: ParametrosGlobais.logado ? '/inicio' : '/login',
      getPages: [
        GetPage(
          name: '/login',
          page: () => const LoginPage(),
          middlewares: [ConvidadoMiddleware()],
        ),
        GetPage(
          name: '/inicio',
          page: () => const Casca(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/nova-lista',
          page: () => const NovaListaPage(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/lista',
          page: () => const ListaPage(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/compra',
          page: () => const ModoCompraPage(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/scanner',
          page: () => const ScannerPage(),
          middlewares: [AuthMiddleware()],
          // Sem animação: a câmera precisa aparecer no ato.
          transition: Transition.noTransition,
        ),
        GetPage(
          name: '/resumo',
          page: () => const ResumoPage(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/ajustes',
          page: () => const AjustesPage(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/categorias',
          page: () => const CategoriasPage(),
          middlewares: [AuthMiddleware()],
        ),
      ],
    );
  }
}
