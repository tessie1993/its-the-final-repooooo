import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../components/components.dart';
import '../scene/gel_float.dart';
import '../state/geode_app_state.dart';
import 'studio_dialogs.dart';
import 'studio_models.dart';
import '../three_d/asset_3d.dart';

class ProjectBrowser extends StatelessWidget {
  const ProjectBrowser({super.key, required this.state});
  final GeodeAppState state;

  Future<void> _create(BuildContext context) async {
    final name = await studioName(context, 'A new nature film', label: 'Project name');
    if (name != null) state.studio.createProject(name);
  }

  Future<void> _import(BuildContext context) async {
    try {
      final file = await FilePicker.pickFile(type: FileType.custom,
        allowedExtensions: ['json'], dialogTitle: 'Import Geode UI project');
      if (file == null) return;
      final size = await file.length();
      if (size != null && size > 5 * 1024 * 1024) {
        throw const FormatException('Project files must be smaller than 5 MB.');
      }
      final value = jsonDecode(utf8.decode(await file.readAsBytes()));
      if (value is! Map<String, dynamic>) {
        throw const FormatException('This file is not a project object.');
      }
      state.studio.importProject(value);
      if (context.mounted && state.studio.error != null) {
        studioMessage(context, state.studio.error!);
      }
    } catch (error) {
      if (context.mounted) studioMessage(context, 'Could not import project: $error');
    }
  }

  Future<void> _projectAction(BuildContext context, StudioProject project, String action) async {
    final studio = state.studio;
    if (action == 'rename') {
      final name = await studioName(context, 'Rename project', initial: project.name);
      if (name != null) studio.renameProject(project.id, name);
    } else if (action == 'duplicate') {
      studio.duplicateProject(project.id);
    } else if (action == 'delete' && await studioConfirm(context, 'Delete ${project.name}?',
      'This removes the local project. Export a JSON copy first if you want to keep it.')) {
      studio.deleteProject(project.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final projects = state.studio.projects;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('STUDIO / YOUR FILMS', style: text.labelSmall),
      const SizedBox(height: 12),
      Text('Let an idea\ntake shape.', style: text.headlineLarge),
      const SizedBox(height: 12),
      Text('Compose materials, music and moments in one living timeline.', style: text.bodyLarge),
      const SizedBox(height: 24),
      GelFloat(controller: state.scene, anchor: const Offset(.55, .33), phase: .7,
        child: SceneThumbnail(materialIndex: state.scene.materialIndex, height: 240,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('A SMALL WORLD. A WIDE CANVAS.', style: text.labelSmall),
            const SizedBox(height: 8),
            Text('Your next atmosphere', style: text.headlineSmall),
            const SizedBox(height: 14),
            GelButton(label: 'Create project', icon: Icons.add_rounded,
              onPressed: () => _create(context)),
          ]))),
      const SizedBox(height: 26),
      Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text('${projects.length} ${projects.length == 1 ? 'project' : 'projects'}', style: text.titleLarge),
        TextButton.icon(onPressed: () => _import(context), icon: const Icon(Icons.file_open_outlined),
          label: const Text('Import project JSON')),
      ]),
      const SizedBox(height: 12),
      if (projects.isEmpty) GelPanel(child: Column(children: [
        Asset3D.boxed(asset: Geode3DAsset.crystalFern, width: 140, height: 110, fallback: Image.asset('assets/images/crystal-fern.png', width: 140, height: 110,
          excludeFromSemantics: true, errorBuilder: (_, error, stack) => const Icon(Icons.spa_outlined, size: 38))),
        const SizedBox(height: 12),
        Text('Room for your first film', style: text.titleMedium),
        const SizedBox(height: 8),
        const Text('Start with a material, add a title, then arrange your timeline.', textAlign: TextAlign.center),
      ])),
      LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth > 720 ? (box.maxWidth - 16) / 2 : box.maxWidth;
        return Wrap(spacing: 16, runSpacing: 16, children: projects.map((project) {
          final visuals = project.clips.where((clip) => clip.lane == 'visual');
          final material = visuals.isEmpty ? 0 : visuals.first.materialIndex;
          return SizedBox(width: width, child: GelPanel(padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(button: true, label: 'Open ${project.name}', child: InkWell(
                borderRadius: BorderRadius.circular(21),
                onTap: () => state.studio.selectProject(project.id),
                child: SceneThumbnail(materialIndex: material, height: 150,
                  child: Text(project.name, style: text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis)),
              )),
              Row(children: [
                Expanded(child: Padding(padding: const EdgeInsets.all(8),
                  child: Text('${project.clips.length} clips · ${studioTime(project.durationMs)}', style: text.bodySmall))),
                PopupMenuButton<String>(tooltip: 'Project actions',
                  onSelected: (action) => _projectAction(context, project, action),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ]),
              ]),
            ])));
        }).toList());
      }),
      const SizedBox(height: 20),
      Text('Projects save on this device. JSON exchange uses the Geode UI project format; native .geode templates are separate.',
        style: text.bodySmall),
    ]);
  }
}
