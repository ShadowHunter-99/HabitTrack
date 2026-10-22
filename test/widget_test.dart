// Tests de la aplicación.
//
// En un entorno de test no hay canales de plugins, por lo que sqflite no
// puede abrir la base de datos real. HabitProvider captura ese error y lo
// muestra en pantalla, así que los tests de arranque verifican que la app
// se dibuja sin caer. Para la lógica de rachas y estadísticas se inyecta
// un HabitProvider con datos ya cargados en memoria.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:habit_track/main.dart';
import 'package:habit_track/models/day_status.dart';
import 'package:habit_track/models/habit.dart';
import 'package:habit_track/models/habit_progress.dart';
import 'package:habit_track/providers/habit_provider.dart';
import 'package:habit_track/screens/app_shell.dart';

void main() {
  group('Arranque y creación', () {
    testWidgets('La app arranca y muestra la pantalla principal',
        (WidgetTester tester) async {
      await tester.pumpWidget(const HabitTrackApp());

      // Deja que se complete la carga inicial (async) del provider.
      await tester.pumpAndSettle();

      expect(find.text('HabitTrack'), findsOneWidget);
      expect(find.text('Nuevo hábito'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('El diálogo de creación valida el nombre vacío',
        (WidgetTester tester) async {
      await tester.pumpWidget(const HabitTrackApp());
      await tester.pumpAndSettle();

      // Abre el diálogo de creación.
      await tester.tap(find.text('Nuevo hábito'));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo hábito'), findsWidgets);

      // Intenta guardar sin escribir nada: debe aparecer el error de
      // validación y el diálogo debe seguir abierto.
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(find.text('El nombre no puede estar vacío'), findsOneWidget);
    });
  });

  group('Rachas y estadísticas (datos en memoria)', () {
    HabitProvider providerConDatos() {
      final ahora = DateTime.now();
      // Día normalizado de hace `dias` atrás.
      DateTime dia(int dias) =>
          HabitProgress.dayOnly(ahora.subtract(Duration(days: dias)));

      final estados = <DateTime, DayStatus>{
        // Racha actual: hoy, ayer y hace 2 días.
        dia(0): DayStatus.completed,
        dia(1): DayStatus.completed,
        dia(2): DayStatus.completed,
        // Ayer-3 marcado como complicado: rompe la racha anterior.
        dia(3): DayStatus.difficult,
        // Racha máxima histórica: 5 días seguidos.
        dia(10): DayStatus.completed,
        dia(11): DayStatus.completed,
        dia(12): DayStatus.completed,
        dia(13): DayStatus.completed,
        dia(14): DayStatus.completed,
      };

      return HabitProvider()
        ..habits = [
          HabitProgress(
            habit: Habit(
              id: 1,
              name: 'Leer',
              description: 'Antes de dormir',
              createdAt: ahora,
            ),
            dayStatuses: estados,
          ),
        ];
    }

    testWidgets('Las insignias del hábito muestran racha 3 y máxima 5',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: providerConDatos(),
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      // La tarjeta muestra ambas insignias con sus valores.
      expect(find.byTooltip('Racha actual (días consecutivos)'),
          findsOneWidget);
      expect(find.byTooltip('Racha máxima alcanzada'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
      expect(find.text('5'), findsWidgets);
    });

    testWidgets('La pestaña de estadísticas muestra los KPIs correctos',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: providerConDatos(),
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      // Cambia a la pestaña de estadísticas (icono del NavigationBar).
      await tester.tap(find.byIcon(Icons.insights_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Racha actual'), findsOneWidget);
      expect(find.text('Racha máxima'), findsOneWidget);
      expect(find.text('Completados'), findsOneWidget);
      expect(find.text('Complicados'), findsOneWidget);
      // Valores calculados: racha actual 3, máxima 5.
      expect(find.text('3'), findsWidgets);
      expect(find.text('5'), findsWidgets);
    });

    testWidgets('Mantener pulsado un hábito ofrece editarlo con sus datos',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: providerConDatos(),
          child: const MaterialApp(home: AppShell()),
        ),
      );
      await tester.pumpAndSettle();

      // Mantener pulsada la tarjeta abre la hoja de acciones.
      await tester.longPress(find.text('Leer'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Editar nombre o descripción'));
      await tester.pumpAndSettle();

      // El diálogo se abre en modo edición con el nombre precargado.
      expect(find.text('Editar hábito'), findsOneWidget);
      expect(find.text('Guardar cambios'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Leer'), findsOneWidget);
    });
  });
}
