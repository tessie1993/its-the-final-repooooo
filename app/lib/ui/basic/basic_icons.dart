import 'package:flutter/material.dart';

import '../../app/spec/app_map.dart';

IconData destinationIcon(DestinationId id) => switch (id) {
  DestinationId.player => Icons.play_circle_outline,
  DestinationId.library => Icons.library_music_outlined,
  DestinationId.visuals => Icons.auto_awesome_outlined,
  DestinationId.studio => Icons.movie_creation_outlined,
  DestinationId.settings => Icons.settings_outlined,
};

IconData modalIcon(PageKind kind) =>
    kind == PageKind.dialog ? Icons.chat_bubble_outline : Icons.vertical_split_outlined;

IconData surfaceIcon(PageSurface surface) => switch (surface) {
  PageSurface.none => Icons.crop_square,
  PageSurface.visualizer => Icons.blur_on,
  PageSurface.timeline => Icons.view_timeline_outlined,
  PageSurface.spectrum => Icons.graphic_eq,
};

String surfaceLabel(PageSurface surface) => switch (surface) {
  PageSurface.none => '',
  PageSurface.visualizer => 'Visualizer — C++ render host (not wired yet)',
  PageSurface.timeline => 'Timeline — lanes, clips, keyframes (not wired yet)',
  PageSurface.spectrum => 'Live spectrum — analysis feature frames (not wired yet)',
};
