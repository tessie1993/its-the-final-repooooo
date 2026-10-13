import 'package:flutter/material.dart';
import '../theme/geode_theme.dart';

class GelButton extends StatefulWidget {
  const GelButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;

  @override
  State<GelButton> createState() => _GelButtonState();
}

class _GelButtonState extends State<GelButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final enabled = widget.onPressed != null;
    return AnimatedScale(
      scale: _pressed && enabled && !reducedMotion ? .97 : 1,
      duration: reducedMotion ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  image: widget.primary
                      ? DecorationImage(
                          image: const AssetImage('assets/images/nature-pebble.png'),
                          fit: BoxFit.fill,
                          opacity: enabled ? 1 : .45,
                        )
                      : null,
                  gradient: widget.primary ? null : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: !enabled
                        ? const [Color(0xFF30464C), Color(0xFF21373E)]
                        : const [Color(0x75497583), Color(0x59214350)],
                  ),
                  border: widget.primary ? null : Border.all(color: Colors.white.withValues(alpha: .23), width: .9),
                ),
                child: TextButton(
                  onPressed: widget.onPressed,
                  style: TextButton.styleFrom(
                    minimumSize: Size(widget.primary ? 160 : 48, widget.primary ? 72 : 54),
                    padding: EdgeInsets.symmetric(horizontal: widget.primary ? 32 : 22, vertical: 16),
                    foregroundColor: GeodeTokens.ink,
                    disabledForegroundColor: GeodeTokens.muted,
                    textStyle: Theme.of(context).textTheme.labelLarge,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 19),
                        const SizedBox(width: 9),
                      ],
                      Flexible(child: Text(widget.label, textAlign: TextAlign.center,
                          style: widget.primary ? const TextStyle(shadows: [Shadow(color: Color(0xFF04232B), blurRadius: 8)]) : null)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
