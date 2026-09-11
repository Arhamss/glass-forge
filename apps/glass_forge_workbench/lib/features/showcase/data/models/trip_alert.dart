import 'package:equatable/equatable.dart';

/// One notification in the Showcase's bell sheet.
class TripAlert extends Equatable {
  const TripAlert({
    required this.title,
    required this.body,
    required this.timeAgo,
  });

  final String title;
  final String body;

  /// Already formatted, the way a feed hands it over.
  final String timeAgo;

  @override
  List<Object?> get props => [title, body, timeAgo];
}
