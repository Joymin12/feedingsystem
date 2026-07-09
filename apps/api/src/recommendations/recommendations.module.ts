import { Module } from "@nestjs/common";

import { AuthModule } from "../auth/auth.module.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { RecommendationsController } from "./recommendations.controller.js";
import { RecommendationsService } from "./recommendations.service.js";

@Module({
  imports: [AuthModule],
  controllers: [RecommendationsController],
  providers: [RecommendationsService, SessionAuthGuard],
})
export class RecommendationsModule {}
