# Geode (Flutter)

The Flutter rebuild of Geode: music player, high-end visualizer (C++) and export studio.
The original app's C++ engine, shaders and assets live in [`../geode`](../geode). The plan is in
[`../docs/blueprint`](../docs/blueprint), and [07-rebuild-plan.md](../docs/blueprint/07-rebuild-plan.md)
covers what is reused and what is rebuilt.

## Right now: a basic UI that walks the whole app

Every screen, tab, sheet and dialog of the original app is reachable. Each page says what it did in
the old app and what will power it in the rebuild. Nothing is wired to the engine yet.

```
lib/
├── main.dart              picks the UI kit (one line to change the whole look)
├── app/                   the app's structure, no widgets of its own
│   ├── spec/              the map of the app as data: destinations, pages, tabs, sheets, first run, tour
│   ├── router.dart        go_router built from the map (StatefulShellRoute for the 5 destinations)
│   ├── hosts.dart         connects app state to the kit (shell, onboarding)
│   ├── app_state.dart     first run, guided tour, who the app is for (Studio shown or hidden)
│   └── geode_app.dart     MaterialApp.router + provider
└── ui/
    ├── ui_kit.dart        the interface every skin implements
    └── basic/             the throwaway basic skin (stock Material)
```

### Changing the UI later

- **A new look for everything:** write `lib/ui/<name>/` implementing `GeodeUiKit`, then change
  `BasicUiKit()` in `main.dart`. Nothing under `lib/app/` changes.
- **A real screen for one page:** a kit can return a dedicated widget for a specific page id in
  `page()` and fall back to the generic page for the rest. Screens can be replaced one at a time.
- **Adding or moving a screen:** edit the map in `lib/app/spec/`. The route and navigation follow.

## Run

```bash
flutter pub get
flutter run            # Android device or emulator
flutter analyze
```

The Android host is Java (`MainActivity.java`); there is no Kotlin app code. The Gradle build
scripts are Flutter's standard Kotlin-DSL `.kts` files, which are build configuration, not app code.
