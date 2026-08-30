import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

/// No Android/iOS o banco é um arquivo no diretório privado do app.
///
/// Aqui não existe a limpeza automática que o Safari faz no IndexedDB de um
/// PWA — os dados só somem se o usuário desinstalar o app.
Future<Database> abrirBanco() async {
  final pasta = await getApplicationDocumentsDirectory();
  return databaseFactoryIo.openDatabase(p.join(pasta.path, 'bipa.db'));
}
