# Bipa

![CI](https://github.com/GabrielInforvix/bipa/actions/workflows/ci.yml/badge.svg)

Lista de supermercado com leitura de código de barras. Monte a lista em casa e,
no mercado, bipe os produtos para ver **o total da compra subindo em tempo
real** — antes de chegar no caixa.

Progressive Web App: roda no navegador e pode ser instalado na tela inicial do
celular como um aplicativo normal. Funciona sem internet e sincroniza sozinho
quando a conexão volta.

---

## Rodando

**Pré-requisitos:** Node 20+, Flutter 3.x, PostgreSQL 16 rodando local na
porta 5432.

```bat
copy api\.env.example api\.env
```

Ajuste a senha do Postgres em `api\.env` e rode:

```bat
setup-mercado.bat
```

Depois, no dia a dia:

```bat
start-mercado.bat
```

- App: <http://localhost:4310>
  (se a porta estiver ocupada, o Windows às vezes reserva faixas para o
  Hyper-V — nesse caso troque a porta no `start-mercado.bat`)
- API: <http://localhost:3010/api>
- Login do seed: **gabriel@bipa.local** / **bipa123**

O seed traz 33 produtos com EAN válido, 10 categorias na ordem do corredor,
3 mercados, uma compra finalizada e uma em andamento — dá para testar o app
inteiro sem cadastrar nada.

### Testando o scanner sem produto na mão

Na tela do scanner há sempre **"Digitar o código"**. Códigos do seed que valem
a pena testar:

| Código | O que acontece |
|---|---|
| `7896036098264` | Arroz Tio João — produto do catálogo, com último preço |
| `7891234567895` | Leite Italac — item que está na lista |
| `2004512043201` | **Etiqueta de balança**: preço R$ 43,20 lido do código |
| `2004512012382` | **Etiqueta de balança**: peso 1,238 kg lido do código |
| `7899999999994` | Não existe — cai no cadastro rápido |

---

## Testando no Android (APK)

O app também compila como aplicativo nativo. No Android o scanner usa o
**ML Kit** em vez da API do navegador — é a leitura boa: funciona com a
embalagem amassada, com pouca luz e sem esperar o foco assentar.

```bat
build-apk-mercado.bat
```

Sem argumento, o script detecta o IP desta máquina na rede. Para escolher outro:
`build-apk-mercado.bat http://192.168.0.10:3010/api`

Gera `bipa-arm64.apk` (~26 MB, serve qualquer celular moderno). Transfira para
o telefone e instale — o Android vai pedir para permitir "instalar de fontes
desconhecidas", o que é normal para APK fora da Play Store.

**Três coisas precisam estar certas para o app achar o servidor:**

1. A API precisa estar rodando no PC (`start-mercado.bat`).
2. Celular e PC na **mesma rede Wi-Fi**.
3. O IP do PC precisa estar liberado em
   `web/android/app/src/main/res/xml/network_security_config.xml` — o Android
   bloqueia HTTP sem TLS por padrão, e a exceção ali é só para o servidor de
   desenvolvimento. **Se o IP da sua máquina mudar, edite esse arquivo e gere
   o APK de novo.**

Se o login falhar com "sem conexão", quase sempre é o **firewall do Windows**
bloqueando a porta 3010 para a rede local. Libere-a ou desative o firewall da
rede privada durante o teste.

---

## O que já está pronto

**Entrar**
- Login e cadastro na mesma tela
- **Usar sem conta**: monta listas e faz compras só no aparelho; ao criar a
  conta depois, tudo que já existe sobe junto

**Compra**
- Modo Compra com o total como maior elemento da tela
- Scanner que não fecha a câmera entre um produto e outro
- Teclado de caixa registradora (digita `599`, vira R$ 5,99)
- Quantidade e preço por item, total calculado e congelado
- Produtos por peso (açougue, hortifrúti, frios) com R$/kg
- Produto fora da lista → compra extra, contabilizada à parte
- Orçamento com barra de gasto e marcador do estimado
- Desfazer devolve o item exatamente como estava (quantidade e preço)

**Catálogo**
- Cascata: catálogo local → etiqueta de balança → Open Food Facts → cadastro
- Cadastro rápido alimenta o catálogo global compartilhado
- Busca por texto com o histórico do próprio usuário
- **Item escrito na mão** para o que não tem código de barras ("pão na
  padaria", "gelo")
- **Editar o planejado**: quantidade, preço estimado e unidade (un/kg)
- **Ordem do corredor**: arraste as categorias para a sequência do seu
  mercado (Ajustes) — as listas passam a agrupar nessa ordem
- **Cadastrar mercado** direto na criação da lista, offline

**Depois da compra**
- Resumo com estimado × pago, economia e planejados × extras separados
- Histórico de preço por produto **e por mercado**, com gráfico e mín/máx/média
- Repetir lista (preço anterior vira só referência)
- Compartilhar pelo menu do sistema (WhatsApp etc.), com fallback de texto

**Infraestrutura**
- Offline-first: tudo funciona sem conexão e sobe depois
- Sincronização idempotente com fila inspecionável
- PWA instalável, com ícone, splash e service worker
- CI no GitHub Actions: analyze + 51 testes + build a cada push
- Autenticação JWT com refresh rotacionado

## O que ficou para depois

Comparação de preços entre supermercados, lista compartilhada entre familiares,
sugestões pelo histórico, previsão do valor da próxima compra, notificações,
apps nativos e assinatura Premium.

O modelo de dados já comporta mercados, compartilhamento e sugestões sem exigir
migração — foi projetado assim de propósito.

---

## Estrutura

```
Mercado/
├── api/                    NestJS + Prisma + PostgreSQL
│   ├── prisma/
│   │   ├── schema.prisma   Modelo de dados
│   │   └── seed.ts         Dados de exemplo
│   └── src/
│       ├── auth/           JWT, refresh rotacionado
│       ├── produtos/       Cascata de catálogo + parser de balança
│       │   └── externo/    Open Food Facts (atrás de interface)
│       ├── listas/         Regras de preço, extras e totais
│       ├── sincronizacao/  Outbox idempotente + delta por cursor
│       └── comum/          IDs e tratamento central de erros
└── web/                    Flutter Web (PWA)
    ├── android/            Projeto Android (APK)
    ├── web/                manifest, ícones, splash
    └── lib/
        ├── offline/        Banco local, fila e sincronizador
        ├── scanner/        Interface + leitor nativo (ML Kit) e web
        ├── controllers/    Estado (GetX)
        ├── models/         Tipos
        ├── pages/          Telas
        └── widget/         Componentes e paleta
```

Detalhes de arquitetura e as decisões que sustentam o código estão em
[CLAUDE.md](CLAUDE.md).

## Testes

```bat
cd api && npx jest
```

```bat
cd web && flutter test
```

**25 testes na API**: parser de etiqueta de balança (com dígito verificador de
EAN-13) e **integração da sincronização** contra Postgres de verdade —
idempotência, resolução de conflito, tombstone, isolamento entre usuários e
delta por cursor.

**26 testes no app**: a conta que aparece na tela (`TotaisLista`, teclado de
centavos) e a interação da folha de edição de item, mais a máquina de estados
do modo convidado.

Os testes da sincronização usam um banco separado (`mercado_test`), criado pelo
`setup-mercado.bat`. **Eles apagam dados** — o `DATABASE_URL_TEST` no `.env`
nunca deve apontar para o banco de desenvolvimento.

## Publicando

```bat
build-prod-mercado.bat https://seu-dominio.com.br/api
```

Gera a pasta `deploy\`. No servidor: crie o `.env` a partir do exemplo
(**trocando os segredos JWT**), rode `npx prisma migrate deploy` e suba com
`node dist/main`. Com `SERVE_WEB=true` a própria API serve o front.

> O scanner exige **HTTPS** para acessar a câmera. Em `localhost` funciona sem
> certificado; em qualquer outro domínio, não.

## Limitações conhecidas

- **Leitura de código de barras na versão web** usa a API `BarcodeDetector` do
  navegador, que existe no Chrome para Android e **não existe no Safari do
  iOS**. Onde ela falta, o app oferece digitação do código. No **APK** isso não
  se aplica: lá o leitor é o ML Kit, nativo. A troca do web por ZXing-wasm é
  uma nova implementação de `EscanerCodigoBarras`, sem tocar no resto.
- **PWA no iOS** pode ter o IndexedDB limpo após ~7 dias sem uso. Como o app é
  usado poucas vezes por mês, isso é o caso comum — por isso ele sincroniza ao
  abrir, ao voltar a conexão e ao fechar a compra.
- A cobertura do **Open Food Facts** para EAN brasileiro é baixa fora das
  grandes marcas. O catálogo colaborativo é o que resolve isso com o tempo.
