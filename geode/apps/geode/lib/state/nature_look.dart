import 'package:flutter/foundation.dart';
import 'visual_parameters.dart';

/// A Flutter gel look. This deliberately has its own format, independent of
/// native renderer presets and their scene-specific parameter schemas.
@immutable
class NatureLook {
  const NatureLook({
    required this.id,
    required this.name,
    required this.description,
    required this.material,
    required this.energy,
    this.saved = false,
    this.particles = true,
    this.natureDetails = true,
    this.hue = .5,
    this.luminescence = .65,
    this.particleDensity = .6,
    this.rippleStrength = .65,
    this.nativeScene,
    this.milkPreset,
    this.nativeParameters = const {},
  });

  final String id, name, description;
  final int material;
  final double energy, hue, luminescence, particleDensity, rippleStrength;
  final bool saved, particles, natureDetails;
  final String? nativeScene, milkPreset;
  final Map<String, double> nativeParameters;

  NatureLook copyWith({String? id, String? name, String? description,
    int? material, double? energy, bool? saved, bool? particles,
    bool? natureDetails, double? hue, double? luminescence, double? particleDensity,
    double? rippleStrength, String? nativeScene, String? milkPreset,
    Map<String, double>? nativeParameters}) => NatureLook(
      id: id ?? this.id, name: name ?? this.name,
      description: description ?? this.description,
      material: material ?? this.material, energy: energy ?? this.energy,
      saved: saved ?? this.saved, particles: particles ?? this.particles,
      natureDetails: natureDetails ?? this.natureDetails, hue: hue ?? this.hue,
      luminescence: luminescence ?? this.luminescence,
      particleDensity: particleDensity ?? this.particleDensity,
      rippleStrength: rippleStrength ?? this.rippleStrength,
      nativeScene: nativeScene ?? this.nativeScene, milkPreset: milkPreset ?? this.milkPreset,
      nativeParameters: nativeParameters ?? this.nativeParameters);

  Map<String, Object> toJson() => {
    'id': id, 'name': name, 'description': description,
    'material': material, 'energy': energy, 'saved': saved,
    'particles': particles, 'natureDetails': natureDetails,
    'hue': hue, 'luminescence': luminescence, 'particleDensity': particleDensity,
    'rippleStrength': rippleStrength,
    'nativeScene': ?nativeScene,
    'milkPreset': ?milkPreset,
    'nativeParameters': nativeParameters,
  };

  factory NatureLook.fromJson(Map<String, dynamic> value) {
    String string(String key, {int max = 160}) {
      final result = value[key];
      if (result is! String || result.trim().isEmpty || result.length > max) {
        throw FormatException('Invalid look $key.');
      }
      return result.trim();
    }
    double number(String key, double fallback) {
      final result = value[key] ?? fallback;
      if (result is! num || !result.isFinite || result < 0 || result > 1) {
        throw FormatException('Invalid look $key.');
      }
      return result.toDouble();
    }
    bool boolean(String key, bool fallback) {
      final result = value[key] ?? fallback;
      if (result is! bool) throw FormatException('Invalid look $key.');
      return result;
    }
    final material = value['material'];
    if (material is! int || material < 0 || material > 2) {
      throw const FormatException('This look uses an unsupported material.');
    }
    final nativeScene = value['nativeScene'];
    final milkPreset = value['milkPreset'];
    if (nativeScene != null && (nativeScene is! String || !RegExp(r'^[a-z0-9_]{1,80}$').hasMatch(nativeScene))) {
      throw const FormatException('Invalid native scene.');
    }
    if (milkPreset != null && (milkPreset is! String || milkPreset.length > 512 || milkPreset.contains('..'))) {
      throw const FormatException('Invalid MilkDrop preset.');
    }
    final parameters = <String, double>{};
    final raw = value['nativeParameters'];
    if (raw != null && raw is! Map) throw const FormatException('Invalid visual settings.');
    if (raw is Map) {
      for (final parameter in visualParameterCatalog) {
        final entry = raw[parameter.id];
        if (entry == null) continue;
        if (entry is! num || !entry.isFinite) throw const FormatException('Invalid visual setting.');
        parameters[parameter.id] = parameter.clamp(entry.toDouble());
      }
    }
    return NatureLook(
      id: string('id'), name: string('name', max: 64),
      description: string('description', max: 240), material: material,
      energy: number('energy', .42), hue: number('hue', .5),
      luminescence: number('luminescence', .65),
      particleDensity: number('particleDensity', .6),
      rippleStrength: number('rippleStrength', .65),
      saved: boolean('saved', true), particles: boolean('particles', true),
      natureDetails: boolean('natureDetails', true),
      nativeScene: nativeScene as String?, milkPreset: milkPreset as String?,
      nativeParameters: Map.unmodifiable(parameters),
    );
  }
}
