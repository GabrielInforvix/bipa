import 'package:intl/intl.dart';

final _dataBr = DateFormat('dd/MM/yyyy', 'pt_BR');
final _dataHoraBr = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');
final _diaMes = DateFormat('dd/MM', 'pt_BR');
final _extenso = DateFormat("EEEE, d 'de' MMMM", 'pt_BR');
final _paraApi = DateFormat('yyyy-MM-dd');

extension DataFormatacao on DateTime {
  String get emDataBr => _dataBr.format(this);
  String get emDataHoraBr => _dataHoraBr.format(this);
  String get emDiaMes => _diaMes.format(this);
  String get porExtenso => _extenso.format(this);
  String get paraApi => _paraApi.format(this);

  /// "hoje" · "ontem" · "12/08/2026"
  String get relativa {
    final hoje = DateTime.now();
    final d = DateTime(year, month, day);
    final h = DateTime(hoje.year, hoje.month, hoje.day);
    final dias = h.difference(d).inDays;
    if (dias == 0) return 'hoje';
    if (dias == 1) return 'ontem';
    return emDataBr;
  }
}

DateTime? parseDataApi(dynamic valor) {
  if (valor == null) return null;
  if (valor is DateTime) return valor;
  return DateTime.tryParse(valor.toString())?.toLocal();
}

/// Saudação da tela de início.
String saudacao() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Bom dia';
  if (h < 18) return 'Boa tarde';
  return 'Boa noite';
}
