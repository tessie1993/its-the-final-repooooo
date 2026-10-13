/// The shape of the app, as plain data.
///
/// Nothing in this folder imports Flutter widgets. The router turns these specs into routes, and a
/// [GeodeUiKit](../../ui/ui_kit.dart) decides what they look like, so the whole UI can be replaced
/// without touching the map of what the app contains.
library;

/// How a page is presented.
enum PageKind {
  /// A full page inside its destination, keeping the navigation bar.
  screen,

  /// A page that covers the whole app, navigation bar included (the full-screen visualizer).
  fullscreen,

  /// A modal bottom sheet over the current page.
  sheet,

  /// A small modal dialog over the current page.
  dialog,
}

/// What a page puts in its large live area, if anything.
enum PageSurface {
  none,

  /// The C++ visualizer (geode_viz through the render host).
  visualizer,

  /// The Studio multi-lane timeline.
  timeline,

  /// The live spectrum on the Player.
  spectrum,
}

/// Something a page can trigger that changes app state rather than opening another page.
enum AppAction { replayTutorial, intentListening, intentVideos, intentBoth, restartOnboarding }

/// One button that runs an [AppAction].
class ActionSpec {
  const ActionSpec(this.action, this.label);

  final AppAction action;
  final String label;
}

/// One page of the app: a screen, a tab inside a screen, a sheet or a dialog.
///
/// Pages nest. [tabs] are shown inside this page; [children] are pages pushed from it;
/// [sheets] are modals opened over it. [features] says what the page does in the original Geode
/// and [poweredBy] what does the work in the rebuild, so the skeleton documents itself.
class PageSpec {
  const PageSpec({
    required this.id,
    required this.title,
    this.kind = PageKind.screen,
    this.summary = '',
    this.features = const [],
    this.poweredBy = const [],
    this.surface = PageSurface.none,
    this.tabs = const [],
    this.children = const [],
    this.sheets = const [],
    this.actions = const [],
  });

  /// URL segment for pushed pages; a stable key for tabs and sheets.
  final String id;
  final String title;
  final PageKind kind;
  final String summary;
  final List<String> features;
  final List<String> poweredBy;
  final PageSurface surface;
  final List<PageSpec> tabs;
  final List<PageSpec> children;
  final List<PageSpec> sheets;
  final List<ActionSpec> actions;

  bool get isModal => kind == PageKind.sheet || kind == PageKind.dialog;

  /// Every page pushed from here, including the ones pushed from inside its tabs.
  ///
  /// A tab is not a route of its own, so a page opened from a tab hangs off the screen that
  /// owns the tab.
  Iterable<PageSpec> get routedChildren sync* {
    yield* children;
    for (final tab in tabs) {
      yield* tab.routedChildren;
    }
  }
}

/// The top-level destinations, in navigation-bar order.
enum DestinationId { player, library, visuals, studio, settings }

/// One entry in the navigation bar and the page it opens.
class DestinationSpec {
  const DestinationSpec({required this.id, required this.page, this.videoMakersOnly = false});

  final DestinationId id;
  final PageSpec page;

  /// Hidden from the navigation when the person only listens (Settings › Behavior).
  final bool videoMakersOnly;

  String get path => '/${page.id}';
  String get title => page.title;
}

/// What the person uses Geode for. Decides whether Studio is in the navigation.
enum UserIntent {
  listening,
  makingVideos,
  both;

  bool get showsStudio => this != listening;
}

/// One step of the first-run flow, shown before the app itself.
class OnboardingStepSpec {
  const OnboardingStepSpec({
    required this.id,
    required this.title,
    required this.body,
    required this.primary,
    this.secondary,
    this.note = '',
  });

  final String id;
  final String title;
  final String body;
  final String primary;
  final String? secondary;
  final String note;
}

/// One stop of the guided tour, which navigates the real app.
class TutorialStepSpec {
  const TutorialStepSpec({
    required this.destination,
    required this.title,
    required this.body,
    this.videoMakersOnly = false,
  });

  final DestinationId destination;
  final String title;
  final String body;
  final bool videoMakersOnly;
}
