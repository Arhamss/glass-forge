String getFileNameFromUrl(String? url) {
  if (url == null || url.isEmpty) return '';
  try {
    return Uri.parse(url).pathSegments.last;
  } catch (_) {
    return url.split('/').last;
  }
}
