import { Module } from "@nestjs/common";
import { MockTmrStore } from "./store";
import { TmrController } from "./tmr.controller";
import { TmrService } from "./tmr.service";

@Module({
  controllers: [TmrController],
  providers: [MockTmrStore, TmrService]
})
export class AppModule {}
