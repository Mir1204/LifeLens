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
                    style:
                        TextStyle(color: color, fontWeight: FontWeight.w800),
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
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Data will appear after your first sync',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .45),
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
                    maxY: points
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
                    titlesData: const FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0; i < points.length; i++)
                            FlSpot(i.toDouble(), points[i].value),
                        ],
                        isCurved: true,
                        barWidth: 3,
                        color: color,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withValues(alpha: .12),
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
  const CategoryPieCard({
    super.key,
    required this.title,
    required this.values,
  });

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
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
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
                                    color: colors[i % colors.length],
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
