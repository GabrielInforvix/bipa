# Bipa — contexto do projeto

PWA de **lista de supermercado com leitura de código de barras**. A promessa
única do app é: **o total da compra sempre visível, atualizado a cada bipe**.
Todo o resto — catálogo, histórico, sincronização — existe para tornar esse
número rápido de alimentar e confiável de ler. Idioma: **pt-BR** em tudo (UI,
código, mensagens, comentários).

- **Backend:** NestJS 11 + Prisma 5 + PostgreSQL, JWT com refresh rotacionado. Pasta `api/`.
- **Frontend:** Flutter (GetX), mobile-first, offline-first. Pasta `web/` — o
  nome é histórico: o mesmo código gera o **PWA** e o **APK Android**.
- **Multi-usuário**, cada um enxerga só os próprios dados. O **catálogo de
  produtos é global e compartilhado** entre todos.

## Como rodar

Pré-requisitos: Node 20+, Flutter 3.x e **PostgreSQL 16 local** na porta 5432
(serviço do Windows — o projeto não usa Docker).

- **1ª vez:** `setup-mercado.bat` — cria o banco, `npm install`,
  `prisma migrate deploy`, `prisma db seed`, `flutter pub get`.
  Antes, copie `api/.env.example` para `api/.env` e ajuste a senha do Postgres.
- **Dia a dia:** `start-mercado.bat` — sobe API (`http://localhost:3010/api`) e
  front (`flutter run` no Chrome, porta **4310**) em janelas separadas.
- **APK Android:** `build-apk-mercado.bat` — detecta o IP da máquina na rede e
  gera `bipa-arm64.apk`. Ver "Android" abaixo.
- **Produção:** `build-prod-mercado.bat https://seu-dominio/api` — a URL da API
  é gravada no build do Flutter, por isso é obrigatória.

**Login do seed:** `gabriel@bipa.local` / `bipa123`.
Portas: Postgres **5432**, API **3010**, front **4310**.

## As decisões que explicam o código

Estas não são preferências de estilo — mudar qualquer uma delas quebra o app.

1. **IDs são UUID v7 gerados no cliente**, nunca autoincrement. É o que permite
   criar lista e itens offline sem remapear chave na sincronização.
2. **Dinheiro é `Decimal(12,2)`, quantidade é `Decimal(10,3)`.** Nunca `double`.
   1,238 kg de patinho é caso normal, e centavo errado no total é bug visível.
   O Prisma serializa Decimal como **String** no JSON — no Dart sempre use
   `parseDouble`/`parseDoubleOpt` de `models/parse.dart`.
3. **O preço pago fica congelado no item** (`lista_itens.total`). Alterar o
   produto depois nunca altera compras anteriores.
4. **Produto vendido por peso** (`tipoVenda = PESO`) muda o significado da tela:
   `quantidade` vira peso em kg e `precoUnitario` vira R$/kg.
5. **Extras são contabilizados à parte** (`origem = EXTRA`), mas somam no total
   geral.
6. **Exclusão é lógica** (`excluidoEm`). Sem tombstone, item apagado offline
   ressuscita na sincronização seguinte.
7. **`logado` e `temConta` são coisas diferentes.** `logado` = pode usar o app
   (inclusive como convidado); `temConta` = pode falar com o servidor. Trocar
   um pelo outro num `if` expulsa o convidado para o login, ou faz o app tentar
   sincronizar sem token. Coberto por `convidado_test.dart`.
8. **Falha de sincronização tem dois tipos.** `FalhaPermanente` (aponta para
   algo que não existe, ou para dado de outro usuário) sai da fila; qualquer
   outra volta para a próxima tentativa. Sem essa distinção o contador de
   pendentes nunca zera.

## Arquitetura

### Backend (`api/src/`)

Módulos NestJS (padrão module/controller/service + dto): `auth`, `categorias`,
`mercados`, `produtos`, `listas`, `sincronizacao`, `dashboard`, `prisma`, `comum`.

- `main.ts`: prefixo global `api`, CORS (`CORS_ORIGIN=dev` libera qualquer
  localhost), `ValidationPipe` (whitelist + transform), `FiltroDeErros` global,
  bloco `SERVE_WEB` que serve o build Flutter em produção.
