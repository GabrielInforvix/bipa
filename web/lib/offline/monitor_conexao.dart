import 'monitor_conexao_io.dart'
    if (dart.library.js_interop) 'monitor_conexao_web.dart' as plataforma;

bool conexaoAtiva() => plataforma.onlineAgora();

void observarConexao(void Function(bool online) aoMudar) =>
    plataforma.escutarConexao(aoMudar);
