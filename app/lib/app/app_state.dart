import 'package:flutter/foundation.dart';

import 'spec/app_map.dart';

/// App-wide state the navigation depends on: first run, the guided tour, and whether Studio is
/// shown. Held in memory for now; persistence arrives with the data layer.
class AppState extends ChangeNotifier {
  AppState({bool onboarded = false, this._intent = UserIntent.both})
    : _onboardingIndex = onboarded ? onboardingSteps.length : 0;

  int _onboardingIndex;
  UserIntent _intent;
  int? _tutorialIndex;

  // ---- first run ----------------------------------------------------------------------------

  bool get onboarded => _onboardingIndex >= onboardingSteps.length;

  OnboardingStepSpec? get onboardingStep => onboarded ? null : onboardingSteps[_onboardingIndex];

  /// Moves to the next first-run step; finishing the last one starts the tour.
  void advanceOnboarding() {
    if (onboarded) return;
    _onboardingIndex++;
    if (onboarded) _tutorialIndex = 0;
    notifyListeners();
  }

  void restartOnboarding() {
    _onboardingIndex = 0;
    _tutorialIndex = null;
    notifyListeners();
  }

  // ---- who the app is for -------------------------------------------------------------------

  UserIntent get intent => _intent;

  void setIntent(UserIntent intent) {
    if (intent == _intent) return;
    _intent = intent;
    notifyListeners();
  }

  /// Where the app opens after first run: Studio for video makers, the Player for everyone else.
  DestinationSpec get landingDestination =>
      destinationOf(_intent == UserIntent.makingVideos ? DestinationId.studio : DestinationId.player);

  /// Destinations in the navigation bar, Studio left out for people who only listen.
  List<DestinationSpec> get visibleDestinations => [
    for (final d in destinations)
      if (!d.videoMakersOnly || _intent.showsStudio) d,
  ];

  // ---- guided tour --------------------------------------------------------------------------

  List<TutorialStepSpec> get tutorialSteps => [
    for (final s in tutorialStepsAll)
      if (!s.videoMakersOnly || _intent.showsStudio) s,
  ];

  TutorialStepSpec? get tutorialStep {
    final i = _tutorialIndex;
    return i == null ? null : tutorialSteps[i];
  }

  int? get tutorialIndex => _tutorialIndex;

  void startTutorial() {
    _tutorialIndex = 0;
    notifyListeners();
  }

  void nextTutorialStep() {
    final i = _tutorialIndex;
    if (i == null) return;
    _tutorialIndex = i + 1 < tutorialSteps.length ? i + 1 : null;
    notifyListeners();
  }

  void previousTutorialStep() {
    final i = _tutorialIndex;
    if (i == null || i == 0) return;
    _tutorialIndex = i - 1;
    notifyListeners();
  }

  void endTutorial() {
    _tutorialIndex = null;
    notifyListeners();
  }

  // ---- actions from pages -------------------------------------------------------------------

  void run(AppAction action) {
    switch (action) {
      case AppAction.replayTutorial:
        startTutorial();
      case AppAction.intentListening:
        setIntent(UserIntent.listening);
      case AppAction.intentVideos:
        setIntent(UserIntent.makingVideos);
      case AppAction.intentBoth:
        setIntent(UserIntent.both);
      case AppAction.restartOnboarding:
        restartOnboarding();
    }
  }
}
