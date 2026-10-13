import 'package:flutter/material.dart';
import '../theme/geode_theme.dart';
import 'material_orb.dart';

class GelMaterialPicker extends StatelessWidget {
  const GelMaterialPicker({super.key, required this.selectedIndex, required this.onChanged});
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  static const names = ['Water', 'Opal', 'Mercury'];

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(names.length, (index) {
          final active = selectedIndex == index;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: index == names.length - 1 ? 0 : 8),
              child: Semantics(
                selected: active,
                label: '${names[index]} material',
                child: TextButton(
                  onPressed: () => onChanged(index),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 92),
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 12),
                    foregroundColor: active ? GeodeTokens.ink : GeodeTokens.muted,
                    backgroundColor: active ? const Color(0x294FA0BA) : const Color(0x11071625),
                    side: BorderSide(color: active ? const Color(0x998EC7D8) : const Color(0x20BCDFE9), width: .8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                  ),
                  child: ExcludeSemantics(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      MaterialOrb(materialIndex: index, size: 38),
                      const SizedBox(height: 7),
                      Text(names[index], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 6),
                      Container(
                        height: 3,
                        width: active ? 15 : 3,
                        decoration: BoxDecoration(
                          color: active ? GeodeTokens.accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          );
        }),
      );
}
