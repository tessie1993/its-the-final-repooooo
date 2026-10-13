import 'package:flutter/material.dart';
import '../theme/geode_theme.dart';

class GelIconButton extends StatelessWidget {
  const GelIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: const AssetImage('assets/images/fern-dew.png'),
              fit: BoxFit.contain,
              opacity: selected ? .8 : .5,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? const [Color(0xBBCAE7DD), Color(0xAA84B8BA)]
                  : const [Color(0x66587E8C), Color(0x5517313E)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: selected ? .5 : .25), width: .8),
            boxShadow: const [BoxShadow(color: Color(0x22000C16), blurRadius: 12, offset: Offset(0, 4))],
          ),
          child: IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            color: GeodeTokens.ink,
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.all(13),
            icon: Icon(icon, size: 21, shadows: const [Shadow(color: Color(0xFF082A35), blurRadius: 7)]),
          ),
        ),
      );
}
