import { Module } from "@nestjs/common";

import { AuthModule } from "../auth/auth.module.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { ReportsController } from "./reports.controller.js";
import { ReportsService } from "./reports.service.js";

@Module({
  imports: [AuthModule],
  controllers: [ReportsController],
  providers: [ReportsService, SessionAuthGuard],
})
export class ReportsModule {}
