import { Body, Controller, Get, Inject, Post, Query } from "@nestjs/common";

import { RecordUsageDto } from "./usage.dto.js";
import { UsageDatabase } from "./usage.database.js";

@Controller("ingredient-usage")
export class UsageController {
  constructor(@Inject(UsageDatabase) private readonly db: UsageDatabase) {}

  /**
   * 사용 중인 원료를 기록한다.
   * 앱은 배합을 분석할 때 원료 목록만 보내고, 투입량은 보내지 않는다.
   */
  @Post()
  record(@Body() body: RecordUsageDto) {
    const saved = this.db.record(body.farmKey, body.stage, body.ingredients);
    return { saved };
  }

  /** 원료별 사용 농가 수. 누적 데이터의 첫 활용. */
  @Get("stats")
  stats(@Query("limit") limit?: string) {
    const parsed = Number(limit);
    return {
      summary: this.db.summary(),
      items: this.db.stats(Number.isFinite(parsed) && parsed > 0 ? parsed : 30),
    };
  }
}
