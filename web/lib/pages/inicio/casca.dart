import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../widget/cores.dart';
import '../ajustes/ajustes_page.dart';
import '../listas/listas_page.dart';
import '../produtos/produtos_page.dart';
import 'inicio_page.dart';

/// Casca com a navegação inferior.
///
/// O Modo Compra e o scanner ficam FORA dela de propósito: dentro do
/// supermercado a tela é imersiva e o polegar só precisa encontrar BIPAR.
class Casca extends StatefulWidget {
  const Casca({super.key});

  @override
  State<Casca> createState() => _CascaState();
}

class _CascaState extends State<Casca> {
  int _aba = 0;

  static const _paginas = [
    InicioPage(),
    ListasPage(),
    ProdutosPage(),
    AjustesPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.fundo,
      body: IndexedStack(index: _aba, children: _paginas),
      floatingActionButton: _aba <= 1
          ? FloatingActionButton(
              backgroundColor: Cores.laranja,
              foregroundColor: Colors.white,
              onPressed: () => Get.toNamed('/nova-lista'),
              child: const Icon(Icons.add, size: 26),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        height: 62,
        backgroundColor: Cores.superficie,
        indicatorColor: Cores.laranjaSuave,
        selectedIndex: _aba,
        onDestinationSelected: (i) => setState(() => _aba = i),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Cores.laranjaEscuro),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt, color: Cores.laranjaEscuro),
            label: 'Listas',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2, color: Cores.laranjaEscuro),
            label: 'Produtos',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Cores.laranjaEscuro),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}
