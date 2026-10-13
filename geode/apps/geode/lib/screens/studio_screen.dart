import 'package:flutter/material.dart';
import '../state/geode_app_state.dart';
import '../studio/project_browser.dart';
import '../studio/studio_editor.dart';

class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key, required this.state});
  final GeodeAppState state;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: state.studio,
    builder: (context, _) {
      final studio = state.studio;
      if (!studio.initialized) {
        return const Center(child: CircularProgressIndicator());
      }
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (studio.error != null) Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: MaterialBanner(
                content: Text(studio.error!),
                actions: [
                  TextButton(onPressed: studio.clearError, child: const Text('Dismiss')),
                  if (!studio.storageReady || studio.error!.contains('saved'))
                    TextButton(onPressed: studio.initialize, child: const Text('Retry storage')),
                ],
              ),
            ),
            if (studio.selectedProject == null)
              ProjectBrowser(state: state)
            else
              StudioEditor(key: ValueKey(studio.selectedProject!.id), state: state),
          ]),
        )),
      );
    },
  );
}