- `comum/filtro-de-erros.ts`: tratamento central. **O log guarda o erro
  inteiro; a resposta devolve só uma frase em pt-BR** — nada de stack trace ou
  nome de tabela vazando para o navegador.
- Auth: bcrypt, access **15m** + refresh **60d rotacionado** (jti + hash em
  `tokens_atualizacao`). O refresh é longo porque o app é usado poucas vezes por
  mês. Guard `JwtAuthGuard`, decorator `@CurrentUser()`.
- **Cascata de produto** (`produtos.service.ts` → `buscarPorEan`), nesta ordem:
  1. catálogo local (instantâneo, cobre o caso comum)
  2. `balanca.util.ts` — EAN-13 iniciado em `2` é código interno da loja, com
     preço ou peso embutido. **Nenhuma API do mundo conhece esse código**, então
     consultar a rede aqui seria tempo jogado fora.
  3. `externo/` — Open Food Facts, atrás da interface `CatalogoExterno`.
     Somar uma fonte (Cosmos, GS1) é acrescentar um item na lista de
     `produtos.module.ts`; o service não muda.
  4. nada → o app abre o cadastro rápido.
- **Sincronização** (`sincronizacao.service.ts`) — três garantias:
  idempotência por `operation_id`, último-a-escrever-vence por registro, e
  **comprado vence não-comprado** no merge (perder item do carrinho faria o
  usuário passar no caixa com total errado).

### Frontend (`web/lib/`)

- `offline/` — **o coração do app.** `banco_local.dart` (sembast/IndexedDB),
  `fila_sincronizacao.dart` (outbox), `repositorio_listas.dart`,
  `sincronizador.dart`.
  A regra: **grava local, enfileira, devolve na hora.** A tela nunca espera a
  rede — nem para marcar comprado, nem para ver o total mudar.
  O delta chega normalizado, então `_aplicarDelta` **hidrata** os itens com o
  catálogo local; sem isso todo item vira "Item" em "Outros".
- `scanner/` — `EscanerCodigoBarras` (interface) com duas implementações:
  `EscanerNativo` (ML Kit, no APK) e `EscanerWeb` (`BarcodeDetector`, no PWA).
  A do navegador **existe no Chrome Android e não existe no Safari iOS** — por
  isso `disponivel()` é checado antes e há sempre digitação manual como saída.
  Ver "Android e web no mesmo código".
- `controllers/` — GetX com `.obs`/`Obx`. `CompraController` é o mais
  importante: resolve o bipe e registra a compra.
  **`ScannerPage` registra o `CompraController` se ele não existir** — ele só é
  criado pelo Modo Compra, e o `Get.find` direto derrubava a tela quando o
  scanner era aberto pela tela da Lista.
- **Modo convidado:** o app roda sem cadastro, guardando tudo na fila local.
  Bipar e sincronizar pedem conta (`widget/pedir_conta.dart`). Ao criar a
  conta, `_autenticar` faz **push antes do pull** — o contrário sobrescreveria
  o que a pessoa montou sem conta. O convidado não recebe categorias, então os
  itens caem em "Outros" até a primeira sincronização.
- `services/api_service.dart` — só o que exige rede (auth, EAN externo,
  histórico). **Leitura de tela sai do repositório local, não daqui.**
- `models/` — imutáveis, `fromJson`/`toJson` completos (precisam do round-trip
  para o banco local).
- `widget/` — `cores.dart` (paleta), `componentes.dart`, `teclado_preco.dart`,
  `item_lista.dart`, `grafico_precos.dart`.
- `extensions/num_extension.dart` — `.emReais`, `.emValor`, `.emQuantidade` e
  `EntradaCentavos` (o teclado de caixa registradora).

**Visual:** laranja `0xFFDC4B16` é marca e ação de bipar, e **nunca aparece em
número** — verde `0xFF0C7245` é só economia, carmim `0xFFB51F35` é só estouro.
Se o acento entrasse nos valores, o usuário perderia o semáforo justamente na
informação que mais lê. Fundo `0xFFF5F4F1`. Estado nunca é comunicado só por
cor: sempre tem ícone ou palavra junto.

