import { Global, Module } from "@nestjs/common";

import { MockDatabaseService } from "./mock-database.service.js";

@Global()
@Module({
  providers: [MockDatabaseService],
  exports: [MockDatabaseService],
})
export class DataModule {}
