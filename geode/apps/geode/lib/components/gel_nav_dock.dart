import 'package:flutter/material.dart';
import '../theme/geode_theme.dart';
import '../three_d/dock_3d.dart';
import '../three_d/three_d_support.dart';
import 'gel_panel.dart';

class GelNavDock extends StatefulWidget {
  const GelNavDock({super.key, required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const labels = ['Visuals', 'Music', 'Studio', 'Settings'];
  static const icons = [
    Icons.blur_on_rounded,
    Icons.library_music_outlined,
    Icons.movie_outlined,
    Icons.settings_outlined,
  ];

  @override
  State<GelNavDock> createState() => _GelNavDockState();
}

class _GelNavDockState extends State<GelNavDock> {
  int? _pressed;

  void _press(int? index) {
    if (_pressed != index) setState(() => _pressed = index);
  }

  @override
  Widget build(BuildContext context) {
    // With 3D pebbles under the tabs, the selected tab lets its glowing pebble show through.
    final pebbles = threeDModeIn(context) != ThreeDMode.flat;
    return GelPanel(
      radius: 34,
      opacity: .72,
      blur: 22,
      padding: const EdgeInsets.all(6),
      child: Stack(children: [
        Positioned.fill(child: Dock3D(count: GelNavDock.labels.length,
          selected: widget.selectedIndex, pressed: _pressed)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(GelNavDock.labels.length, (index) {
            final active = index == widget.selectedIndex;
            return Expanded(
              child: Semantics(
                selected: active,
                label: '${GelNavDock.labels[index]} tab',
                child: Listener(
                  onPointerDown: (_) => _press(index),
                  onPointerUp: (_) => _press(null),
                  onPointerCancel: (_) => _press(null),
                  child: TextButton(
                    onPressed: () => widget.onChanged(index),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 63),
                      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 10),
                      foregroundColor: active ? GeodeTokens.accent : GeodeTokens.muted,
                      backgroundColor: active
                        ? (pebbles ? const Color(0x3D4D6240) : const Color(0xFF4D6240))
                        : Colors.transparent,
                      side: active ? const BorderSide(color: Color(0xFF8B9F69)) : BorderSide.none,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: ExcludeSemantics(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(GelNavDock.icons[index], size: 22, shadows: active || pebbles
                          ? const [Shadow(color: Color(0xCC0B1A10), blurRadius: 8)] : null),
                        const SizedBox(height: 5),
                        Text(GelNavDock.labels[index], textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                              shadows: pebbles ? const [Shadow(color: Color(0xE60B1A10), blurRadius: 6)] : null)),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ]),
    );
  }
}
