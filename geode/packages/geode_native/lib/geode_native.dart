/// Dart bindings to libgeode.so and the Android entry points that cannot be Dart.
library;

import 'dart:ffi';

import 'src/geode_api.g.dart';

export 'src/geode_api.g.dart';
export 'src/native_platform.dart';

/// The process-wide binding to libgeode.so.
///
/// libgeode is loaded once per process, so every caller shares this instance.
final GeodeApi geodeApi = GeodeApi(DynamicLibrary.open('libgeode.so'));
