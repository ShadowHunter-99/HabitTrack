import 'package:flutter/material.dart';

import '../../models/habit_progress.dart';

/// Tarjeta que representa un hábito en la pantalla principal.
///
/// - Tocar la tarjeta (o el botón ✓) marca/desmarca el hábito como
///   completado hoy.
/// - El botón ✗ marca el día de hoy como "complicado" (no se pudo
///   cumplir); tocarlo de nuevo lo desmarca.
/// - Las insignias 🔥 y 🏆 muestran la racha actual y la máxima.
/// - Mantener pulsada la tarjeta abre la hoja de acciones
///   (editar / eliminar), gestionada por la pantalla principal.
class HabitTile extends StatelessWidget {
  const HabitTile({
    super.key,
    required this.progress,
    required this.onToggleCompleted,
    required this.onToggleDifficult,
    required this.onOpenActions,
  });

  final HabitProgress progress;

  /// Se ejecuta al marcar/desmarcar el hábito como completado hoy.
  final VoidCallback onToggleCompleted;

  /// Se ejecuta al marcar/desmarcar hoy como día complicado.
  final VoidCallback onToggleDifficult;

  /// Se ejecuta al mantener pulsada la tarjeta (editar / eliminar).
  final VoidCallback onOpenActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completado = progress.isCompletedToday;
    final complicado = progress.isDifficultToday;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: completado
              ? theme.colorScheme.primary
              : complicado
                  ? Colors.deepOrange
                  : theme.colorScheme.outlineVariant,
          width: (completado || complicado) ? 1.5 : 1,
        ),
      ),
      color: completado
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : complicado
              ? Colors.deepOrange.withValues(alpha: 0.06)
              : theme.colorScheme.surface,
      child: InkWell(
        onTap: onToggleCompleted,
        onLongPress: onOpenActions,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          child: Row(
            children: [
              // Botones de estado del día de hoy: ✓ completado, ✗ complicado.
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onToggleCompleted,
                    tooltip: completado
                        ? 'Quitar «completado» de hoy'
                        : 'Marcar como completado hoy',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      completado
                          ? Icons.check_circle_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 30,
                      color: completado
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                    ),
                  ),
                  IconButton(
                    onPressed: onToggleDifficult,
                    tooltip: complicado
                        ? 'Quitar «complicado» de hoy'
                        : 'Marcar hoy como complicado (no cumplido)',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      complicado
                          ? Icons.cancel_rounded
                          : Icons.cancel_outlined,
                      size: 30,
                      color: complicado
                          ? Colors.deepOrange
                          : theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Nombre, descripción y rachas.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.habit.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        decoration: completado
                            ? TextDecoration.lineThrough
                            : null,
                        color: completado ? theme.colorScheme.outline : null,
                      ),
                    ),
                    if (progress.habit.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        progress.habit.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _StreakChip(
                          icon: Icons.local_fire_department_rounded,
                          value: progress.currentStreak,
                          tooltip: 'Racha actual (días consecutivos)',
                          foreground: progress.currentStreak > 0
                              ? Colors.deepOrange
                              : null,
                        ),
                        _StreakChip(
                          icon: Icons.emoji_events_rounded,
                          value: progress.maxStreak,
                          tooltip: 'Racha máxima alcanzada',
                          foreground: progress.maxStreak > 0
                              ? Colors.amber.shade800
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pequeña insignia con icono y número (racha actual o máxima).
class _StreakChip extends StatelessWidget {
  const _StreakChip({
    required this.icon,
    required this.value,
    required this.tooltip,
    this.foreground,
  });

  final IconData icon;
  final int value;

  /// Texto de ayuda que explica qué representa el número.
  final String tooltip;

  /// Color del contenido; si es `null` se usa un tono neutro.
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = foreground ?? theme.colorScheme.outline;

    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 3),
            Text(
              '$value',
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
