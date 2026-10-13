import 'package:flutter/foundation.dart';

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
    this.particleDensity = .6,
    this.rippleStrength = .65,
  });

  final String id, name, description;
  final int material;
  final double energy, hue, particleDensity, rippleStrength;
  final bool saved, particles, natureDetails;

  NatureLook copyWith({String? id, String? name, String? description,
    int? material, double? energy, bool? saved, bool? particles,
    bool? natureDetails, double? hue, double? particleDensity,
    double? rippleStrength}) => NatureLook(
      id: id ?? this.id, name: name ?? this.name,
      description: description ?? this.description,
      material: material ?? this.material, energy: energy ?? this.energy,
      saved: saved ?? this.saved, particles: particles ?? this.particles,
      natureDetails: natureDetails ?? this.natureDetails, hue: hue ?? this.hue,
      particleDensity: particleDensity ?? this.particleDensity,
      rippleStrength: rippleStrength ?? this.rippleStrength);

  Map<String, Object> toJson() => {
    'id': id, 'name': name, 'description': description,
    'material': material, 'energy': energy, 'saved': saved,
    'particles': particles, 'natureDetails': natureDetails,
    'hue': hue, 'particleDensity': particleDensity,
    'rippleStrength': rippleStrength,
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
    return NatureLook(
      id: string('id'), name: string('name', max: 64),
      description: string('description', max: 240), material: material,
      energy: number('energy', .42), hue: number('hue', .5),
      particleDensity: number('particleDensity', .6),
      rippleStrength: number('rippleStrength', .65),
      saved: boolean('saved', true), particles: boolean('particles', true),
      natureDetails: boolean('natureDetails', true),
    );
  }
}