**Cuidados de UI já resolvidos (não regredir):**
- `↓`/`↑` como caractere viram quadrado vazio na fonte do Flutter Web — use
  `DeltaValor` (ícone + texto).
- `Icons.barcode_reader` fica ilegível em botão — use `IconeBarras` (desenhado).
- Preço nunca usa o teclado do sistema: `TecladoPreco` + `EntradaCentavos`
  (digita `599`, vira R$ 5,99). O teclado nativo com vírgula decimal é
  inconsistente em PWA no iOS e empurra o layout.
- Rotas `/compra`, `/lista` e `/resumo` **caem numa lista padrão** quando não
  recebem argumento — senão recarregar a página trava em spinner eterno.

## Android e web no mesmo código

Três camadas não existem nas duas plataformas, e cada uma é resolvida por
**import condicional** — a escolha acontece em tempo de compilação, então o
código do navegador nunca entra no APK e vice-versa:

| Camada | Web | Android/iOS |
|---|---|---|
| `scanner/escaner.dart` | `EscanerWeb` (`BarcodeDetector`) | `EscanerNativo` (ML Kit) |
| `offline/fabrica_banco.dart` | `sembast_web` (IndexedDB) | `sembast_io` (arquivo) |
| `offline/monitor_conexao.dart` | eventos `online`/`offline` | otimista, corrige na sincronização |

Cada par tem um terceiro arquivo `*_indisponivel.dart`, usado onde nenhuma das
duas se aplica (desktop) — sem ele o import condicional não compila.

**Ao mexer no scanner, mexa na interface primeiro.** `EscanerCodigoBarras`
devolve a prévia da câmera como *widget* justamente para caber nas duas
plataformas; devolver um id de view HTML quebraria o Android.

### Android

- `android/app/src/main/AndroidManifest.xml` — permissão de câmera declarada
  com `required=false`: o app segue utilizável sem ela (digitação do código),
  e exigir câmera bloquearia a instalação sem motivo.
- `android/app/src/main/res/xml/network_security_config.xml` — o Android 9+
  bloqueia HTTP sem TLS. A exceção é aberta **só** para o IP do servidor de
  desenvolvimento. **Se o IP da máquina mudar, edite esse arquivo.** Em
  produção, com a API em HTTPS, o arquivo e a linha `networkSecurityConfig`
  podem sair.
- O `API_BASE` fica **gravado dentro do APK**. Um celular não enxerga o
  `localhost` do PC — por isso o build usa o IP da rede.

## Lista compartilhada

Convite por código curto (`convites`, multiuso, expira em 7 dias, sem sistema
de amigos); membros em `lista_membros`. As regras que sustentam:

- **Acesso é "dona OU membro"** via `comum/acesso.ts` (`minhaLista`), usado por
  listas, sincronização, dashboard e histórico. Um `if` esquecido vira
  vazamento — por isso é um helper só.
- **O motor de sincronização não mudou**: idempotência, último-vence e
  comprado-vence já eram cegos a quem é o aparelho. `compradoPorId`/
  `criadoPorId` são preenchidos pelo servidor com o usuário da operação.
- **"Excluir" vindo de membro vira sair da lista** — membro não apaga a lista
  da família (vale no endpoint e na sincronização).
- **Histórico de preços é da casa**: registro pertence a quem comprou, e a
  consulta enxerga as listas em que você é membro.
- **Pulso de 15 s**: `CompraController` sincroniza a cada 15 s quando a lista
  compartilhada está em compra (decisão aprovada; WebSocket é fase B).
- Só o dono convida/revoga/remove; membro sai sozinho. Convidado (sem conta)
  não compartilha.
- UI: `folha_compartilhar.dart`, `folha_entrar.dart`, iniciais nos itens via
  `lista.inicialDe(...)`, selo `rotuloPessoas` ("com Maria") e
  `quemEstaComprando` (compra de outro nos últimos 10 min).

## Modelo de dados (`api/prisma/schema.prisma`)

`USUARIOS`, `TOKENS_ATUALIZACAO`, `CATEGORIAS`, `PRODUTOS`, `PRODUTOS_USUARIO`,
`MERCADOS`, `LISTAS`, `LISTA_ITENS`, `LISTA_MEMBROS`, `CONVITES`,
`HISTORICO_PRECOS`, `OPERACOES_SINCRONIZACAO`.

