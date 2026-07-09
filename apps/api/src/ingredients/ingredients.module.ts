import { Module } from "@nestjs/common";

import { AuthModule } from "../auth/auth.module.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { DataModule } from "../data/data.module.js";
import { IngredientsController } from "./ingredients.controller.js";
import { IngredientsService } from "./ingredients.service.js";

@Module({
  imports: [AuthModule, DataModule],
  controllers: [IngredientsController],
  providers: [IngredientsService, SessionAuthGuard],
})
export class IngredientsModule {}
