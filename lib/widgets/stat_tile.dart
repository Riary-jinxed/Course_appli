import 'package:flutter/material.dart';

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool large;

  const StatTile({super.key, required this.label, required this.value, this.unit, this.large = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: t.labelMedium?.copyWith(color: Theme.of(context).colorScheme.outline)),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: (large ? t.displayMedium : t.headlineSmall)
                    ?.copyWith(fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()])),
            if (unit != null) ...[
              const SizedBox(width: 4),
              Text(unit!, style: t.bodyMedium),
            ],
          ],
        ),
      ],
    );
  }
}
