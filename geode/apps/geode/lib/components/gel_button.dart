import 'package:flutter/material.dart';
import '../theme/geode_theme.dart';
import 'gel_panel.dart';

class GelButton extends StatefulWidget {
  const GelButton({super.key, required this.label, required this.onPressed,
    this.icon, this.primary = true});
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
    final enabled = widget.onPressed != null;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return AnimatedContainer(
      duration: reduced ? Duration.zero : const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      transformAlignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .001)
        ..setEntry(1, 3, _pressed && enabled && !reduced ? 2 : 0)
        ..rotateX(_pressed && enabled && !reduced ? -.035 : 0),
      child: Listener(
        onPointerDown: (_) { if (enabled) setState(() => _pressed = true); },
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: GelPanel(radius: widget.primary ? 32 : 24, blur: 8,
          opacity: enabled ? (widget.primary ? .80 : .48) : .25,
          highlighted: widget.primary && enabled, pearl: widget.primary,
          padding: EdgeInsets.zero,
          child: Material(color: Colors.transparent,
            child: TextButton(onPressed: widget.onPressed,
              style: TextButton.styleFrom(
                minimumSize: Size(widget.primary ? 120 : 48, widget.primary ? 62 : 52),
                padding: EdgeInsets.symmetric(horizontal: widget.primary ? 24 : 18, vertical: 14),
                foregroundColor: GeodeTokens.ink,
                disabledForegroundColor: GeodeTokens.muted.withValues(alpha: .5),
                textStyle: Theme.of(context).textTheme.labelLarge,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
                if (widget.icon != null) ...[Icon(widget.icon, size: 20), const SizedBox(width: 9)],
                Flexible(child: Text(widget.label, textAlign: TextAlign.center,
                  style: const TextStyle(shadows: [Shadow(color: Color(0x80022335), blurRadius: 6)]))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
