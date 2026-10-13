import 'package:flutter/material.dart';

import '../../app/spec/app_map.dart';
import '../ui_kit.dart';
import 'basic_onboarding.dart';
import 'basic_page.dart';
import 'basic_shell.dart';

/// A deliberately plain skin: stock Material widgets, no theme packs, no art.
///
/// It exists to walk the whole app while the engine and features are rebuilt. Replace it by
/// writing another [GeodeUiKit]; nothing outside `ui/basic/` depends on this folder.
class BasicUiKit implements GeodeUiKit {
  const BasicUiKit();

  @override
  ThemeData theme() => ThemeData(colorSchemeSeed: const Color(0xFF8E5BD8), brightness: Brightness.dark);

  @override
  Widget shell(BuildContext context, ShellModel model) => BasicShell(model: model);

  @override
  Widget page(BuildContext context, PageModel model) => BasicPage(model: model);

  @override
  Widget onboarding(BuildContext context, OnboardingModel model) => BasicOnboarding(model: model);

  @override
  Future<void> showModal(BuildContext context, PageModel model) {
    if (model.spec.kind == PageKind.dialog) {
      return showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(model.spec.title),
          content: SizedBox(
            width: double.maxFinite,
            child: BasicPageBody(model: model, shrinkWrap: true),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
        ),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(model.spec.title, style: Theme.of(context).textTheme.titleLarge),
            ),
            Expanded(child: BasicPageBody(model: model)),
          ],
        ),
      ),
    );
  }
}
