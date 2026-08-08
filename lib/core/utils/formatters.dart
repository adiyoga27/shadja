import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String rupiah(num value) {
    final format = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    return format.format(value);
  }

  static String rupiahShort(num value) {
    if (value >= 1000000) {
      return 'Rp${(value / 1000000).toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      return 'Rp${(value / 1000).toStringAsFixed(0)}rb';
    }
    return rupiah(value);
  }

  static String dateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);

  static String date(DateTime dt) =>
      DateFormat('dd MMM yyyy', 'id_ID').format(dt);

  static String time(DateTime dt) => DateFormat('HH:mm').format(dt);

  static String dateTimeFromIso(String iso) {
    try {
      return dateTime(DateTime.parse(iso));
    } catch (_) {
      return iso;
    }
  }
}