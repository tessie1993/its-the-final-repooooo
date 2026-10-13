import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../components/components.dart';
import 'studio_controller.dart';
import 'studio_dialogs.dart';

const uiStudioLanes = ['visual', 'media', 'text', 'overlay', 'audio'];
const studioLaneNames = ['Visual', 'Media', 'Text', 'Overlay', 'Audio'];
const studioLaneIcons = [Icons.water_drop_outlined, Icons.movie_outlined,
  Icons.text_fields_rounded, Icons.layers_outlined, Icons.music_note_rounded];
const studioLaneColors = [Color(0xFF8ECDBC), Color(0xFF82B6D5), Color(0xFFDCC5A4),
  Color(0xFFC6AFE0), Color(0xFFA1C997)];

class StudioTimeline extends StatefulWidget {
  const StudioTimeline({super.key, required this.studio, required this.pausePreview});
  final StudioController studio;
  final VoidCallback pausePreview;
  @override
  State<StudioTimeline> createState() => _StudioTimelineState();
}

class _StudioTimelineState extends State<StudioTimeline> {
  double zoom = 1;
  @override
  Widget build(BuildContext context) {
    final studio = widget.studio;
    final project = studio.selectedProject!;
    final duration = math.max(10000, project.durationMs);
    final laneHeight = 94.0 + math.max(0.0, MediaQuery.textScalerOf(context).scale(1) - 1) * 44;
    return GelPanel(padding: const EdgeInsets.all(14), child: Column(children: [
      Row(children: [
        Expanded(child: Text('Your timeline', style: Theme.of(context).textTheme.titleLarge)),
        IconButton(tooltip: 'Zoom out', onPressed: zoom <= 1 ? null
          : () => setState(() => zoom = (zoom - .5).clamp(1.0, 4.0).toDouble()),
          icon: const Icon(Icons.zoom_out_rounded)),
        Text('${zoom.toStringAsFixed(1)}×'),
        IconButton(tooltip: 'Zoom in', onPressed: zoom >= 4 ? null
          : () => setState(() => zoom = (zoom + .5).clamp(1.0, 4.0).toDouble()),
          icon: const Icon(Icons.zoom_in_rounded)),
      ]),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (context, box) {
        final width = math.max(660.0, box.maxWidth - 136) * zoom;
        return SingleChildScrollView(scrollDirection: Axis.horizontal, child: SizedBox(
          width: width + 136,
          child: Column(children: [
            Row(children: [const SizedBox(width: 136), SizedBox(width: width, height: 30,
              child: Stack(children: List.generate(6, (i) => Positioned(
                left: (width - 58) * i / 5, child: Text(studioTime(duration * i ~/ 5),
                  style: Theme.of(context).textTheme.labelSmall)))))]),
            ...List.generate(uiStudioLanes.length, (index) {
              final lane = uiStudioLanes[index];
              final color = studioLaneColors[index];
              final clips = project.clips.where((clip) => clip.lane == lane).toList();
              return SizedBox(height: laneHeight + 10, child: Row(children: [
                SizedBox(width: 136, child: Padding(padding: const EdgeInsets.only(right: 10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 8),
                    Row(children: [Icon(studioLaneIcons[index], size: 16, color: color),
                      const SizedBox(width: 8), Text(studioLaneNames[index])]),
                    Row(children: [
                      IconButton(tooltip: studio.laneMuted(lane) ? 'Unmute lane' : 'Mute lane',
                        onPressed: () => studio.toggleLaneMute(lane),
                        icon: Icon(studio.laneMuted(lane) ? Icons.volume_off_rounded : Icons.volume_up_rounded, size: 18)),
                      IconButton(tooltip: studio.laneLocked(lane) ? 'Unlock lane' : 'Lock lane',
                        onPressed: () => studio.toggleLaneLock(lane),
                        icon: Icon(studio.laneLocked(lane) ? Icons.lock_rounded : Icons.lock_open_rounded, size: 18)),
                    ]),
                  ]))),
                SizedBox(width: width, height: laneHeight, child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (detail) {
                    widget.pausePreview();
                    studio.setPlayhead((detail.localPosition.dx / width * duration).round());
                  },
                  child: DecoratedBox(decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14), color: color.withValues(alpha: .045),
                    border: Border.all(color: color.withValues(alpha: .12))),
                    child: Stack(clipBehavior: Clip.hardEdge, children: [
                      if (clips.isEmpty) Center(child: Text('No ${studioLaneNames[index].toLowerCase()} clips',
                        style: Theme.of(context).textTheme.bodySmall)),
                      ...clips.map((clip) => Positioned(
                        left: clip.startMs / duration * width, top: 9, bottom: 9,
                        width: math.max(14.0, clip.durationMs / duration * width),
                        child: Tooltip(message: '${clip.label}\n${studioTime(clip.startMs)} – ${studioTime(clip.endMs)}',
                          child: Semantics(button: true, selected: studio.selectedClipId == clip.id,
                            label: '${studioLaneNames[index]} clip ${clip.label}',
                            child: InkWell(onTap: () { widget.pausePreview(); studio.selectClip(clip.id);
                              studio.setPlayhead(clip.startMs); },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                                    colors: [color.withValues(alpha: .48), color.withValues(alpha: .15)]),
                                  border: Border.all(width: studio.selectedClipId == clip.id ? 2 : 1,
                                    color: studio.selectedClipId == clip.id ? Colors.white : color.withValues(alpha: .6))),
                                child: ClipRect(child: Opacity(opacity: clip.enabled && !studio.laneMuted(lane) ? 1 : .4,
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(clip.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const Spacer(),
                                    Text('${(clip.durationMs / 1000).toStringAsFixed(1)} s', maxLines: 1,
                                      overflow: TextOverflow.clip, style: Theme.of(context).textTheme.labelSmall),
                                  ]))),
                              ))))),
                      ),
                      ...project.markers.map((marker) => Positioned(left: marker.atMs / duration * width,
                        top: 0, bottom: 0, child: IgnorePointer(child: Container(width: 1, color: const Color(0x889BD5A0))))),
                      Positioned(left: studio.playheadMs / duration * width, top: 0, bottom: 0,
                        child: IgnorePointer(child: Container(width: 2, color: Colors.white))),
                    ]),
                  ),
                )),
              ]));
            }),
          ]),
        ));
      }),
      const SizedBox(height: 8),
      Text('Tap a clip to inspect it. Tap a lane to move the playhead; scroll sideways to explore.',
        style: Theme.of(context).textTheme.bodySmall),
    ]));
  }
}
