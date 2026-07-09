import { Module } from "@nestjs/common";

import { AuthModule } from "./auth/auth.module.js";
import { AnalysisRunsModule } from "./analysis-runs/analysis-runs.module.js";
import { DataModule } from "./data/data.module.js";
import { FarmsModule } from "./farms/farms.module.js";
import { FormulasModule } from "./formulas/formulas.module.js";
import { IngredientsModule } from "./ingredients/ingredients.module.js";
import { RecommendationsModule } from "./recommendations/recommendations.module.js";
import { ReportsModule } from "./reports/reports.module.js";

@Module({
  imports: [
    DataModule,
    AuthModule,
    FarmsModule,
    IngredientsModule,
    FormulasModule,
    AnalysisRunsModule,
    RecommendationsModule,
    ReportsModule,
  ],
})
export class AppModule {}
