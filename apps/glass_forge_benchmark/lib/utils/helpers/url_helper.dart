import 'dart:io';

import 'package:flutter/material.dart';
import 'package:glass_forge_benchmark/utils/helpers/logger_helper.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlHelper {
  static Future<void> launchMapsWithCoordinates({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    try {
      final encodedLabel = label != null ? Uri.encodeComponent(label) : '';
      Uri uri;

      if (Platform.isIOS) {
        uri = Uri.parse(
          'maps://?daddr=$latitude,$longitude${label != null ? '&q=$encodedLabel' : ''}',
        );
      } else {
        uri = Uri.parse(
          'geo:$latitude,$longitude?q=$latitude,$longitude${label != null ? '($encodedLabel)' : ''}',
        );
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final webUri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
        );
        if (await canLaunchUrl(webUri)) {
          await launchUrl(webUri, mode: LaunchMode.externalApplication);
        } else {
          debugPrint('Could not launch maps');
        }
      }
    } catch (e) {
      debugPrint('Error launching maps: $e');
    }
  }

  static Future<void> launchWebsite(String urlString) async {
    try {
      var url = urlString;
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        AppLogger.warning('Could not launch $url');
      }
    } catch (e, s) {
      AppLogger.error('Error launching URL', e, s);
    }
  }
}
