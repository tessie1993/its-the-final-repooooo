import 'package:flutter/material.dart';

import '../ui_kit.dart';
import 'basic_icons.dart';

/// Navigation bar, a mini player off the Player tab, and the guided-tour card.
class BasicShell extends StatelessWidget {
  const BasicShell({super.key, required this.model});

  final ShellModel model;

  @override
  Widget build(BuildContext context) {
    final tutorial = model.tutorial;
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: model.body),
          if (tutorial != null) _TutorialCard(model: tutorial),
          if (model.showMiniPlayer && tutorial == null) _MiniPlayer(onTap: model.onOpenPlayer),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: model.selectedIndex,
        onDestinationSelected: model.onSelect,
        destinations: [
          for (final d in model.destinations)
            NavigationDestination(icon: Icon(destinationIcon(d.id)), label: d.title),
        ],
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ListTile(
        key: const Key('mini-player'),
        leading: const Icon(Icons.music_note),
        title: const Text('Nothing playing'),
        subtitle: const Text('Mini player — tap for the Player'),
        trailing: const Icon(Icons.play_arrow),
        onTap: onTap,
      ),
    );
  }
}

class _TutorialCard extends StatelessWidget {
  const _TutorialCard({required this.model});

  final TutorialModel model;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: const Key('tutorial-card'),
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${model.index + 1} of ${model.total}', style: text.labelSmall),
            const SizedBox(height: 4),
            Text(model.step.title, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(model.step.body, style: text.bodyMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(onPressed: model.onSkip, child: const Text('Skip')),
                const Spacer(),
                if (model.index > 0) TextButton(onPressed: model.onBack, child: const Text('Back')),
                FilledButton(onPressed: model.onNext, child: Text(model.isLast ? 'Got it' : 'Next')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
