/// No Android/iOS não há um evento equivalente ao `online`/`offline` do
/// navegador sem trazer mais um plugin. O estado real vem do resultado da
/// própria sincronização, que já distingue "sem conexão" de "erro do
/// servidor" — então aqui o app começa otimista e se corrige na primeira
/// tentativa de envio.
bool onlineAgora() => true;

void escutarConexao(void Function(bool online) aoMudar) {}
