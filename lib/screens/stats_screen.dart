import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/day_status.dart';
import '../models/habit_progress.dart';
import '../providers/habit_provider.dart';

/// Rango temporal que muestra el gráfico de estadísticas.
enum StatsRange {
  week(7, 'Semana'),
  month(30, 'Mes');

  const StatsRange(this.days, this.label);

  /// Número de días que abarca (contando hoy).
  final int days;

  /// Etiqueta visible en el selector.
  final String label;
}

/// Iniciales de los días de la semana para el eje horizontal.
const List<String> _kDiasSemana = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

/// Pantalla de Estadísticas.
///
/// - Indicadores clave: racha actual y racha máxima (del hábito
///   seleccionado, o la mejor entre todos los hábitos).
/// - Gráfico de barras con el historial de días completados vs.
///   complicados, en vista semanal o mensual.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// Id del hábito seleccionado; `null` significa "todos".
  int? _selectedHabitId;

  /// Rango del gráfico (semana / mes).
  StatsRange _range = StatsRange.week;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HabitProvider>();
    final theme = Theme.of(context);

    if (provider.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Sin hábitos todavía no hay nada que graficar.
    if (provider.habits.isEmpty) {
      return const Scaffold(body: _EmptyStats());
    }

    // Si el hábito seleccionado ya no existe (p. ej. se eliminó en la
    // otra pestaña), se vuelve a la vista "Todos".
    HabitProgress? seleccionado;
    for (final h in provider.habits) {
      if (h.habit.id == _selectedHabitId) {
        seleccionado = h;
        break;
      }
    }
    final mostrados =
        seleccionado != null ? [seleccionado] : provider.habits;

    final datos = _agregar(mostrados, _range);

    // Rachas clave: del hábito seleccionado o la mejor entre todos.
    final rachaActual = mostrados
        .fold<int>(0, (max, h) => h.currentStreak > max ? h.currentStreak : max);
    final rachaMaxima = mostrados
        .fold<int>(0, (max, h) => h.maxStreak > max ? h.maxStreak : max);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Estadísticas'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Selector de hábito (o "todos").
          //
          // Se usa `initialValue` junto a una clave que cambia con la
          // selección *efectiva*: si el hábito elegido desaparece (p. ej.
          // se eliminó en la otra pestaña), el campo se reconstruye y
          // vuelve a mostrar "Todos los hábitos" en lugar de quedarse con
          // un valor huérfano.
          KeyedSubtree(
            key: ValueKey(seleccionado?.habit.id),
            child: DropdownButtonFormField<int?>(
              initialValue: seleccionado?.habit.id,
              decoration: const InputDecoration(
                labelText: 'Hábito',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.filter_list_rounded),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Todos los hábitos'),
                ),
                for (final h in provider.habits)
                  DropdownMenuItem<int?>(
                    value: h.habit.id,
                    child: Text(
                      h.habit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (valor) =>
                  setState(() => _selectedHabitId = valor),
            ),
          ),
          const SizedBox(height: 16),

          // Indicadores clave.
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.75,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _KpiCard(
                label: 'Racha actual',
                value: rachaActual,
                suffix: 'días seguidos',
                icon: Icons.local_fire_department_rounded,
                color: Colors.deepOrange,
              ),
              _KpiCard(
                label: 'Racha máxima',
                value: rachaMaxima,
                suffix: 'días seguidos',
                icon: Icons.emoji_events_rounded,
                color: Colors.amber.shade800,
              ),
              _KpiCard(
                label: 'Completados',
                value: datos.totalCompletados,
                suffix: 'en ${_range.days} días',
                icon: Icons.check_circle_outline_rounded,
                color: theme.colorScheme.primary,
              ),
              _KpiCard(
                label: 'Complicados',
                value: datos.totalComplicados,
                suffix: 'en ${_range.days} días',
                icon: Icons.cancel_outlined,
                color: Colors.deepOrange,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Selector de rango temporal.
          SegmentedButton<StatsRange>(
            segments: [
              for (final r in StatsRange.values)
                ButtonSegment(value: r, label: Text(r.label)),
            ],
            selected: {_range},
            onSelectionChanged: (seleccion) =>
                setState(() => _range = seleccion.first),
          ),
          const SizedBox(height: 16),

          // Gráfico de barras agrupadas.
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Completados vs. complicados por día',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: _HabitBarChart(
                      days: datos.days,
                      completados: datos.completados,
                      complicados: datos.complicados,
                      range: _range,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _ChartLegendDot(
                        color: theme.colorScheme.primary,
                        label: 'Completados',
                      ),
                      const SizedBox(width: 16),
                      const _ChartLegendDot(
                        color: Colors.deepOrange,
                        label: 'Complicados',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Agrega el historial de los hábitos indicados en listas por día.
  ///
  /// Para cada día del rango cuenta cuántos hábitos se completaron y
  /// cuántos se marcaron como complicados.
  _StatsAggregate _agregar(List<HabitProgress> habits, StatsRange range) {
    final hoy = HabitProgress.dayOnly(DateTime.now());
    final days = List.generate(
      range.days,
      (i) => hoy.subtract(Duration(days: range.days - 1 - i)),
    );
    final completados = List<int>.filled(range.days, 0);
    final complicados = List<int>.filled(range.days, 0);

    for (final h in habits) {
      for (var i = 0; i < days.length; i++) {
        final status = h.dayStatuses[days[i]];
        if (status == DayStatus.completed) {
          completados[i]++;
        } else if (status == DayStatus.difficult) {
          complicados[i]++;
        }
      }
    }

    var totalCompletados = 0;
    var totalComplicados = 0;
    for (var i = 0; i < days.length; i++) {
      totalCompletados += completados[i];
      totalComplicados += complicados[i];
    }

    return _StatsAggregate(
      days: days,
      completados: completados,
      complicados: complicados,
      totalCompletados: totalCompletados,
      totalComplicados: totalComplicados,
    );
  }
}

/// Resultado de la agregación diaria que consume el gráfico.
class _StatsAggregate {
  const _StatsAggregate({
    required this.days,
    required this.completados,
    required this.complicados,
    required this.totalCompletados,
    required this.totalComplicados,
  });

  /// Días del rango, del más antiguo al más reciente.
  final List<DateTime> days;

  /// Número de hábitos completados por día (paralelo a [days]).
  final List<int> completados;

  /// Número de hábitos complicados por día (paralelo a [days]).
  final List<int> complicados;

  final int totalCompletados;
  final int totalComplicados;
}

/// Gráfico de barras agrupadas: barras verdes = completados, barras
/// naranjas = complicados. Un grupo por día.
class _HabitBarChart extends StatelessWidget {
  const _HabitBarChart({
    required this.days,
    required this.completados,
    required this.complicados,
    required this.range,
  });

  final List<DateTime> days;
  final List<int> completados;
  final List<int> complicados;
  final StatsRange range;

  /// Etiqueta del eje horizontal para un día dado.
  String _etiquetaDia(int index) {
    final day = days[index];
    if (range == StatsRange.week) {
      return _kDiasSemana[day.weekday - 1];
    }
    // En vista mensual solo se etiqueta cada 5 días para no saturar el eje.
    return (index % 5 == 0 || index == days.length - 1) ? '${day.day}' : '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorCompletado = theme.colorScheme.primary;
    const colorComplicado = Colors.deepOrange;

    // Altura máxima: al menos 1 para que el eje Y tenga rango.
    var maxValor = 0;
    for (var i = 0; i < days.length; i++) {
      if (completados[i] > maxValor) maxValor = completados[i];
      if (complicados[i] > maxValor) maxValor = complicados[i];
    }
    final maxY = (maxValor == 0 ? 1 : maxValor).toDouble();

    // Barras más finas en vista mensual (30 grupos).
    final anchoBarra = range == StatsRange.week ? 10.0 : 3.0;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: maxY <= 4 ? 1 : (maxY / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                child: Text(
                  value.toInt().toString(),
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                final etiqueta =
                    (index >= 0 && index < days.length)
                        ? _etiquetaDia(index)
                        : '';
                return SideTitleWidget(
                  meta: meta,
                  child: Text(etiqueta, style: theme.textTheme.bodySmall),
                );
              },
            ),
          ),
        ),
        gridData: const FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
        ),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: completados[i].toDouble(),
                  color: colorCompletado,
                  width: anchoBarra,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: complicados[i].toDouble(),
                  color: colorComplicado,
                  width: anchoBarra,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Tarjeta de indicador clave (KPI) con icono, valor y sufijo.
class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.color,
  });

  final String label;
  final int value;
  final String suffix;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            suffix,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Punto de color con etiqueta, para la leyenda del gráfico.
class _ChartLegendDot extends StatelessWidget {
  const _ChartLegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Estado vacío cuando todavía no hay hábitos que graficar.
class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

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
              Icons.insights_outlined,
              size: 72,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text('Sin datos todavía', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Crea hábitos y márcalos cada día para ver aquí tus '
              'estadísticas y rachas.',
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
