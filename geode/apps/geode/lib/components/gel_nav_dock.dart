import 'package:flutter/material.dart';
import '../theme/geode_theme.dart';
import 'gel_panel.dart';

class GelNavDock extends StatelessWidget {
  const GelNavDock({super.key, required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const labels = ['Visuals', 'Library', 'Studio', 'Settings'];
  static const icons = [
    Icons.blur_on_rounded,
    Icons.grid_view_rounded,
    Icons.tune_rounded,
    Icons.settings_outlined,
  ];

  @override
  Widget build(BuildContext context) => GelPanel(
        radius: 27,
        opacity: .84,
        blur: 22,
        padding: const EdgeInsets.all(6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(labels.length, (index) {
            final active = index == selectedIndex;
            return Expanded(
              child: Semantics(
                selected: active,
                label: '${labels[index]} tab',
                child: TextButton(
                  onPressed: () => onChanged(index),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 63),
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                    foregroundColor: active ? GeodeTokens.accent : GeodeTokens.muted,
                    backgroundColor: active ? const Color(0x1FDBF6ED) : Colors.transparent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: ExcludeSemantics(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icons[index], size: 22),
                      const SizedBox(height: 5),
                      Text(labels[index], textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
                    ]),
                  ),
                ),
              ),
            );
          }),
        ),
      );
}
