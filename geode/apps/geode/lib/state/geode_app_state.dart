import 'package:flutter/foundation.dart';
import '../scene/geode_scene_controller.dart';

@immutable
class NatureLook {
  const NatureLook({required this.id, required this.name, required this.description,
    required this.material, required this.energy, this.saved = false,
    this.particles = true, this.natureDetails = true});
  final String id;
  final String name;
  final String description;
  final int material;
  final double energy;
  final bool saved;
  final bool particles;
  final bool natureDetails;
}

/// In-memory UI state. The native music/visualizer port is a separate boundary.
/// Frame updates belong to [scene], never to this screen-level notifier.
class GeodeAppState extends ChangeNotifier {
  final scene = GeodeSceneController();
  int destination = 0;
  bool immersive = false;
  bool natureDetails = true;
  String selectedLookId = 'forest-glass';
  final Set<String> favorites = {'forest-glass'};
  final List<NatureLook> looks = [
    const NatureLook(id: 'forest-glass', name: 'Forest glass',
      description: 'Clear water · quiet ripples', material: 0, energy: .42),
    const NatureLook(id: 'moonstone', name: 'Moonstone',
      description: 'Opal quartz · slow drift', material: 1, energy: .25),
    const NatureLook(id: 'silver-spring', name: 'Silver spring',
      description: 'Liquid silver · flowing light', material: 2, energy: .68),
  ];

  NatureLook get selectedLook => looks.firstWhere((look) => look.id == selectedLookId,
    orElse: () => looks.first);

  bool get isEdited => selectedLook.material != scene.materialIndex ||
    (selectedLook.energy - scene.energy).abs() > .001 ||
    selectedLook.particles != scene.particlesEnabled ||
    selectedLook.natureDetails != natureDetails;

  void navigate(int index) {
    destination = index.clamp(0, 3).toInt();
    immersive = false;
    notifyListeners();
  }

  void setImmersive(bool value) { immersive = value; notifyListeners(); }
  void togglePlayback() { scene.paused = !scene.paused; notifyListeners(); }
  void setMaterial(int value) { scene.setMaterial(value); notifyListeners(); }
  void setEnergy(double value) { scene.setEnergy(value); notifyListeners(); }
  void setParticles(bool value) { scene.particlesEnabled = value; notifyListeners(); }
  void setQuality(bool value) { scene.highQuality = value; notifyListeners(); }
  void setReducedMotion(bool value) { scene.reducedMotion = value; notifyListeners(); }
  void setNatureDetails(bool value) { natureDetails = value; notifyListeners(); }

  void selectLook(NatureLook look) {
    selectedLookId = look.id;
    scene.setMaterial(look.material);
    scene.setEnergy(look.energy);
    scene.particlesEnabled = look.particles;
    natureDetails = look.natureDetails;
    destination = 0;
    notifyListeners();
  }

  void toggleFavorite(String id) {
    if (!favorites.add(id)) favorites.remove(id);
    notifyListeners();
  }

  void saveLook(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    final look = NatureLook(id: 'saved-${DateTime.now().microsecondsSinceEpoch}',
      name: cleanName, description: 'Your nature study · this session',
      material: scene.materialIndex, energy: scene.energy, saved: true,
      particles: scene.particlesEnabled, natureDetails: natureDetails);
    looks.add(look);
    selectedLookId = look.id;
    favorites.add(look.id);
    notifyListeners();
  }

  void resetAppearance() {
    scene.setMaterial(0);
    scene.setEnergy(.42);
    scene.reducedMotion = false;
    scene.particlesEnabled = true;
    scene.highQuality = true;
    scene.paused = false;
    natureDetails = true;
    selectedLookId = 'forest-glass';
    notifyListeners();
  }

  @override
  void dispose() { scene.dispose(); super.dispose(); }
}
