import 'package:flutter/material.dart';
import '../theme/geode_theme.dart';
import '../three_d/depth_3d.dart';
import 'gel_panel.dart';

class GelButton extends StatelessWidget {
  const GelButton({super.key, required this.label, required this.onPressed,
    this.icon, this.primary = true});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Depth3D(
      enabled: enabled,
      radius: primary ? 32 : 24,
      maxTilt: primary ? .12 : .16,
      child: GelPanel(radius: primary ? 32 : 24, blur: 8,
        opacity: enabled ? (primary ? .80 : .48) : .25,
        highlighted: primary && enabled, pearl: primary,
        padding: EdgeInsets.zero,
        child: Material(color: Colors.transparent,
          child: TextButton(onPressed: onPressed,
            style: TextButton.styleFrom(
              minimumSize: Size(primary ? 120 : 48, primary ? 62 : 52),
              padding: EdgeInsets.symmetric(horizontal: primary ? 24 : 18, vertical: 14),
              foregroundColor: GeodeTokens.ink,
              disabledForegroundColor: GeodeTokens.muted.withValues(alpha: .5),
              textStyle: Theme.of(context).textTheme.labelLarge,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 9)],
              Flexible(child: Text(label, textAlign: TextAlign.center,
                style: const TextStyle(shadows: [Shadow(color: Color(0x80022335), blurRadius: 6)]))),
            ]),
          ),
        ),
      ),
    );
  }
}
