import 'package:flutter/material.dart';

import '../components/components.dart';
import '../scene/gel_float.dart';
import '../state/geode_app_state.dart';
import '../theme/geode_theme.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, required this.state});
  final GeodeAppState state;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  bool _favoritesOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final query = _search.text.trim().toLowerCase();
    final looks = state.looks.where((look) =>
      (!_favoritesOnly || state.favorites.contains(look.id)) &&
      '${look.name} ${look.description}'.toLowerCase().contains(query)).toList();
    final text = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 32),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('COLLECTION', style: text.labelSmall),
          const SizedBox(height: 12),
          Text('Your collection', style: text.headlineLarge),
          const SizedBox(height: 12),
          Text('Little worlds to get lost in.', style: text.bodyLarge),
          const SizedBox(height: 28),
          GelFloat(controller: state.scene, anchor: const Offset(.5, .25), weight: 2,
            child: GelPanel(padding: const EdgeInsets.fromLTRB(18, 2, 8, 2), radius: 22,
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                style: text.bodyLarge,
                decoration: InputDecoration(
                  hintText: 'Find a feeling',
                  hintStyle: text.bodyMedium,
                  border: InputBorder.none,
                  icon: const Icon(Icons.search_rounded, size: 21),
                  suffixIcon: _search.text.isEmpty ? null : IconButton(
                    tooltip: 'Clear search', icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(_search.clear),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          GelFloat(controller: state.scene, anchor: const Offset(.35, .36), phase: .4,
            child: Wrap(spacing: 10, runSpacing: 10, children: [
            GelButton(label: 'All looks', primary: !_favoritesOnly,
              onPressed: () => setState(() => _favoritesOnly = false)),
            GelButton(label: 'Favorites', icon: Icons.favorite_border_rounded,
              primary: _favoritesOnly,
              onPressed: () => setState(() => _favoritesOnly = true)),
          ])),
          const SizedBox(height: 26),
          if (looks.isEmpty)
            GelFloat(controller: state.scene, anchor: const Offset(.5, .6),
              child: GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.water_drop_outlined, color: GeodeTokens.ice),
              const SizedBox(height: 18),
              Text(query.isNotEmpty ? 'No looks found' : 'Room for a favorite', style: text.titleLarge),
              const SizedBox(height: 8),
              Text(query.isNotEmpty ? 'Try another name or clear your search.'
                : 'Tap the heart on any look to keep it here.', style: text.bodyMedium),
              const SizedBox(height: 18),
              GelButton(label: 'Show all looks', onPressed: () => setState(() {
                _search.clear();
                _favoritesOnly = false;
              })),
            ])))
          else
            LayoutBuilder(builder: (context, constraints) {
              final width = constraints.maxWidth > 520
                ? (constraints.maxWidth - 18) / 2 : constraints.maxWidth;
              return Wrap(spacing: 18, runSpacing: 20, children: [
                for (var i = 0; i < looks.length; i++)
                  SizedBox(width: width, child: _lookCard(context, looks[i], i)),
              ]);
            }),
          const SizedBox(height: 24),
          Text('Made in Studio? Your saved looks live here for this session.',
            style: text.bodySmall),
        ]),
      )),
    );
  }

  Widget _lookCard(BuildContext context, NatureLook look, int index) {
    final state = widget.state;
    final text = Theme.of(context).textTheme;
    final favorite = state.favorites.contains(look.id);
    final selected = state.selectedLookId == look.id && !state.isEdited;
    return GelFloat(
      controller: state.scene, anchor: Offset(index.isEven ? .3 : .7, .5),
      phase: index * 1.4, weight: 1.4,
      child: GelPanel(padding: const EdgeInsets.all(10), opacity: .63, child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            Semantics(button: true, label: 'Open ${look.name}', child: GestureDetector(
              onTap: () => state.selectLook(look),
              child: SceneThumbnail(materialIndex: look.material, height: 180,
                child: Align(alignment: Alignment.bottomLeft, child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(selected ? 'CURRENT LOOK' : look.saved ? 'YOUR STUDY' : 'NATURE STUDY',
                    style: text.labelSmall?.copyWith(color: GeodeTokens.ink)),
                ))),
            )),
            Positioned(top: 8, right: 8, child: GelIconButton(
              icon: favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              tooltip: favorite ? 'Remove ${look.name} from favorites' : 'Favorite ${look.name}',
              selected: favorite, onPressed: () => state.toggleFavorite(look.id),
            )),
          ]),
          Padding(padding: const EdgeInsets.fromLTRB(8, 16, 8, 6), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(look.name, style: text.titleLarge),
              const SizedBox(height: 5),
              Text(look.description, style: text.bodyMedium),
              const SizedBox(height: 16),
              GelButton(label: 'Enter this world', icon: Icons.arrow_outward_rounded,
                onPressed: () => state.selectLook(look)),
            ],
          )),
        ],
      )),
    );
  }
}
