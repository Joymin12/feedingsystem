import { Module } from "@nestjs/common";

import { DataModule } from "../data/data.module.js";
import { FarmsController } from "./farms.controller.js";
import { FarmsService } from "./farms.service.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { AuthModule } from "../auth/auth.module.js";

@Module({
  imports: [AuthModule, DataModule],
  controllers: [FarmsController],
  providers: [FarmsService, SessionAuthGuard],
})
export class FarmsModule {}
