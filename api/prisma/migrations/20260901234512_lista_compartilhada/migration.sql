-- AlterTable
ALTER TABLE "lista_itens" ADD COLUMN     "comprado_por_id" UUID,
ADD COLUMN     "criado_por_id" UUID;

-- CreateTable
CREATE TABLE "lista_membros" (
    "id" UUID NOT NULL,
    "lista_id" UUID NOT NULL,
    "usuario_id" UUID NOT NULL,
    "entrou_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "lista_membros_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "convites" (
    "id" UUID NOT NULL,
    "lista_id" UUID NOT NULL,
    "codigo" TEXT NOT NULL,
    "criado_por_id" UUID NOT NULL,
    "expira_em" TIMESTAMP(3) NOT NULL,
    "revogado_em" TIMESTAMP(3),
    "criado_em" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "convites_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "lista_membros_usuario_id_idx" ON "lista_membros"("usuario_id");

-- CreateIndex
CREATE UNIQUE INDEX "lista_membros_lista_id_usuario_id_key" ON "lista_membros"("lista_id", "usuario_id");

-- CreateIndex
CREATE UNIQUE INDEX "convites_codigo_key" ON "convites"("codigo");

-- AddForeignKey
ALTER TABLE "lista_itens" ADD CONSTRAINT "lista_itens_criado_por_id_fkey" FOREIGN KEY ("criado_por_id") REFERENCES "usuarios"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lista_itens" ADD CONSTRAINT "lista_itens_comprado_por_id_fkey" FOREIGN KEY ("comprado_por_id") REFERENCES "usuarios"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lista_membros" ADD CONSTRAINT "lista_membros_lista_id_fkey" FOREIGN KEY ("lista_id") REFERENCES "listas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "lista_membros" ADD CONSTRAINT "lista_membros_usuario_id_fkey" FOREIGN KEY ("usuario_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "convites" ADD CONSTRAINT "convites_lista_id_fkey" FOREIGN KEY ("lista_id") REFERENCES "listas"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "convites" ADD CONSTRAINT "convites_criado_por_id_fkey" FOREIGN KEY ("criado_por_id") REFERENCES "usuarios"("id") ON DELETE CASCADE ON UPDATE CASCADE;
