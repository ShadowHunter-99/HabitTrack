import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/habit_progress.dart';
import '../providers/habit_provider.dart';
import 'widgets/add_habit_dialog.dart';
import 'widgets/habit_tile.dart';

/// Pantalla principal (pestaña "Hábitos").
///
/// - Lista todos los hábitos creados con su racha actual y máxima.
/// - Permite marcar cada hábito hoy como completado (tocando la tarjeta)
///   o como complicado (botón ✗).
/// - Mantener pulsada una tarjeta abre las acciones de editar / eliminar.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  /// Abre el diálogo de creación y, si el usuario guardó datos, crea el
  /// hábito a través del provider.
  Future<void> _openCreateDialog(BuildContext context) async {
    final input = await showDialog<HabitInput>(
      context: context,
      builder: (_) => const AddHabitDialog(),
    );

    if (input == null) return; // El usuario canceló el diálogo.

    // Tras un `await` el contexto podría ya no ser válido; hay que
    // comprobarlo antes de usarlo de nuevo.
    if (!context.mounted) return;
    await context.read<HabitProvider>().addHabit(
          input.name,
          input.description,
        );
  }

  /// Abre la hoja inferior con las acciones disponibles sobre un hábito
  /// (editar / eliminar). Se muestra al mantener pulsada la tarjeta.
  Future<void> _openHabitActions(
    BuildContext context,
    HabitProgress progress,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final sheetTheme = Theme.of(sheetContext);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  progress.habit.name,
                  style: sheetTheme.textTheme.titleMedium,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar nombre o descripción'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openEditDialog(context, progress);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: sheetTheme.colorScheme.error,
                ),
                title: Text(
                  'Eliminar',
                  style: TextStyle(color: sheetTheme.colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDelete(context, progress);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Abre el diálogo de edición con los datos actuales del hábito y, si
  /// el usuario confirma, aplica los cambios.
  Future<void> _openEditDialog(
    BuildContext context,
    HabitProgress progress,
  ) async {
    final input = await showDialog<HabitInput>(
      context: context,
      builder: (_) => AddHabitDialog(
        initialName: progress.habit.name,
        initialDescription: progress.habit.description,
      ),
    );

    if (input == null) return; // Sin cambios.
    if (!context.mounted) return; // Guard tras el await.

    await context
        .read<HabitProvider>()
        .updateHabit(progress, input.name, input.description);
  }

  /// Pide confirmación antes de eliminar un hábito y su historial.
  Future<void> _confirmDelete(
    BuildContext context,
    HabitProgress progress,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar hábito?'),
        content: Text(
          'Se eliminará "${progress.habit.name}" y todo su historial. '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return; // Guard tras el await del diálogo.
    await context.read<HabitProvider>().deleteHabit(progress);
  }

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    const diasSemana = [
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
      'domingo',
    ];
    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final fechaLegible =
        '${diasSemana[hoy.weekday - 1]}, ${hoy.day} de ${meses[hoy.month - 1]}';

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('HabitTrack'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              fechaLegible,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ),
      body: Consumer<HabitProvider>(
        builder: (context, provider, _) {
          // 1. Carga inicial en curso.
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Error de carga (p. ej. base de datos no disponible).
          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.tonalIcon(
                      onPressed: () => provider.loadHabits(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            );
          }

          // 3. Aún no hay hábitos creados.
          if (provider.habits.isEmpty) {
            return const _EmptyState();
          }

          // 4. Lista de hábitos.
          return ListView.separated(
            // Padding inferior para que el FAB no tape la última tarjeta.
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            itemCount: provider.habits.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final habit = provider.habits[index];
              return HabitTile(
                progress: habit,
                onToggleCompleted: () =>
                    provider.toggleCompletedToday(habit),
                onToggleDifficult: () =>
                    provider.toggleDifficultToday(habit),
                onOpenActions: () => _openHabitActions(context, habit),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo hábito'),
      ),
    );
  }
}

/// Estado vacío que se muestra cuando todavía no hay hábitos creados.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('Aún no hay hábitos', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Crea tu primer hábito con el botón «Nuevo hábito» '
              'y empieza a construir tu racha.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
