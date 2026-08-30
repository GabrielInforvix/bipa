import 'package:sembast_web/sembast_web.dart';

/// Na web o sembast grava em IndexedDB — o único armazenamento do navegador
/// com espaço para a lista inteira.
Future<Database> abrirBanco() => databaseFactoryWeb.openDatabase('bipa.db');
