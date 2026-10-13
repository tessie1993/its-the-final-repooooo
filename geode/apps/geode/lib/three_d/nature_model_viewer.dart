import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import '../components/gel_panel.dart';
import 'asset_3d.dart';
import 'three_d_support.dart';

/// A local glTF inspection surface. WebView is loaded only after user intent,
/// so opening the customizer never pays for an extra rendering engine.
class NatureModelViewer extends StatefulWidget {
  const NatureModelViewer({super.key});
  @override
  State<NatureModelViewer> createState() => _NatureModelViewerState();
}

class _NatureModelViewerState extends State<NatureModelViewer> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final mode = threeDModeIn(context);
    final supported = mode != ThreeDMode.flat && (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS || kIsWeb);
    return GelPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: Text('Inside the mineral', style: Theme.of(context).textTheme.titleMedium)),
        if (supported) TextButton(onPressed: () => setState(() => _opened = !_opened),
          child: Text(_opened ? 'Close model' : 'Explore in 3D')),
      ]),
      const SizedBox(height: 8),
      SizedBox(height: 180, child: _opened && supported
        ? ModelViewer(src: 'assets/models/geode_crystal.glb',
            alt: 'Geode quartz cluster. Drag to orbit and pinch to zoom.',
            cameraControls: true, autoRotate: false,
            interactionPrompt: InteractionPrompt.none, ar: false,
            exposure: 1.1, shadowIntensity: .5, debugLogging: false)
        : Asset3D(asset: Geode3DAsset.crystalFern,
            fallback: Image.asset('assets/images/crystal-fern.png', fit: BoxFit.contain))),
      Text(_opened && supported ? 'Drag to orbit. Pinch to see the details.' : 'A small world of quartz and living light.',
        style: Theme.of(context).textTheme.bodySmall),
    ]));
  }
}
