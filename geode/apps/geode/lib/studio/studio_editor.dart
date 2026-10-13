import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../components/components.dart';
import '../state/geode_app_state.dart';
import 'clip_dialog.dart';
import 'clip_inspector.dart';
import 'export_sheet.dart';
import 'studio_controller.dart';
import 'studio_dialogs.dart';
import 'studio_timeline.dart';

class StudioEditor extends StatefulWidget {
  const StudioEditor({super.key, required this.state});
  final GeodeAppState state;
  @override
  State<StudioEditor> createState() => _StudioEditorState();
}

class _StudioEditorState extends State<StudioEditor> with WidgetsBindingObserver {
  Timer? _timer;
  final _clock = Stopwatch();
  int _startMs = 0;
  bool get _playing => _timer != null;
  StudioController get studio => widget.state.studio;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addObserver(this); }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _pause();
  }
  @override
  void dispose() {
    _timer?.cancel(); _clock.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _pause() {
    _timer?.cancel(); _timer = null; _clock.stop();
    if (mounted) setState(() {});
  }

  void _play() {
    if (_playing) { _pause(); return; }
    final project = studio.selectedProject;
    if (project == null || project.clips.isEmpty) return;
    if (studio.playheadMs >= project.durationMs) studio.setPlayhead(0);
    _startMs = studio.playheadMs;
    _clock.reset(); _clock.start();
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      final project = studio.selectedProject;
      if (!mounted || project == null || widget.state.destination != 2) { _pause(); return; }
      final next = _startMs + _clock.elapsedMilliseconds;
      studio.setPlayhead(math.min(next, project.durationMs));
      if (next >= project.durationMs) _pause();
    });
    setState(() {});
  }

  Future<void> _add() async {
    _pause();
    await showDialog<void>(context: context, builder: (_) => ClipDialog(studio: studio));
  }

  @override
  Widget build(BuildContext context) {
    final project = studio.selectedProject!;
    final text = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        TextButton.icon(onPressed: () { _pause(); studio.selectProject(null); },
          icon: const Icon(Icons.arrow_back_rounded), label: const Text('Projects')),
        Text('STUDIO / COMPOSE', style: text.labelSmall),
      ]),
      const SizedBox(height: 8),
      Text(project.name, style: text.headlineMedium),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        GelButton(label: 'Add clip', icon: Icons.add_rounded, onPressed: _add),
        IconButton.filledTonal(tooltip: 'Undo edit', onPressed: studio.canUndo ? () {
          _pause(); studio.undo();
        } : null, icon: const Icon(Icons.undo_rounded)),
        IconButton.filledTonal(tooltip: 'Redo edit', onPressed: studio.canRedo ? () {
          _pause(); studio.redo();
        } : null, icon: const Icon(Icons.redo_rounded)),
        TextButton.icon(onPressed: () { _pause(); showModalBottomSheet<void>(
          context: context, isScrollControlled: true, useSafeArea: true,
          builder: (_) => ExportSheet(studio: studio));
        }, icon: const Icon(Icons.ios_share_rounded), label: const Text('Export')),
      ]),
      const SizedBox(height: 18),
      LayoutBuilder(builder: (context, box) {
        final preview = _preview(context);
        final inspector = ClipInspector(studio: studio, pausePreview: _pause);
        if (box.maxWidth < 920) return Column(children: [
          preview, const SizedBox(height: 18), inspector,
        ]);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 3, child: preview), const SizedBox(width: 18),
          Expanded(flex: 2, child: inspector),
        ]);
      }),
      const SizedBox(height: 18),
      StudioTimeline(studio: studio, pausePreview: _pause),
      const SizedBox(height: 18),
      _markers(context),
    ]);
  }

  Widget _preview(BuildContext context) {
    final project = studio.selectedProject!;
    final active = project.clips.where((c) => c.enabled && !studio.laneMuted(c.lane)
      && c.startMs <= studio.playheadMs && studio.playheadMs < c.endMs).toList()
      ..sort((a, b) => a.startMs.compareTo(b.startMs));
    final visuals = active.where((c) => c.lane == 'visual').toList();
    final titles = active.where((c) => c.lane == 'text').toList();
    final energy = widget.state.scene.effectiveReducedMotion ? 0.0
      : project.evaluate('energy', studio.playheadMs, fallback: .4).clamp(0.0, 1.0).toDouble();
    final opacity = project.evaluate('opacity', studio.playheadMs, fallback: 1).clamp(0.0, 1.0).toDouble();
    return GelPanel(padding: const EdgeInsets.all(12), child: Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(22), child: SizedBox(height: 270,
        child: Stack(fit: StackFit.expand, children: [
          if (visuals.isNotEmpty) Opacity(opacity: opacity, child: Transform.scale(
            scale: 1 + energy * .025 * math.sin(studio.playheadMs / 1600),
            child: SceneThumbnail(materialIndex: visuals.last.materialIndex, height: 270)))
          else const ColoredBox(color: Color(0xFF071A21), child: Center(
            child: Text('No visual at this time', style: TextStyle(color: Color(0xFFAEC7D0))))),
          if (titles.isNotEmpty) Center(child: Padding(padding: const EdgeInsets.all(24),
            child: Text(titles.map((c) => c.label).join('\n'), textAlign: TextAlign.center,
              maxLines: 5, overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white, shadows: const [Shadow(blurRadius: 16, color: Colors.black)])))),
          Positioned(left: 14, top: 14, child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
            child: const Padding(padding: EdgeInsets.all(8), child: Text('MATERIAL + TEXT PREVIEW')))),
        ]))),
      const SizedBox(height: 8),
      Row(children: [
        IconButton.filledTonal(tooltip: _playing ? 'Pause timeline preview' : 'Play timeline preview',
          onPressed: project.clips.isEmpty ? null : _play,
          icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded)),
        const SizedBox(width: 10),
        Expanded(child: Text('${studioTime(studio.playheadMs)} / ${studioTime(project.durationMs)}')),
        IconButton(tooltip: 'Return to start', onPressed: () { _pause(); studio.setPlayhead(0); },
          icon: const Icon(Icons.skip_previous_rounded)),
      ]),
      Slider(value: studio.playheadMs.clamp(0, project.durationMs).toDouble(),
        max: project.durationMs.toDouble(), label: studioTime(studio.playheadMs),
        onChanged: (value) { _pause(); studio.setPlayhead(value.round()); }),
      Padding(padding: const EdgeInsets.fromLTRB(8, 0, 8, 8), child: Text(
        'Material and text timing preview. Media, audio and overlays remain references; transitions are saved for rendering.',
        style: Theme.of(context).textTheme.bodySmall)),
    ]));
  }

  Widget _markers(BuildContext context) {
    final markers = studio.selectedProject!.markers;
    return GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 14, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('Moments to remember', style: Theme.of(context).textTheme.titleMedium),
        TextButton.icon(onPressed: () async {
          _pause();
          final name = await studioName(context, 'Mark this moment',
            initial: 'Moment ${markers.length + 1}');
          if (name != null) studio.addMarker(name);
        }, icon: const Icon(Icons.bookmark_add_outlined), label: const Text('Add marker')),
      ]),
      if (markers.isEmpty) const Text('Place the playhead at a moment, then mark it.'),
      Wrap(spacing: 8, runSpacing: 8, children: markers.map((marker) => InputChip(
        label: Text('${marker.name} · ${studioTime(marker.atMs)}'),
        onPressed: () { _pause(); studio.setPlayhead(marker.atMs); },
        onDeleted: () => studio.deleteMarker(marker.id), deleteButtonTooltipMessage: 'Delete marker',
      )).toList()),
    ]));
  }
}
