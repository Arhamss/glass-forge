const _priceDecimalDigits = 2;

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

String formatPrice(double price, {String currencySymbol = ''}) {
  final isWhole = price == price.truncateToDouble();
  final raw = isWhole
      ? price.toInt().toString()
      : price.toStringAsFixed(_priceDecimalDigits);

  final negative = raw.startsWith('-');
  final unsigned = negative ? raw.substring(1) : raw;

  final parts = unsigned.split('.');
  final grouped = _groupThousands(parts[0]);
  final formatted = parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  final sign = negative ? '-' : '';

  return '$sign$currencySymbol$formatted';
}
