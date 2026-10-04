import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class TrendPoint {
  const TrendPoint({required this.label, required this.value});

  final String label;
  final double value;
}

class TrendChartCard extends StatelessWidget {
  const TrendChartCard({
    super.key,
    required this.title,
    required this.points,
    required this.color,
    this.suffix = '',
  });

  final String title;
  final List<TrendPoint> points;
  final Color color;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final lineColor = Theme.of(context).brightness == Brightness.dark
        ? color.withRed(110).withGreen(210).withBlue(255)
        : color;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (points.isNotEmpty)
                  Text(
                    '${points.last.value.toStringAsFixed(1)}$suffix',
                    style: TextStyle(
                      color: lineColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (points.isEmpty)
              SizedBox(
                height: 90,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.show_chart,
                        size: 32,
                        color: color.withValues(alpha: .3),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No history yet',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Data will appear after your first sync',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: .45),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 150,
                child: LineChart(
                  LineChartData(
                    minY: 0,
                    maxY:
                        points
                                .map((p) => p.value)
                                .fold<double>(0, (m, v) => v > m ? v : m) <=
                            0
                        ? 100
                        : points
                                  .map((p) => p.value)
                                  .fold<double>(0, (m, v) => v > m ? v : m) *
                              1.2,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Colors.black.withValues(alpha: .07),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        axisNameWidget: Text(
                          'Hours',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) => Text(
                            value.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
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
                        axisNameWidget: Text(
                          'Day',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: points.length > 10 ? 5 : 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.round();
                            if (index < 0 || index >= points.length)
                              return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                points[index].label,
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) =>
                            Theme.of(context).colorScheme.inverseSurface,
                        getTooltipItems: (spots) => spots
                            .map(
                              (spot) => LineTooltipItem(
                                '${points[spot.x.round()].label}\n${spot.y.toStringAsFixed(1)}$suffix',
                                TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onInverseSurface,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].value),
                        ],
                        isCurved: points.length <= 10,
                        barWidth: 3,
                        color: lineColor,
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                                radius: 3,
                                color: lineColor,
                                strokeWidth: 1.5,
                                strokeColor: Theme.of(
                                  context,
                                ).colorScheme.surface,
                              ),
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: lineColor.withValues(alpha: .18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class CategoryPieCard extends StatelessWidget {
  const CategoryPieCard({super.key, required this.title, required this.values});

  final String title;
  final Map<String, double> values;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF256D85),
      const Color(0xFF287D5A),
      const Color(0xFFC8553D),
      const Color(0xFF7B61A8),
      const Color(0xFFB88746),
    ];
    final entries = values.entries.where((entry) => entry.value > 0).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            if (entries.isEmpty)
              const Text('No category data yet')
            else
              SizedBox(
                height: 170,
                child: Row(
                  children: [
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 34,
                          sections: [
                            for (var i = 0; i < entries.length; i++)
                              PieChartSectionData(
                                value: entries[i].value,
                                title: '',
                                radius: 48,
                                color: colors[i % colors.length],
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < entries.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: colors[i % colors.length],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(entries[i].key)),
                                  Text(entries[i].value.toStringAsFixed(0)),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
