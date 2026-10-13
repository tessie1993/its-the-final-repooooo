import 'package:flutter/material.dart';

import '../ui_kit.dart';

class BasicOnboarding extends StatelessWidget {
  const BasicOnboarding({super.key, required this.model});

  final OnboardingModel model;

  @override
  Widget build(BuildContext context) {
    final step = model.step;
    final text = Theme.of(context).textTheme;
    final secondary = step.secondary;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text('${model.index + 1} / ${model.total}', style: text.labelMedium),
            const SizedBox(height: 32),
            Text(step.title, style: text.headlineMedium),
            const SizedBox(height: 16),
            Text(step.body, style: text.bodyLarge),
            if (step.note.isNotEmpty) ...[const SizedBox(height: 16), Text(step.note, style: text.bodySmall)],
            const SizedBox(height: 32),
            FilledButton(onPressed: model.onPrimary, child: Text(step.primary)),
            if (secondary != null) TextButton(onPressed: model.onSecondary, child: Text(secondary)),
          ],
        ),
      ),
    );
  }
}
