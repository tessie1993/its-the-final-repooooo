import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../ui/ui_kit.dart';
import 'app_state.dart';
import 'spec/app_map.dart';

/// Connects the first-run flow in [AppState] to the kit's onboarding page.
class OnboardingHost extends StatelessWidget {
  const OnboardingHost({super.key, required this.ui});

  final GeodeUiKit ui;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final step = state.onboardingStep;
    if (step == null) return const SizedBox.shrink();
    return ui.onboarding(
      context,
      OnboardingModel(
        step: step,
        index: onboardingSteps.indexOf(step),
        total: onboardingSteps.length,
        onPrimary: state.advanceOnboarding,
        onSecondary: state.advanceOnboarding,
      ),
    );
  }
}

/// Connects the navigation shell to the kit: which destinations are visible, which one is
/// selected, and the guided tour, which moves between destinations as it advances.
class ShellHost extends StatefulWidget {
  const ShellHost({super.key, required this.ui, required this.navigationShell});

  final GeodeUiKit ui;
  final StatefulNavigationShell navigationShell;

  @override
  State<ShellHost> createState() => _ShellHostState();
}

class _ShellHostState extends State<ShellHost> {
  /// Branch indices follow [destinations]; the bar may hide some of them.
  void _goTo(DestinationId id) {
    final branch = destinations.indexWhere((d) => d.id == id);
    final shell = widget.navigationShell;
    shell.goBranch(branch, initialLocation: branch == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final shell = widget.navigationShell;
    final current = destinations[shell.currentIndex];
    final visible = state.visibleDestinations;
    final selected = visible.indexWhere((d) => d.id == current.id);

    final step = state.tutorialStep;
    if (step != null && step.destination != current.id) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _goTo(step.destination);
      });
    }

    return widget.ui.shell(
      context,
      ShellModel(
        destinations: visible,
        selectedIndex: selected < 0 ? 0 : selected,
        onSelect: (i) => _goTo(visible[i].id),
        body: shell,
        showMiniPlayer: current.id != DestinationId.player,
        onOpenPlayer: () => _goTo(DestinationId.player),
        tutorial: step == null
            ? null
            : TutorialModel(
                step: step,
                index: state.tutorialIndex!,
                total: state.tutorialSteps.length,
                onNext: state.nextTutorialStep,
                onBack: state.previousTutorialStep,
                onSkip: state.endTutorial,
              ),
      ),
    );
  }
}
