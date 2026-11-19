import 'package:intl/intl.dart';

/// Tarih/süre/para biçimlendirme yardımcıları.
String formatDate(String? raw, {String pattern = 'd MMM yyyy'}) {
  if (raw == null || raw.length < 4) return '-';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return DateFormat(pattern).format(d);
}

String formatYear(String? raw) =>
    (raw == null || raw.length < 4) ? '' : raw.substring(0, 4);

String formatRuntime(int? minutes) {
  if (minutes == null || minutes <= 0) return '-';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return h > 0 ? '${h}s ${m > 0 ? '${m}dk' : ''}'.trim() : '${m}dk';
}

String formatScore(double? value) =>
    value == null || value <= 0 ? '-' : '${(value * 10).round()}%';

String formatMoney(int? value, {String symbol = r'$'}) {
  if (value == null || value <= 0) return '-';
  return '$symbol${NumberFormat.decimalPattern('tr').format(value)}';
}

String formatCount(int? value) {
  if (value == null) return '-';
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}B';
  return '$value';
}

String relativeTime(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inDays > 30) return formatDate(d.toIso8601String());
  if (diff.inDays > 0) return '${diff.inDays} gün önce';
  if (diff.inHours > 0) return '${diff.inHours} saat önce';
  if (diff.inMinutes > 0) return '${diff.inMinutes} dk önce';
  return 'az önce';
}
