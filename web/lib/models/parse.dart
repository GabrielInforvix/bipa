/// Parse tolerante. O Prisma serializa Decimal como String no JSON, então
/// preço e quantidade chegam como texto — nunca como número.
double parseDouble(dynamic v, {double padrao = 0}) {
  if (v == null) return padrao;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? padrao;
}

double? parseDoubleOpt(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int parseInt(dynamic v, {int padrao = 0}) {
  if (v == null) return padrao;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? padrao;
}

bool parseBool(dynamic v, {bool padrao = false}) {
  if (v == null) return padrao;
  if (v is bool) return v;
  final t = v.toString().toLowerCase();
  return t == 'true' || t == '1';
}

String parseString(dynamic v, {String padrao = ''}) =>
    v == null ? padrao : v.toString();

String? parseStringOpt(dynamic v) {
  final s = v?.toString();
  return (s == null || s.isEmpty) ? null : s;
}
