import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../ui/ui_kit.dart';
import 'app_state.dart';
import 'hosts.dart';
import 'spec/app_map.dart';

const welcomePath = '/welcome';
const searchPath = '/search';

/// Builds the router from the app map. Every page in [destinations] gets a route; the UI kit
/// draws it.
GoRouter buildRouter({required AppState state, required GeodeUiKit ui}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  PageModel modelFor(BuildContext context, PageSpec spec, String path, {bool destination = false}) {
    late final PageModel model;
    model = PageModel(
      spec: spec,
      openChild: (child) => context.push('$path/${child.id}'),
      openModal: (modal) => ui.showModal(context, model.forSpec(modal)),
      runAction: state.run,
      onSearch: destination ? () => context.push(searchPath) : null,
    );
    return model;
  }

  List<RouteBase> childRoutes(PageSpec spec, String path) => [
    for (final child in spec.routedChildren)
      GoRoute(
        path: child.id,
        parentNavigatorKey: child.kind == PageKind.fullscreen ? rootKey : null,
        builder: (context, _) => ui.page(context, modelFor(context, child, '$path/${child.id}')),
        routes: childRoutes(child, '$path/${child.id}'),
      ),
  ];

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: destinations.first.path,
    refreshListenable: state,
    redirect: (context, routerState) {
      final location = routerState.matchedLocation;
      final welcoming = location == welcomePath;
      if (!state.onboarded) return welcoming ? null : welcomePath;
      if (welcoming) return state.landingDestination.path;
      final studio = destinationOf(DestinationId.studio).path;
      if (!state.intent.showsStudio && location.startsWith(studio)) {
        return destinations.first.path;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: welcomePath,
        builder: (context, _) => OnboardingHost(ui: ui),
      ),
      GoRoute(
        path: searchPath,
        builder: (context, _) => ui.page(context, modelFor(context, searchPage, searchPath)),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, _, navigationShell) => ShellHost(ui: ui, navigationShell: navigationShell),
        branches: [
          for (final d in destinations)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: d.path,
                  builder: (context, _) =>
                      ui.page(context, modelFor(context, d.page, d.path, destination: true)),
                  routes: childRoutes(d.page, d.path),
                ),
              ],
            ),
        ],
      ),
    ],
  );
}

/// Every routable page and its path: the destinations, everything pushed from them, and search.
List<(String, PageSpec)> allRoutes() {
  final out = <(String, PageSpec)>[];
  void walk(PageSpec spec, String path) {
    out.add((path, spec));
    for (final child in spec.routedChildren) {
      walk(child, '$path/${child.id}');
    }
  }

  for (final d in destinations) {
    walk(d.page, d.path);
  }
  out.add((searchPath, searchPage));
  return out;
}
