import 'package:flutter/material.dart';
import '../components/components.dart';
import '../state/geode_app_state.dart';
import '../theme/geode_theme.dart';
import 'visuals/native_scene_catalog.dart';
import 'visuals/visual_widgets.dart';

class LibraryScreen extends PresetLibraryScreen {
  const LibraryScreen({super.key, required super.state});
}

class PresetLibraryScreen extends StatefulWidget {
  const PresetLibraryScreen({super.key, required this.state});
  final GeodeAppState state;
  @override
  State<PresetLibraryScreen> createState() => _PresetLibraryScreenState();
}

class _PresetLibraryScreenState extends State<PresetLibraryScreen> {
  final _search = TextEditingController();
  int _filter = 0;
  bool _native = false;
  bool _fileBusy = false;
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(animation: widget.state,
    builder: (context, _) {
      final state = widget.state;
      final query = _search.text.trim().toLowerCase();
      final looks = state.looks.where((look) =>
        (_filter != 1 || state.favorites.contains(look.id)) &&
        (_filter != 2 || look.saved) &&
        '${look.name} ${look.description} ${['water', 'opal', 'mercury'][look.material]}'
          .toLowerCase().contains(query)).toList();
      return VisualPageShell(title: 'Your little worlds', subtitle: 'Presets & scene collection',
        actions: [PopupMenuButton<String>(tooltip: 'Manage look collection',
          enabled: !_fileBusy, icon: const Icon(Icons.more_horiz_rounded),
          onSelected: _fileAction, itemBuilder: (_) => const [
            PopupMenuItem(value: 'import', child: Text('Import looks')),
            PopupMenuItem(value: 'export', child: Text('Export looks')),
          ])],
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
          child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              VisualFloat(state: state, child: GelPanel(padding: const EdgeInsets.all(8),
                radius: 23, child: TextField(controller: _search,
                  decoration: InputDecoration(hintText: _native ? 'Search native scenes' : 'Search looks, moods, materials',
                    prefixIcon: const Icon(Icons.search_rounded), border: InputBorder.none,
                    suffixIcon: query.isEmpty ? null : IconButton(tooltip: 'Clear search',
                      onPressed: () { _search.clear(); setState(() {}); }, icon: const Icon(Icons.close_rounded))),
                  onChanged: (_) => setState(() {})))),
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 10, children: [
                ChoiceChip(label: Text('Looks · ${state.looks.length}'), selected: !_native,
                  onSelected: (_) => setState(() => _native = false)),
                ChoiceChip(label: Text('Native scenes · ${nativeSceneCatalog.length}'), selected: _native,
                  onSelected: (_) => setState(() => _native = true)),
              ]),
              const SizedBox(height: 20),
              if (_native) NativeSceneCatalog(query: query) else ...[
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _filterChip('All looks', 0), _filterChip('Favorites', 1), _filterChip('Saved by you', 2),
                ]),
                const SizedBox(height: 20),
                if (looks.isEmpty) _emptyState(context) else
                  LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 840 ? 3 : constraints.maxWidth >= 550 ? 2 : 1;
                    final width = (constraints.maxWidth - (columns - 1) * 18) / columns;
                    return Wrap(spacing: 18, runSpacing: 20, children: [
                      for (var i = 0; i < looks.length; i++)
                        SizedBox(width: width, child: _lookCard(context, looks[i], i)),
                    ]);
                  }),
                const SizedBox(height: 22),
                VisualFloat(state: state, phase: 2, child: GelButton(
                  label: 'Save the current look', icon: Icons.add_rounded,
                  onPressed: () => saveCurrentLook(context, state))),
                const SizedBox(height: 12),
                Text(state.visualLibrary.persistenceError ?? 'Saved looks and favorites stay on this device. Export a collection to keep a copy.',
                  textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              ],
            ]))),
        ));
    });

  Widget _filterChip(String label, int value) => FilterChip(label: Text(label),
    selected: _filter == value, onSelected: (_) => setState(() => _filter = value));

  Widget _emptyState(BuildContext context) => GelPanel(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 24), child: Column(children: [
      const Icon(Icons.water_drop_outlined, size: 38, color: GeodeTokens.ice),
      const SizedBox(height: 14),
      Text(_search.text.isNotEmpty ? 'No worlds found' : _filter == 1 ? 'Keep a little wonder' : 'Make this world your own',
        style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: 8),
      Text(_search.text.isNotEmpty ? 'Try a different name or material.' : _filter == 1
        ? 'Tap a heart on a look to find it here.' : 'Customize the scene, then save your first look.', textAlign: TextAlign.center),
      if (_search.text.isNotEmpty || _filter != 0) TextButton(
        onPressed: () { _search.clear(); setState(() => _filter = 0); }, child: const Text('Show all looks')),
    ])));

  Widget _lookCard(BuildContext context, NatureLook look, int index) {
    final state = widget.state;
    final favorite = state.favorites.contains(look.id);
    final selected = state.selectedLookId == look.id && !state.isEdited;
    return VisualFloat(state: state, phase: index * 1.4,
      anchor: Offset(index.isEven ? .3 : .7, .5), child: GelPanel(
        padding: const EdgeInsets.all(10), opacity: .68,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Stack(children: [
            Semantics(button: true, label: 'Apply ${look.name}', child: InkWell(
              borderRadius: BorderRadius.circular(21), onTap: () => _apply(look),
              child: SceneThumbnail(materialIndex: look.material, height: 185,
                child: Text(selected ? 'CURRENT LOOK' : look.saved ? 'SAVED BY YOU' : 'NATURE STUDY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: GeodeTokens.ink))))),
            Positioned(top: 8, right: 8, child: GelIconButton(
              icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              tooltip: favorite ? 'Unfavorite ${look.name}' : 'Favorite ${look.name}',
              selected: favorite, onPressed: () => state.toggleFavorite(look.id))),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(8, 12, 0, 0), child: Row(children: [
            Expanded(child: Text(look.name, style: Theme.of(context).textTheme.titleMedium)),
            PopupMenuButton<String>(tooltip: 'Manage ${look.name}', onSelected: (value) => _lookAction(value, look),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
                if (look.saved) ...[
                  const PopupMenuItem(value: 'rename', child: Text('Rename')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ]),
          ])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(look.description,
            style: Theme.of(context).textTheme.bodySmall)),
          const SizedBox(height: 14),
          GelButton(label: selected ? 'Return to this world' : 'Enter this world',
            primary: false, icon: Icons.arrow_outward_rounded, onPressed: () => _apply(look)),
        ])));
  }

  void _apply(NatureLook look) {
    widget.state.selectLook(look);
    Navigator.pop(context);
  }

  Future<void> _lookAction(String action, NatureLook look) async {
    final state = widget.state;
    if (action == 'duplicate') {
      final copy = state.visualLibrary.duplicate(look.id);
      if (copy != null) state.selectLook(copy);
    } else if (action == 'rename') {
      final name = await askLookName(context, initialName: look.name, title: 'Rename this world', action: 'Rename');
      if (name != null && mounted) state.visualLibrary.rename(look.id, name);
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(context: context,
        builder: (context) => AlertDialog(title: Text('Delete “${look.name}”?'),
          content: const Text('This removes the saved look from this device.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep look')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
      if (confirmed != true || !mounted) return;
      final wasSelected = state.selectedLookId == look.id;
      state.visualLibrary.delete(look.id);
      if (wasSelected) state.selectLook(state.visualLibrary.selectedLook);
    }
  }

  Future<void> _fileAction(String action) async {
    setState(() => _fileBusy = true);
    String? message;
    try {
      if (action == 'import') {
        final count = await widget.state.visualLibrary.importLooks();
        if (count >= 0) message = '$count ${count == 1 ? 'look' : 'looks'} imported.';
      } else if (await widget.state.visualLibrary.exportLooks()) {
        message = 'Look collection exported.';
      }
    } on FormatException catch (error) { message = error.message.toString(); }
    catch (_) { message = 'The file could not be ${action == 'import' ? 'opened' : 'saved'}. Please try again.'; }
    if (!mounted) return;
    setState(() => _fileBusy = false);
    if (message != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
