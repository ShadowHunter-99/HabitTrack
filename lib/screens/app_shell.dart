import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'stats_screen.dart';

/// Contenedor principal con la barra de navegación inferior.
///
/// Mantiene ambas pantallas vivas con un [IndexedStack] para no perder su
/// estado (lista, selección, gráficos) al cambiar de pestaña.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _indiceActual = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _indiceActual,
        children: const [HomeScreen(), StatsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActual,
        onDestinationSelected: (valor) => setState(() => _indiceActual = valor),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.view_list_outlined),
            selectedIcon: Icon(Icons.view_list_rounded),
            label: 'Hábitos',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded),
            label: 'Estadísticas',
          ),
        ],
      ),
    );
  }
}
