import { Module } from "@nestjs/common";

import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { DataModule } from "../data/data.module.js";
import { AuthController } from "./auth.controller.js";
import { AuthService } from "./auth.service.js";

@Module({
  imports: [DataModule],
  controllers: [AuthController],
  providers: [AuthService, SessionAuthGuard],
  exports: [AuthService],
})
export class AuthModule {}
