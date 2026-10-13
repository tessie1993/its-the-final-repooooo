import 'package:flutter/material.dart';
import '../three_d/depth_3d.dart';
import '../theme/geode_theme.dart';
import 'gel_panel.dart';

class GelIconButton extends StatelessWidget {
  const GelIconButton({super.key, required this.icon, required this.tooltip,
    required this.onPressed, this.selected = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(selected: selected,
    child: Depth3D(enabled: onPressed != null, radius: 30, maxTilt: .22, sink: .06, child: GelPanel(radius: 30, opacity: selected ? .85 : .55, blur: 6,
      highlighted: selected, pearl: selected, padding: EdgeInsets.zero,
      child: Material(color: Colors.transparent,
        child: IconButton(tooltip: tooltip, onPressed: onPressed,
          color: selected ? GeodeTokens.accent : GeodeTokens.ink,
          disabledColor: GeodeTokens.muted.withValues(alpha: .4),
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: const EdgeInsets.all(13),
          style: IconButton.styleFrom(shape: const CircleBorder()),
          icon: Icon(icon, size: 21, shadows: const [
            Shadow(color: Color(0x5540502D), blurRadius: 12),
            Shadow(color: Color(0xFF122416), blurRadius: 3),
          ]),
        ),
      ),
    )),
  );
}
