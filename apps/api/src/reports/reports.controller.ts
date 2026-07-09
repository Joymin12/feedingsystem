import { Controller, Get, Param, Res, UseGuards } from "@nestjs/common";
import type { Response } from "express";
import type { CurrentUser as CurrentUserType } from "@feedingsystem/contracts";

import { CurrentUser } from "../common/decorators/current-user.decorator.js";
import { SessionAuthGuard } from "../common/guards/session-auth.guard.js";
import { ReportsService } from "./reports.service.js";

@Controller("reports/analysis-runs")
@UseGuards(SessionAuthGuard)
export class ReportsController {
  constructor(private readonly reportsService: ReportsService) {}

  @Get(":runId.pdf")
  getPdf(
    @CurrentUser() user: CurrentUserType,
    @Param("runId") runId: string,
    @Res() response: Response,
  ) {
    const buffer = this.reportsService.getPdf(user, runId);
    response.setHeader("Content-Type", "application/pdf");
    response.setHeader("Content-Disposition", `attachment; filename="${runId}.pdf"`);
    response.send(buffer);
  }

  @Get(":runId.xlsx")
  getXlsx(
    @CurrentUser() user: CurrentUserType,
    @Param("runId") runId: string,
    @Res() response: Response,
  ) {
    const buffer = this.reportsService.getXlsx(user, runId);
    response.setHeader(
      "Content-Type",
      "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    );
    response.setHeader("Content-Disposition", `attachment; filename="${runId}.xlsx"`);
    response.send(buffer);
  }
}
