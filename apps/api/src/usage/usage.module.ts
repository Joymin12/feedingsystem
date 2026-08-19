import { Module } from "@nestjs/common";

import { UsageController } from "./usage.controller.js";
import { UsageDatabase } from "./usage.database.js";

@Module({
  controllers: [UsageController],
  providers: [UsageDatabase],
})
export class UsageModule {}
