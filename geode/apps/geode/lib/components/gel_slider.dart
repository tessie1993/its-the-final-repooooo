import 'package:flutter/material.dart';
import '../theme/geode_theme.dart';

class GelSlider extends StatelessWidget {
  const GelSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.description,
  });

  final String label;
  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final normalized = value.clamp(0.0, 1.0).toDouble();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleSmall)),
            const SizedBox(width: 12),
            Text('${(normalized * 100).round()}%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: GeodeTokens.accent)),
          ],
        ),
        Semantics(
          label: label,
          // A bounded height: Slider ignores minHeight when its height is unbounded and
          // sizes itself below the 48 dp touch target, failing layout.
          child: SizedBox(
            height: 48,
            child: Slider(
              value: normalized,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
              semanticFormatterCallback: (v) => '${(v * 100).round()} percent',
            ),
          ),
        ),
        if (description != null)
          Text(description!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
