import { Injectable } from "@nestjs/common";
import type { CurrentUser } from "@feedingsystem/contracts";

import { MockDatabaseService } from "../data/mock-database.service.js";
import { buildPdfReport, buildXlsxReport } from "./report-builder.js";

@Injectable()
export class ReportsService {
  constructor(private readonly db: MockDatabaseService) {}

  getPdf(user: CurrentUser, runId: string) {
    const run = this.db.getAnalysisRun(user, runId);
    this.db.recordReportDownload(user, runId, "pdf");
    return buildPdfReport(run);
  }

  getXlsx(user: CurrentUser, runId: string) {
    const run = this.db.getAnalysisRun(user, runId);
    this.db.recordReportDownload(user, runId, "xlsx");
    return buildXlsxReport(run);
  }
}
