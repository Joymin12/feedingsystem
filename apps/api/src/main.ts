import "reflect-metadata";

import { ValidationPipe } from "@nestjs/common";
import { NestFactory } from "@nestjs/core";
import cookieParser from "cookie-parser";

import { AppModule } from "./app.module.js";
import { AllExceptionsFilter } from "./common/http-exception.filter.js";

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix("v1");
  app.use(cookieParser());
  app.enableCors({
    credentials: true,
    origin: true,
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());

  const port = Number(process.env.PORT ?? 3001);
  await app.listen(port);
}

void bootstrap();
