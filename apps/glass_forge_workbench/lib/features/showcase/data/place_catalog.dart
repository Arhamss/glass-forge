import 'package:glass_forge_workbench/constants/asset_paths.dart';
import 'package:glass_forge_workbench/features/showcase/data/models/place.dart';
import 'package:glass_forge_workbench/features/showcase/data/models/trip_alert.dart';

/// The Showcase's sample content. Static on purpose: the screen exists to
/// show glass over real photographs, not to fetch anything.
abstract class PlaceCatalog {
  static const places = <Place>[
    Place(
      id: 'braies',
      title: 'Lago di Braies',
      region: 'Dolomites, Italy',
      description:
          'A still, cold lake under the Seekofel. Go before seven and the '
          'boathouse has the water to itself.',
      distanceKm: 12.4,
      temperatureC: 14,
      photo: AssetPaths.photoAlpineLake,
      isNearby: true,
    ),
    Place(
      id: 'omoide',
      title: 'Omoide Yokochō',
      region: 'Shinjuku, Tokyo',
      description:
          'Sixty tiny bars in two alleys by the station. Best in the rain, '
          'when the lanterns double in the puddles.',
      distanceKm: 3.1,
      temperatureC: 19,
      photo: AssetPaths.photoTokyoRain,
      isNearby: true,
    ),
    Place(
      id: 'apostles',
      title: 'Twelve Apostles',
      region: 'Victoria, Australia',
      description:
          'Limestone stacks off the Great Ocean Road. Seven are still '
          'standing; the light is best in the last hour of the day.',
      distanceKm: 48.2,
      temperatureC: 21,
      photo: AssetPaths.photoSeaCliffs,
      isNearby: false,
    ),
    Place(
      id: 'columbia',
      title: 'Columbia Road',
      region: 'London, UK',
      description:
          'A Sunday flower market that fills one street end to end. Traders '
          'drop their prices as they pack up at three.',
      distanceKm: 1.2,
      temperatureC: 16,
      photo: AssetPaths.photoFlowerMarket,
      isNearby: true,
    ),
    Place(
      id: 'chebbi',
      title: 'Erg Chebbi',
      region: 'Merzouga, Morocco',
      description:
          'Dunes up to 150 metres high on the edge of the Sahara. Camp one '
          'night and watch the ridges turn blue after sunset.',
      distanceKm: 210.5,
      temperatureC: 27,
      photo: AssetPaths.photoDesertDunes,
      isNearby: false,
    ),
    Place(
      id: 'senja',
      title: 'Senja',
      region: 'Troms, Norway',
      description:
          'Norway in miniature: fjords, peaks and fishing villages on one '
          'island, and aurora most clear nights from September.',
      distanceKm: 96,
      temperatureC: -4,
      photo: AssetPaths.photoNorthernLights,
      isNearby: false,
    ),
    Place(
      id: 'riomaggiore',
      title: 'Riomaggiore',
      region: 'Cinque Terre, Italy',
      description:
          'Houses stacked up a ravine above a harbour the size of a car park. '
          'Take the evening boat back to La Spezia.',
      distanceKm: 7.8,
      temperatureC: 22,
      photo: AssetPaths.photoCoastalTown,
      isNearby: true,
    ),
    Place(
      id: 'hoh',
      title: 'Hoh Rainforest',
      region: 'Washington, USA',
      description:
          'Moss-hung maples and ferns in one of the wettest places in the '
          'lower 48. The Hall of Mosses loop takes under an hour.',
      distanceKm: 64.3,
      temperatureC: 11,
      photo: AssetPaths.photoForestFog,
      isNearby: false,
    ),
  ];

  static const alerts = <TripAlert>[
    TripAlert(
      title: 'Clear skies over Senja',
      body: 'Aurora forecast is strong from 22:00 tonight.',
      timeAgo: '12 min',
    ),
    TripAlert(
      title: 'Columbia Road is on',
      body: 'The market opens at 8. You saved it last week.',
      timeAgo: '2 h',
    ),
    TripAlert(
      title: 'Braies before the crowds',
      body: 'Sunrise is at 06:41. The first bus leaves at 05:50.',
      timeAgo: 'Yesterday',
    ),
  ];

  static const nowPlayingTitle = 'Night Drive';
  static const nowPlayingArtist = 'Coastline FM';
}