Campos em português com `@map` snake_case + `@@map`. Pontos que importam:

- `produtos.ean` é **único** (regra 9: um EAN nunca vira produto duplicado) e
  indexado — é o caminho crítico do scanner. Produto **sem** EAN é permitido.
- `produtos` é o catálogo **global**; `produtos_usuario` guarda a
  personalização (apelido, categoria, unidade) sem sujar o catálogo de todos.
- `categorias.ordem` é a **ordem do corredor**, arrastável em `/categorias`
  (Ajustes). Reordenar também reescreve a ordem copiada nos itens das
  listas locais — sem isso o agrupamento só mudaria na próxima
  sincronização (ver `reordenarCategorias` no repositório).
- `listas.mercadoId` e `historico_precos.mercadoId` são nuláveis mas existem
  desde o início: sem mercado o histórico mistura atacado com loja de bairro.
- `historico_precos.listaItemId` é **único** — é o que torna a finalização
  idempotente e impede a média de ser distorcida por reenvio.
- `listas(usuarioId, atualizadoEm)` é o índice que sustenta o pull incremental.

## API

`POST /auth/register` · `/auth/login` · `/auth/refresh` · `/auth/logout` ·
`/auth/trocar-senha` · `GET /auth/perfil`

`GET|POST /listas` · `GET|PUT|DELETE /listas/:id` ·
`POST /listas/:id/iniciar|finalizar|repetir` ·
`POST /listas/:id/itens` · `PUT|PATCH|DELETE /listas/:id/itens/:itemId`

`GET /produtos` · `GET /produtos/ean/:ean` · `POST /produtos` ·
`PATCH /produtos/:id` · `GET /produtos/:id/historico-precos`

`GET|POST /categorias` · `PATCH /categorias/reordenar` ·
`GET|POST /mercados` · `POST|GET /sincronizacao` · `GET /dashboard/resumo`

`POST|DELETE /listas/:id/convites` · `GET /convites/:codigo` ·
`POST /convites/:codigo/aceitar` · `DELETE /listas/:id/membros/:usuarioId`

Tudo exige JWT, menos `register`/`login`/`refresh`.

## CI

`.github/workflows/ci.yml` roda em todo push/PR: API (build + jest com
Postgres 16 em service container) e Flutter (analyze + testes + build web),
em jobs independentes. Flutter fixado em 3.44.0 — a mesma versão da máquina
de desenvolvimento.

## Testes

- `cd api && npx jest`
  - `produtos/balanca.util.spec.ts` — parser de etiqueta de balança, com
    dígito verificador de EAN-13.
  - `sincronizacao/sincronizacao.service.spec.ts` — **integração contra
    Postgres de verdade** (banco `mercado_test`, via `DATABASE_URL_TEST`),
    incluindo os casos de lista compartilhada com dois usuários.
  - `convites/convites.service.spec.ts` — convite, prévia, aceite idempotente,
    revogação e permissões de remoção (integração, mesmo banco).
    É de integração de propósito: o que pode dar errado ali é a conversa com o
    banco (upsert, constraint, `atualizadoEm` do servidor), e um mock testaria
    só o meu raciocínio sobre o banco. **Esses testes apagam dados** — jamais
    aponte a variável para o banco de desenvolvimento.
- `cd web && flutter test`
  - `calculos_test.dart` — `EntradaCentavos` e `TotaisLista.calcular`. Este
    roda no aparelho quando não há conexão e precisa dar exatamente o mesmo
    número que o servidor, senão o total pisca ao sincronizar.
  - `folha_item_test.dart` — interação da edição de item (o teclado de preço
    não é o do sistema; se ele quebrar, entra um preço diferente do digitado).
  - `convidado_test.dart` — a máquina de estados do modo convidado.

> Nas asserções de moeda o espaço depois de "R$" é **U+00A0** (não separável),
> que é o que o `intl` gera. Com espaço comum o teste falha mostrando duas
> strings idênticas no terminal.

## Próximas fases (fora do escopo atual)

Fase B do compartilhamento (WebSocket, notificações, papel só-leitura) ·
comparação de preço entre mercados · sugestões pelo histórico · previsão da
próxima compra · apps nativos · assinatura Premium.
