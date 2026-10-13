import 'package:flutter/material.dart';

import '../../app/spec/app_map.dart';
import '../ui_kit.dart';
import 'basic_icons.dart';

/// Any page from the app map: an app bar, then either its tabs or its content.
class BasicPage extends StatelessWidget {
  const BasicPage({super.key, required this.model});

  final PageModel model;

  @override
  Widget build(BuildContext context) {
    final spec = model.spec;
    final onSearch = model.onSearch;
    return Scaffold(
      appBar: AppBar(
        title: Text(spec.title),
        actions: [
          if (onSearch != null)
            IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: onSearch),
        ],
      ),
      body: spec.tabs.isEmpty ? BasicPageBody(model: model) : _TabbedBody(model: model),
    );
  }
}

/// A page with tabs: what the page itself does (collapsed), then the tabs. Tabs nest.
class _TabbedBody extends StatelessWidget {
  const _TabbedBody({required this.model});

  final PageModel model;

  @override
  Widget build(BuildContext context) {
    final spec = model.spec;
    final hasInfo =
        spec.summary.isNotEmpty ||
        spec.features.isNotEmpty ||
        spec.poweredBy.isNotEmpty ||
        spec.children.isNotEmpty ||
        spec.sheets.isNotEmpty ||
        spec.actions.isNotEmpty;
    return DefaultTabController(
      length: spec.tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (spec.surface != PageSurface.none) _SurfacePlaceholder(spec.surface, height: 96),
          if (hasInfo)
            ExpansionTile(
              title: Text('About ${spec.title}'),
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: BasicPageBody(model: model, showSurface: false),
                ),
              ],
            ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final tab in spec.tabs) Tab(text: tab.title)],
          ),
          Expanded(
            child: TabBarView(
              children: [
                for (final tab in spec.tabs)
                  tab.tabs.isEmpty
                      ? BasicPageBody(model: model.forSpec(tab))
                      : _TabbedBody(model: model.forSpec(tab)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The content of one page: what it does, what powers it, and everything it opens.
class BasicPageBody extends StatelessWidget {
  const BasicPageBody({super.key, required this.model, this.shrinkWrap = false, this.showSurface = true});

  final PageModel model;
  final bool shrinkWrap;
  final bool showSurface;

  @override
  Widget build(BuildContext context) {
    final spec = model.spec;
    final text = Theme.of(context).textTheme;
    return ListView(
      shrinkWrap: shrinkWrap,
      padding: const EdgeInsets.all(16),
      children: [
        if (spec.summary.isNotEmpty) Text(spec.summary, style: text.bodyLarge),
        if (showSurface && spec.surface != PageSurface.none && spec.tabs.isEmpty) ...[
          const SizedBox(height: 12),
          _SurfacePlaceholder(spec.surface, height: 180),
        ],
        if (spec.children.isNotEmpty) ...[
          _Heading('Opens'),
          for (final child in spec.children)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(child.kind == PageKind.fullscreen ? Icons.fullscreen : Icons.arrow_forward),
              title: Text(child.title),
              subtitle: child.summary.isEmpty ? null : Text(child.summary),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => model.openChild(child),
            ),
        ],
        if (spec.sheets.isNotEmpty) ...[
          _Heading('Sheets & dialogs'),
          for (final modal in spec.sheets)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(modalIcon(modal.kind)),
              title: Text(modal.title),
              onTap: () => model.openModal(modal),
            ),
        ],
        if (spec.actions.isNotEmpty) ...[
          _Heading('Actions'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in spec.actions)
                FilledButton.tonal(onPressed: () => model.runAction(a.action), child: Text(a.label)),
            ],
          ),
        ],
        if (spec.features.isNotEmpty) ...[
          _Heading('What it does'),
          for (final f in spec.features) _Bullet(f),
        ],
        if (spec.poweredBy.isNotEmpty) ...[
          _Heading('Powered by'),
          for (final p in spec.poweredBy) _Bullet(p, icon: Icons.memory),
        ],
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 6),
    child: Text(label, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text, {this.icon = Icons.circle});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4, right: 8),
          child: Icon(icon, size: icon == Icons.circle ? 6 : 14),
        ),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _SurfacePlaceholder extends StatelessWidget {
  const _SurfacePlaceholder(this.surface, {required this.height});

  final PageSurface surface;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    margin: const EdgeInsets.symmetric(horizontal: 0),
    decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(8)),
    alignment: Alignment.center,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(surfaceIcon(surface), color: Colors.white54),
        const SizedBox(width: 8),
        Flexible(
          child: Text(surfaceLabel(surface), style: const TextStyle(color: Colors.white54)),
        ),
      ],
    ),
  );
}
