import { Module } from "@nestjs/common";

import { ExplanationsController } from "./explanations.controller.js";
import { ExplanationsService } from "./explanations.service.js";
import { GeminiClient } from "./gemini.client.js";

@Module({
  controllers: [ExplanationsController],
  providers: [ExplanationsService, GeminiClient],
})
export class ExplanationsModule {}
