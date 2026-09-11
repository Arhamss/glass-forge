import 'package:equatable/equatable.dart';

/// A place in the Showcase feed. Sample content, the way a travel app's API
/// would return it.
class Place extends Equatable {
  const Place({
    required this.id,
    required this.title,
    required this.region,
    required this.description,
    required this.distanceKm,
    required this.temperatureC,
    required this.photo,
    required this.isNearby,
  });

  final String id;
  final String title;
  final String region;
  final String description;
  final double distanceKm;
  final int temperatureC;

  /// An asset path.
  final String photo;
  final bool isNearby;

  String get distanceText => distanceKm.toStringAsFixed(1);
  String get temperatureText => '$temperatureC°';

  @override
  List<Object?> get props => [id];
}
