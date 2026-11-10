import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final bool large;
  final IconData? icon;
  final CrossAxisAlignment align;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.large = false,
    this.icon,
    this.align = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Text(label.toUpperCase(), style: t.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style: (large ? t.displayLarge?.copyWith(fontSize: 72, height: 1) : t.headlineSmall)
                    ?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabular)),
            if (unit != null) ...[
              const SizedBox(width: 3),
              Text(unit!, style: t.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ],
    );
  }
}

/// Carte arrondie contenant une statistique (grille du détail d'une course).
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color? accent;

  const StatCard({super.key, required this.label, required this.value, this.unit, required this.icon, this.accent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final color = accent ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: t.labelMedium?.copyWith(color: scheme.onSurfaceVariant), maxLines: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabular)),
                  if (unit != null) ...[
                    const SizedBox(width: 3),
                    Text(unit!, style: t.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
