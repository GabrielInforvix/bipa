-- CreateEnum
CREATE TYPE "PerfilUsuario" AS ENUM ('ADMIN', 'COMUM');

-- CreateEnum
CREATE TYPE "TipoVenda" AS ENUM ('UNIDADE', 'PESO');

-- CreateEnum
CREATE TYPE "StatusLista" AS ENUM ('RASCUNHO', 'EM_COMPRA', 'FINALIZADA');

-- CreateEnum
CREATE TYPE "OrigemProduto" AS ENUM ('CATALOGO', 'OPEN_FOOD_FACTS', 'MANUAL', 'BALANCA');

-- CreateEnum
CREATE TYPE "OrigemItem" AS ENUM ('PLANEJADO', 'EXTRA');

-- CreateTable
CREATE TABLE "usuarios" (
    "id" UUID NOT NULL,
    "nome" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "senha_hash" TEXT NOT NULL,
    "perfil" "PerfilUsuario" NOT NULL DEFAULT 'COMUM',
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "usuarios_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "tokens_atualizacao" (
    "id" UUID NOT NULL,
    "jti" TEXT NOT NULL,
    "usuario_id" UUID NOT NULL,
    "token_hash" TEXT NOT NULL,
    "expira_em" TIMESTAMP(3) NOT NULL,
    "revogado_em" TIMESTAMP(3),
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "tokens_atualizacao_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "categorias" (
    "id" UUID NOT NULL,
    "nome" TEXT NOT NULL,
    "icone" TEXT,
    "ordem" INTEGER NOT NULL DEFAULT 0,
    "usuario_id" UUID,
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "categorias_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "produtos" (
    "id" UUID NOT NULL,
    "ean" TEXT,
    "nome" TEXT NOT NULL,
    "marca" TEXT,
    "imagem_url" TEXT,
    "tipo_venda" "TipoVenda" NOT NULL DEFAULT 'UNIDADE',
    "unidade" TEXT NOT NULL DEFAULT 'un',
    "categoria_id" UUID,
    "origem" "OrigemProduto" NOT NULL DEFAULT 'MANUAL',
    "confirmacoes" INTEGER NOT NULL DEFAULT 0,
    "criado_por_id" UUID,
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "produtos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "produtos_usuario" (
    "id" UUID NOT NULL,
    "usuario_id" UUID NOT NULL,
    "produto_id" UUID NOT NULL,
    "apelido" TEXT,
    "categoria_id" UUID,
    "unidade_preferida" TEXT,
    "favorito" BOOLEAN NOT NULL DEFAULT false,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "produtos_usuario_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "mercados" (
    "id" UUID NOT NULL,
    "usuario_id" UUID NOT NULL,
    "nome" TEXT NOT NULL,
    "cidade" TEXT,
    "ativo" BOOLEAN NOT NULL DEFAULT true,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "mercados_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "listas" (
    "id" UUID NOT NULL,
    "usuario_id" UUID NOT NULL,
    "nome" TEXT NOT NULL,
    "data" DATE NOT NULL,
    "observacao" TEXT,
    "orcamento" DECIMAL(12,2),
    "mercado_id" UUID,
    "status" "StatusLista" NOT NULL DEFAULT 'RASCUNHO',
    "finalizada_em" TIMESTAMP(3),
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL,
    "excluido_em" TIMESTAMP(3),

    CONSTRAINT "listas_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "lista_itens" (
    "id" UUID NOT NULL,
    "lista_id" UUID NOT NULL,
    "produto_id" UUID,
    "nome_livre" TEXT,
    "categoria_id" UUID,
    "ordem" INTEGER NOT NULL DEFAULT 0,
    "origem" "OrigemItem" NOT NULL DEFAULT 'PLANEJADO',
    "unidade" TEXT NOT NULL DEFAULT 'un',
    "quantidade_planejada" DECIMAL(10,3) NOT NULL DEFAULT 1,
    "preco_estimado" DECIMAL(12,2),
    "comprado" BOOLEAN NOT NULL DEFAULT false,
    "quantidade" DECIMAL(10,3),
    "preco_unitario" DECIMAL(12,2),
    "total" DECIMAL(12,2),
    "comprado_em" TIMESTAMP(3),
    "observacao" TEXT,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "atualizado_em" TIMESTAMP(3) NOT NULL,
    "excluido_em" TIMESTAMP(3),

    CONSTRAINT "lista_itens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "historico_precos" (
    "id" UUID NOT NULL,
    "usuario_id" UUID NOT NULL,
    "produto_id" UUID NOT NULL,
    "mercado_id" UUID,
    "lista_item_id" UUID,
    "preco" DECIMAL(12,2) NOT NULL,
    "quantidade" DECIMAL(10,3) NOT NULL,
    "total" DECIMAL(12,2) NOT NULL,
    "data" DATE NOT NULL,
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "historico_precos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "operacoes_sincronizacao" (
    "id" UUID NOT NULL,
    "usuario_id" UUID NOT NULL,
    "entidade" TEXT NOT NULL,
    "entidade_id" UUID NOT NULL,
    "acao" TEXT NOT NULL,
    "aplicada_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "operacoes_sincronizacao_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "usuarios_email_key" ON "usuarios"("email");

-- CreateIndex
CREATE UNIQUE INDEX "tokens_atualizacao_jti_key" ON "tokens_atualizacao"("jti");

-- CreateIndex
CREATE INDEX "tokens_atualizacao_usuario_id_idx" ON "tokens_atualizacao"("usuario_id");

-- CreateIndex
CREATE INDEX "categorias_usuario_id_ordem_idx" ON "categorias"("usuario_id", "ordem");

-- CreateIndex
CREATE UNIQUE INDEX "categorias_usuario_id_nome_key" ON "categorias"("usuario_id", "nome");

-- CreateIndex
CREATE UNIQUE INDEX "produtos_ean_key" ON "produtos"("ean");

-- CreateIndex
CREATE INDEX "produtos_ean_idx" ON "produtos"("ean");

-- CreateIndex
CREATE INDEX "produtos_nome_idx" ON "produtos"("nome");

-- CreateIndex
CREATE UNIQUE INDEX "produtos_usuario_usuario_id_produto_id_key" ON "produtos_usuario"("usuario_id", "produto_id");

-- CreateIndex
CREATE UNIQUE INDEX "mercados_usuario_id_nome_key" ON "mercados"("usuario_id", "nome");

-- CreateIndex
CREATE INDEX "listas_usuario_id_atualizado_em_idx" ON "listas"("usuario_id", "atualizado_em");

-- CreateIndex
CREATE INDEX "listas_usuario_id_status_idx" ON "listas"("usuario_id", "status");

-- CreateIndex
CREATE INDEX "lista_itens_lista_id_idx" ON "lista_itens"("lista_id");

-- CreateIndex
CREATE INDEX "lista_itens_lista_id_comprado_idx" ON "lista_itens"("lista_id", "comprado");

-- CreateIndex
CREATE UNIQUE INDEX "historico_precos_lista_item_id_key" ON "historico_precos"("lista_item_id");

-- CreateIndex
CREATE INDEX "historico_precos_usuario_id_produto_id_data_idx" ON "historico_precos"("usuario_id", "produto_id", "data");

-- CreateIndex
CREATE INDEX "operacoes_sincronizacao_usuario_id_aplicada_em_idx" ON "operacoes_sincronizacao"("usuario_id", "aplicada_em");

-- AddForeignKey
ALTER TABLE "tokens_atualizacao" ADD CONSTRAINT "tokens_atualizacao_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "categorias" ADD CONSTRAINT "categorias_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produtos" ADD CONSTRAINT "produtos_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "categorias"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produtos" ADD CONSTRAINT "produtos_criado_por_id_fkey" FOREIGN KEY ("criado_por_id") REFERENCES "usuarios"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produtos_usuario" ADD CONSTRAINT "produtos_usuario_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produtos_usuario" ADD CONSTRAINT "produtos_usuario_produto_id_fkey" FOREIGN KEY ("produto_id") REFERENCES "produtos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "produtos_usuario" ADD CONSTRAINT "produtos_usuario_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "categorias"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mercados" ADD CONSTRAINT "mercados_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "listas" ADD CONSTRAINT "listas_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "listas" ADD CONSTRAINT "listas_mercado_id_fkey" FOREIGN KEY ("mercado_id") REFERENCES "mercados"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lista_itens" ADD CONSTRAINT "lista_itens_lista_id_fkey" FOREIGN KEY ("lista_id") REFERENCES "listas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lista_itens" ADD CONSTRAINT "lista_itens_produto_id_fkey" FOREIGN KEY ("produto_id") REFERENCES "produtos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lista_itens" ADD CONSTRAINT "lista_itens_categoria_id_fkey" FOREIGN KEY ("categoria_id") REFERENCES "categorias"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "historico_precos" ADD CONSTRAINT "historico_precos_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "historico_precos" ADD CONSTRAINT "historico_precos_produto_id_fkey" FOREIGN KEY ("produto_id") REFERENCES "produtos"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "historico_precos" ADD CONSTRAINT "historico_precos_mercado_id_fkey" FOREIGN KEY ("mercado_id") REFERENCES "mercados"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "historico_precos" ADD CONSTRAINT "historico_precos_lista_item_id_fkey" FOREIGN KEY ("lista_item_id") REFERENCES "lista_itens"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "operacoes_sincronizacao" ADD CONSTRAINT "operacoes_sincronizacao_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;
