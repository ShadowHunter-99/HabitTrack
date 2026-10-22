import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/habit_provider.dart';
import 'screens/app_shell.dart';

void main() {
  runApp(const HabitTrackApp());
}

/// Widget raíz de la aplicación.
///
/// Configura el [HabitProvider] en la cima del árbol de widgets para que
/// toda la app pueda acceder al estado, y define el tema visual.
class HabitTrackApp extends StatelessWidget {
  const HabitTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      // Se crea el provider y se dispara la carga inicial de datos.
      // El operador en cascada (`..`) registra el provider recién creado
      // mientras la carga corre en segundo plano.
      create: (_) => HabitProvider()..loadHabits(),
      child: MaterialApp(
        title: 'HabitTrack',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        ),
        home: const AppShell(),
      ),
    );
  }
}
