import { Module } from "@nestjs/common";

import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { AuthModule } from "../auth/auth.module.js";
import { FormulasController } from "./formulas.controller.js";
import { FormulasService } from "./formulas.service.js";

@Module({
  imports: [AuthModule],
  controllers: [FormulasController],
  providers: [FormulasService, SessionAuthGuard],
})
export class FormulasModule {}
