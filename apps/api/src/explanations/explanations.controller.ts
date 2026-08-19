import { Body, Controller, Inject, Post } from "@nestjs/common";

import { CreateExplanationDto } from "./explanations.dto.js";
import { ExplanationsService } from "./explanations.service.js";

@Controller()
export class ExplanationsController {
  // tsx(esbuild)는 emitDecoratorMetadata를 지원하지 않아 타입만으로는 주입되지 않는다.
  // 토큰을 명시해 런타임 메타데이터에 의존하지 않게 한다.
  constructor(
    @Inject(ExplanationsService)
    private readonly explanationsService: ExplanationsService,
  ) {}

  /**
   * 엔진이 확정한 판정·교정 결과를 받아 농가용 설명 문장을 돌려준다.
   * 실패하면 4xx/5xx를 그대로 내보내고, 앱은 내장 설명으로 폴백한다.
   */
  @Post("explanations")
  create(@Body() body: CreateExplanationDto) {
    return this.explanationsService.explain(body);
  }
}
