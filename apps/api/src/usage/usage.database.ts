import { Injectable, Logger, OnModuleInit } from "@nestjs/common";
import { DatabaseSync } from "node:sqlite";
import { mkdirSync } from "node:fs";
import { dirname, resolve } from "node:path";

/**
 * 원료 사용 기록 저장소.
 *
 * 여기 저장하는 것은 "어떤 농가가 어떤 원료를 쓰고 있는가" 뿐이다.
 * 투입량(kg)과 배합 비율은 저장하지 않는다. 배합비는 농가가 쌓아온 노하우이고,
 * 서버가 그것까지 가져가면 앱을 쓸 이유가 사라진다.
 *
 * 배합 전체가 서버에 남는 경우는 하나뿐이다. 사용자가 커뮤니티에 직접 올릴 때.
 * 그때는 사용자가 공개를 선택한 것이므로 성격이 다르다.
 *
 * 저장소는 파일 기반 SQLite다. 별도 DB 서버 없이 동작하고,
 * 스키마와 질의는 표준 SQL이라 나중에 PostgreSQL로 옮길 때 그대로 쓸 수 있다.
 */
@Injectable()
export class UsageDatabase implements OnModuleInit {
  private readonly logger = new Logger(UsageDatabase.name);
  private db!: DatabaseSync;

  onModuleInit(): void {
    const path = process.env.USAGE_DB_PATH
      ? resolve(process.env.USAGE_DB_PATH)
      : resolve(process.cwd(), "data/usage.db");

    mkdirSync(dirname(path), { recursive: true });
    this.db = new DatabaseSync(path);

    // 같은 농가가 같은 원료를 여러 번 보내도 한 줄만 남는다.
    // 우리가 알고 싶은 것은 "쓰고 있는가"이지 "몇 번 보냈는가"가 아니다.
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS ingredient_usage (
        farm_key        TEXT NOT NULL,
        ingredient_id   TEXT NOT NULL,
        ingredient_name TEXT NOT NULL,
        stage           TEXT,
        first_seen_at   TEXT NOT NULL,
        last_seen_at    TEXT NOT NULL,
        PRIMARY KEY (farm_key, ingredient_id)
      )
    `);
    this.db.exec(
      `CREATE INDEX IF NOT EXISTS idx_usage_ingredient ON ingredient_usage(ingredient_id)`,
    );

    this.logger.log(`원료 사용 기록 DB 연결: ${path}`);
  }

  /**
   * 사용 중인 원료를 기록한다.
   * 이미 있으면 마지막 확인 시각만 갱신한다.
   */
  record(
    farmKey: string,
    stage: string | undefined,
    ingredients: { id: string; name: string }[],
  ): number {
    const now = new Date().toISOString();
    const statement = this.db.prepare(`
      INSERT INTO ingredient_usage
        (farm_key, ingredient_id, ingredient_name, stage, first_seen_at, last_seen_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ON CONFLICT(farm_key, ingredient_id) DO UPDATE SET
        last_seen_at = excluded.last_seen_at,
        ingredient_name = excluded.ingredient_name,
        stage = excluded.stage
    `);

    let saved = 0;
    for (const item of ingredients) {
      if (!item.id || !item.name) continue;
      statement.run(farmKey, item.id, item.name, stage ?? null, now, now);
      saved += 1;
    }
    return saved;
  }

  /**
   * 원료별로 몇 농가가 쓰고 있는지. 누적 데이터의 첫 활용 형태다.
   */
  stats(limit = 30): { ingredientId: string; name: string; farmCount: number }[] {
    const rows = this.db
      .prepare(`
        SELECT ingredient_id AS ingredientId,
               ingredient_name AS name,
               COUNT(DISTINCT farm_key) AS farmCount
        FROM ingredient_usage
        GROUP BY ingredient_id
        ORDER BY farmCount DESC, name ASC
        LIMIT ?
      `)
      .all(limit) as { ingredientId: string; name: string; farmCount: number }[];
    return rows;
  }

  /** 전체 규모. 화면에 "지금까지 몇 농가, 몇 종"을 보여줄 때 쓴다. */
  summary(): { farmCount: number; ingredientCount: number; rowCount: number } {
    const row = this.db
      .prepare(`
        SELECT COUNT(DISTINCT farm_key)      AS farmCount,
               COUNT(DISTINCT ingredient_id) AS ingredientCount,
               COUNT(*)                      AS rowCount
        FROM ingredient_usage
      `)
      .get() as { farmCount: number; ingredientCount: number; rowCount: number };
    return row;
  }
}
