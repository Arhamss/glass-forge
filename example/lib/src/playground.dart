import 'package:flutter/widgets.dart';
import 'package:glass_forge/glass_forge.dart';
import 'package:glass_forge_example/src/presets.dart';

/// Photographs the app can put behind the glass.
const List<String> photos = [
  'assets/images/northern_lights.jpg',
  'assets/images/tokyo_rain.jpg',
  'assets/images/desert_dunes.jpg',
  'assets/images/alpine_lake.jpg',
  'assets/images/coastal_town.jpg',
];

/// Everything the user can tinker with, in one place.
///
/// A plain [ChangeNotifier]: the app has one screen and one set of knobs,
/// and a state-management library would be most of what this example
/// teaches.
class Playground extends ChangeNotifier {
  Playground() : _material = presets.first.material;

  GlassMaterial _material;
  GlassMaterial get material => _material;

  String? _preset = presets.first.name;

  /// The preset the material came from, or null once a slider has moved.
  String? get preset => _preset;

  bool _morph = false;

  /// Whether the last change should animate. Presets morph; a slider under
  /// a finger must not lag behind it.
  bool get morph => _morph;

  void applyPreset(Preset preset) {
    _material = preset.material;
    _preset = preset.name;
    _morph = true;
    notifyListeners();
  }

  void tweak(GlassMaterial material) {
    _material = material;
    _preset = null;
    _morph = false;
    notifyListeners();
  }

  double _blend = 28;

  /// How far apart, in logical pixels, blended shapes start to merge.
  double get blend => _blend;
  set blend(double value) {
    _blend = value;
    notifyListeners();
  }

  GlassTier? _tier;

  /// A pinned tier, or null to let the engine decide.
  GlassTier? get tier => _tier;
  set tier(GlassTier? value) {
    _tier = value;
    notifyListeners();
  }

  int _photo = 0;
  String get photo => photos[_photo];
  void nextPhoto() {
    _photo = (_photo + 1) % photos.length;
    notifyListeners();
  }

  void reset() {
    _blend = 28;
    _tier = null;
    applyPreset(presets.first);
  }
}

/// Puts a [Playground] in scope and rebuilds dependents when it changes.
class PlaygroundScope extends InheritedNotifier<Playground> {
  const PlaygroundScope({
    required Playground playground,
    required super.child,
    super.key,
  }) : super(notifier: playground);

  static Playground of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlaygroundScope>()!.notifier!;

  /// The playground without subscribing to it — for callbacks.
  static Playground read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PlaygroundScope>()!.notifier!;
}
