import { Module } from "@nestjs/common";

import { AuthModule } from "../auth/auth.module.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { AnalysisRunsController } from "./analysis-runs.controller.js";
import { AnalysisRunsService } from "./analysis-runs.service.js";

@Module({
  imports: [AuthModule],
  controllers: [AnalysisRunsController],
  providers: [AnalysisRunsService, SessionAuthGuard],
})
export class AnalysisRunsModule {}
