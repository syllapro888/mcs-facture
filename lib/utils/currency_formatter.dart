/// Formatage des montants en francs CFA : « 182 000 FCFA ».
class CurrencyFormatter {
  CurrencyFormatter._();

  static const String aPreciser = 'À préciser';

  /// 182000 -> "182 000"
  static String number(num value) {
    final negative = value < 0;
    final digits = value.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return negative ? '-$buffer' : buffer.toString();
  }

  /// 182000 -> "182 000 FCFA" ; null -> "À préciser"
  static String fcfa(num? value) =>
      value == null ? aPreciser : '${number(value)} FCFA';

  /// Quantité : 4 -> "4", 2.5 -> "2,5"
  static String quantity(double q) {
    if (q == q.roundToDouble()) return q.toInt().toString();
    var s = q.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s.replaceAll('.', ',');
  }

  /// Lit un montant saisi : "182 000", "182.000" -> 182000 ; vide -> null
  static int? parseAmount(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.isEmpty) return null;
    return int.tryParse(cleaned);
  }

  /// Lit une quantité : "2,5" -> 2.5
  static double? parseQuantity(String text) {
    final cleaned = text.trim().replaceAll(' ', '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
