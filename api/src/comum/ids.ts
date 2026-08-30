import { v7 as uuidv7 } from 'uuid';

/** UUID v7 — ordenável por tempo, o que mantém os índices do Postgres
 *  saudáveis mesmo com ids gerados fora do banco. O cliente gera os seus;
 *  o servidor usa esta função só quando cria algo por conta própria. */
export function novoId(): string {
  return uuidv7();
}

const RE_UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function ehUuid(valor: unknown): valor is string {
  return typeof valor === 'string' && RE_UUID.test(valor);
}
