import 'package:flutter/material.dart';

import '../app/spec/app_map.dart';

/// Everything the app needs from a UI skin.
///
/// The router and app state never build widgets themselves; they hand these models to a kit.
/// To restyle the whole app, write another implementation (for example `ui/stone/`) and pass it
/// to `GeodeApp` in `main.dart`. Nothing under `app/` changes.
abstract interface class GeodeUiKit {
  ThemeData theme();

  /// The frame around the destinations: navigation, mini player, the guided tour.
  Widget shell(BuildContext context, ShellModel model);

  /// Any page from the app map: a destination, a pushed page, or a full-screen page.
  Widget page(BuildContext context, PageModel model);

  /// A sheet or dialog from the app map, shown over the current page.
  Future<void> showModal(BuildContext context, PageModel model);

  /// One step of the first-run flow.
  Widget onboarding(BuildContext context, OnboardingModel model);
}

/// What a page can show and do.
class PageModel {
  const PageModel({
    required this.spec,
    required this.openChild,
    required this.openModal,
    required this.runAction,
    this.onSearch,
  });

  final PageSpec spec;

  /// Push one of the pages in [PageSpec.routedChildren].
  final void Function(PageSpec child) openChild;

  /// Show one of the sheets or dialogs in [PageSpec.sheets] (also those of its tabs).
  final void Function(PageSpec modal) openModal;

  final void Function(AppAction action) runAction;

  /// Set on destination pages: opens search.
  final VoidCallback? onSearch;

  /// The same callbacks for a tab or modal inside this page.
  PageModel forSpec(PageSpec other) =>
      PageModel(spec: other, openChild: openChild, openModal: openModal, runAction: runAction);
}

class ShellModel {
  const ShellModel({
    required this.destinations,
    required this.selectedIndex,
    required this.onSelect,
    required this.body,
    required this.showMiniPlayer,
    required this.onOpenPlayer,
    this.tutorial,
  });

  /// The destinations in the navigation, in order.
  final List<DestinationSpec> destinations;

  /// Index into [destinations].
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final Widget body;
  final bool showMiniPlayer;
  final VoidCallback onOpenPlayer;

  /// Set while the guided tour runs.
  final TutorialModel? tutorial;
}

class TutorialModel {
  const TutorialModel({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final TutorialStepSpec step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  bool get isLast => index == total - 1;
}

class OnboardingModel {
  const OnboardingModel({
    required this.step,
    required this.index,
    required this.total,
    required this.onPrimary,
    required this.onSecondary,
  });

  final OnboardingStepSpec step;
  final int index;
  final int total;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
}
