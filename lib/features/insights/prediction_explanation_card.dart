import 'package:flutter/material.dart';

class PredictionExplanationCard extends StatelessWidget {
  const PredictionExplanationCard({
    super.key,
    required this.stressRisk,
    required this.explanations,
  });

  final int stressRisk;
  final List<String> explanations;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline),
              const SizedBox(width: 8),
              Text(
                'Why your stress risk is $stressRisk/100',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...explanations.map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          ),
          const Text(
            'This explains the app inputs; it is not a medical diagnosis.',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
