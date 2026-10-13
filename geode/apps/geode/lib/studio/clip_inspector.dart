import 'package:flutter/material.dart';
import '../components/components.dart';
import 'clip_properties_dialog.dart';
import 'keyframe_editor.dart';
import 'studio_controller.dart';
import 'studio_dialogs.dart';
import '../three_d/asset_3d.dart';
import '../three_d/controls_3d.dart';

class ClipInspector extends StatelessWidget {
  const ClipInspector({super.key, required this.studio, required this.pausePreview});
  final StudioController studio;
  final VoidCallback pausePreview;

  void _edit(VoidCallback action) { pausePreview(); action(); }

  @override
  Widget build(BuildContext context) {
    final clip = studio.selectedClip;
    final text = Theme.of(context).textTheme;
    if (clip == null) {
      return GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: Asset3D.boxed(asset: Geode3DAsset.crystalFern, width: 130, height: 100, fallback: Image.asset('assets/images/crystal-fern.png', width: 130, height: 100,
        excludeFromSemantics: true, errorBuilder: (_, error, stack) => const Icon(Icons.spa_outlined, size: 58)))),
      Text('A little detail changes everything.', style: text.titleLarge),
      const SizedBox(height: 10),
      const Text('Select a clip to shape its timing and material. Add your first clip above.'),
      const SizedBox(height: 18),
      KeyframeEditor(studio: studio, pausePreview: pausePreview),
    ]));
    }
    final locked = studio.laneLocked(clip.lane);
    final transitionType = clip.transition['type'] as String? ?? 'none';
    final transitionDuration = (clip.transition['durationMs'] as num? ?? 800).toInt();
    final canSplit = !locked && studio.playheadMs - clip.startMs >= 33 && clip.endMs - studio.playheadMs >= 33;
    return GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${clip.lane.toUpperCase()} / CLIP', style: text.labelSmall),
      const SizedBox(height: 8),
      Text(clip.label, style: text.titleLarge, maxLines: 3, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 8),
      Text('${studioTime(clip.startMs)} → ${studioTime(clip.endMs)}', style: text.bodyMedium),
      if (locked) const Padding(padding: EdgeInsets.only(top: 8),
        child: Text('Lane locked · unlock in the timeline to edit.')),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton.icon(onPressed: locked ? null : () {
          pausePreview(); showDialog<void>(context: context,
            builder: (_) => ClipPropertiesDialog(studio: studio, clip: clip));
        }, icon: const Icon(Icons.tune_rounded, size: 18), label: const Text('Timing & text')),
        OutlinedButton.icon(onPressed: canSplit ? () => _edit(studio.splitClip) : null,
          icon: const Icon(Icons.content_cut_rounded, size: 18), label: const Text('Split')),
        OutlinedButton(onPressed: !locked && studio.playheadMs > clip.startMs &&
          studio.playheadMs <= clip.endMs - 33 ? () => _edit(studio.trimStart) : null,
          child: const Text('Trim start here')),
        OutlinedButton(onPressed: !locked && studio.playheadMs >= clip.startMs + 33 &&
          studio.playheadMs < clip.endMs ? () => _edit(studio.trimEnd) : null,
          child: const Text('Trim end here')),
        IconButton(tooltip: 'Duplicate clip', onPressed: locked ? null : () => _edit(studio.duplicateClip),
          icon: const Icon(Icons.copy_all_rounded)),
        IconButton(tooltip: 'Delete clip', onPressed: locked ? null : () => _edit(studio.deleteClip),
          icon: const Icon(Icons.delete_outline_rounded)),
      ]),
      SwitchTile3D(contentPadding: EdgeInsets.zero, title: const Text('Clip enabled'),
        value: clip.enabled, onChanged: locked ? null : (value) => _edit(() => studio.updateClip(enabled: value))),
      if (clip.lane == 'visual') ...[
        const SizedBox(height: 8),
        Text('Material', style: text.titleSmall),
        const SizedBox(height: 12),
        IgnorePointer(ignoring: locked, child: Opacity(opacity: locked ? .4 : 1,
          child: GelMaterialPicker(selectedIndex: clip.materialIndex,
            onChanged: (value) => _edit(() => studio.updateClip(materialIndex: value))))),
      ],
      if (clip.source != null) Padding(padding: const EdgeInsets.only(top: 12),
        child: SelectableText('Source: ${clip.source}', maxLines: 2, style: text.bodySmall)),
      const SizedBox(height: 18),
      DropdownButtonFormField<String>(key: ValueKey('${clip.id}-$transitionType'),
        initialValue: transitionType, decoration: const InputDecoration(labelText: 'Opening transition'),
        items: const [DropdownMenuItem(value: 'none', child: Text('None')),
          DropdownMenuItem(value: 'dissolve', child: Text('Dissolve')),
          DropdownMenuItem(value: 'fade', child: Text('Fade')),
          DropdownMenuItem(value: 'wipe', child: Text('Wipe'))],
        onChanged: locked || clip.durationMs < 100 ? null : (value) => _edit(() =>
          studio.setTransition(value!, transitionDuration > 0 ? transitionDuration : 800))),
      if (transitionType != 'none') ...[
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: [400, 800, 1500, 3000].map((ms) => ChoiceChip(
          label: Text('${ms / 1000}s'), selected: transitionDuration == ms,
          onSelected: locked || ms > clip.durationMs ? null
            : (_) => _edit(() => studio.setTransition(transitionType, ms)),
        )).toList()),
        const SizedBox(height: 8),
        Text('Transition settings are saved. Native transition rendering is not connected.', style: text.bodySmall),
      ],
      const Divider(height: 32),
      KeyframeEditor(studio: studio, pausePreview: pausePreview),
    ]));
  }
}
