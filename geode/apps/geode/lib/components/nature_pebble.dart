import 'package:flutter/material.dart';
import '../theme/geode_theme.dart';
import 'material_orb.dart';

/// A photographic moss-and-glass pebble floating free of a rectangular card.
class NaturePebble extends StatelessWidget {
  const NaturePebble({
    super.key,
    required this.label,
    this.onPressed,
    this.width = 240,
    this.height = 92,
  });

  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: Image.asset(
                'assets/images/nature-pebble.png',
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (_, error, trace) => const Center(child: MaterialOrb(size: 100)),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 25),
                child: Material(
                  type: MaterialType.transparency,
                  child: TextButton(
                    onPressed: onPressed,
                    style: TextButton.styleFrom(
                      foregroundColor: GeodeTokens.ink,
                      disabledForegroundColor: GeodeTokens.ink,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    child: Text(label, textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            shadows: [Shadow(color: Color(0xFF06222D), blurRadius: 8), Shadow(color: Color(0xCC06222D), blurRadius: 4)])),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
