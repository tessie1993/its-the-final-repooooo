import 'library_map.dart';
import 'page_spec.dart';
import 'player_map.dart';
import 'settings_map.dart';
import 'studio_map.dart';
import 'visuals_map.dart';

export 'onboarding_map.dart';
export 'page_spec.dart';
export 'player_map.dart' show searchPage;

/// The whole app: every destination in navigation-bar order.
///
/// Add a screen here and it gets a route, a place in the navigation and a test that visits it.
const destinations = [
  DestinationSpec(id: DestinationId.player, page: playerPage),
  DestinationSpec(id: DestinationId.library, page: libraryPage),
  DestinationSpec(id: DestinationId.visuals, page: visualsPage),
  DestinationSpec(id: DestinationId.studio, page: studioPage, videoMakersOnly: true),
  DestinationSpec(id: DestinationId.settings, page: settingsPage),
];

DestinationSpec destinationOf(DestinationId id) => destinations.firstWhere((d) => d.id == id);
