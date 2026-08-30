import { Module } from '@nestjs/common';
import { CATALOGOS_EXTERNOS } from './externo/catalogo-externo';
import { OpenFoodFactsService } from './externo/open-food-facts.service';
import { ProdutosController } from './produtos.controller';
import { ProdutosService } from './produtos.service';

@Module({
  controllers: [ProdutosController],
  providers: [
    ProdutosService,
    OpenFoodFactsService,
    {
      // A cascata de fontes externas é montada aqui. Somar uma fonte nova
      // (Cosmos, GS1) é acrescentar um item nesta lista — o ProdutosService
      // não muda.
      provide: CATALOGOS_EXTERNOS,
      useFactory: (openFoodFacts: OpenFoodFactsService) => [openFoodFacts],
      inject: [OpenFoodFactsService],
    },
  ],
  exports: [ProdutosService],
})
export class ProdutosModule {}
