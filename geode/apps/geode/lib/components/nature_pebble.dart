import 'package:flutter/material.dart';
import '../theme/geode_theme.dart';
import 'fern_sprig.dart';
import 'gel_panel.dart';

/// A solid mossy stone button with a botanical edge.
class NaturePebble extends StatelessWidget {
  const NaturePebble({super.key, required this.label, this.onPressed,
    this.width = 240, this.height = 92});
  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) => SizedBox(width: width, height: height,
    child: GelPanel(radius: 44, pearl: true, padding: EdgeInsets.zero,
      child: Stack(alignment: Alignment.center, children: [
        const Positioned(left: 3, bottom: 1, child: IgnorePointer(child: FernSprig(size: 68))),
        Material(type: MaterialType.transparency,
          child: TextButton(onPressed: onPressed,
            style: TextButton.styleFrom(foregroundColor: GeodeTokens.ink,
              minimumSize: Size(width, height), padding: const EdgeInsets.fromLTRB(52, 14, 20, 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(44))),
            child: Text(label, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
        ),
      ]),
    ),
  );
}
