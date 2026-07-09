CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TYPE user_role_enum AS ENUM ('owner', 'member');
CREATE TYPE storage_level_enum AS ENUM ('low', 'medium', 'high');
CREATE TYPE wet_feed_policy_enum AS ENUM ('allowed', 'seasonal', 'avoid');
CREATE TYPE objective_enum AS ENUM ('growth', 'cost_reduction', 'moisture_support', 'stability_first');
CREATE TYPE formula_status_enum AS ENUM ('draft', 'active', 'archived');
CREATE TYPE ingredient_category_enum AS ENUM ('energy', 'protein', 'roughage', 'byproduct', 'mineral', 'supplement');
CREATE TYPE stage_enum AS ENUM ('growing_early', 'growing_late', 'fattening_early', 'fattening_mid', 'fattening_late', 'breeding');
CREATE TYPE price_source_enum AS ENUM ('farm_setting', 'manual_override', 'market_default');
CREATE TYPE nutrient_status_enum AS ENUM ('deficient', 'adequate', 'excess');
CREATE TYPE action_type_enum AS ENUM ('add', 'reduce', 'replace', 'remove');
CREATE TYPE preference_type_enum AS ENUM ('preferred', 'avoided');
CREATE TYPE member_status_enum AS ENUM ('active', 'invited');
CREATE TYPE warning_severity_enum AS ENUM ('info', 'warning', 'critical');
CREATE TYPE analysis_mode_enum AS ENUM ('formula', 'adhoc');
CREATE TYPE nfc_source_enum AS ENUM ('api', 'derived');
CREATE TYPE audit_event_type_enum AS ENUM (
  'formula_created',
  'formula_updated',
  'analysis_run_created',
  'recommendation_memo_created',
  'report_pdf_downloaded',
  'report_xlsx_downloaded',
  'farm_profile_updated',
  'farm_member_invited',
  'farm_ingredient_setting_updated'
);

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION prevent_mutation()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'append-only table: mutation is not allowed';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION protect_ingredient_nutrition_version()
RETURNS TRIGGER AS $$
BEGIN
  IF
    OLD.ingredient_id IS DISTINCT FROM NEW.ingredient_id OR
    OLD.moisture_pct IS DISTINCT FROM NEW.moisture_pct OR
    OLD.dm_pct IS DISTINCT FROM NEW.dm_pct OR
    OLD.ash_pct_dm IS DISTINCT FROM NEW.ash_pct_dm OR
    OLD.cp_pct_dm IS DISTINCT FROM NEW.cp_pct_dm OR
    OLD.tdn_pct_dm IS DISTINCT FROM NEW.tdn_pct_dm OR
    OLD.ndf_pct_dm IS DISTINCT FROM NEW.ndf_pct_dm OR
    OLD.adf_pct_dm IS DISTINCT FROM NEW.adf_pct_dm OR
    OLD.nfc_pct_dm IS DISTINCT FROM NEW.nfc_pct_dm OR
    OLD.ee_pct_dm IS DISTINCT FROM NEW.ee_pct_dm OR
    OLD.ca_pct_dm IS DISTINCT FROM NEW.ca_pct_dm OR
    OLD.p_pct_dm IS DISTINCT FROM NEW.p_pct_dm OR
    OLD.nfc_source IS DISTINCT FROM NEW.nfc_source OR
    OLD.source IS DISTINCT FROM NEW.source OR
    OLD.source_version IS DISTINCT FROM NEW.source_version OR
    OLD.analyzed_at IS DISTINCT FROM NEW.analyzed_at OR
    OLD.trust_level IS DISTINCT FROM NEW.trust_level
  THEN
    RAISE EXCEPTION 'ingredient nutrition version rows are immutable except is_current';
  END IF;

  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE,
  password_hash text NOT NULL,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE farms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE farm_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL REFERENCES farms(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  role user_role_enum NOT NULL,
  status member_status_enum NOT NULL DEFAULT 'active',
  invited_by uuid REFERENCES users(id) ON DELETE RESTRICT,
  invited_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT farm_members_unique UNIQUE (farm_id, user_id)
);

CREATE TABLE farm_profiles (
  farm_id uuid PRIMARY KEY REFERENCES farms(id) ON DELETE CASCADE,
  storage_level storage_level_enum NOT NULL DEFAULT 'medium',
  wet_feed_policy wet_feed_policy_enum NOT NULL DEFAULT 'allowed',
  cost_priority smallint NOT NULL DEFAULT 3 CHECK (cost_priority BETWEEN 1 AND 5),
  stability_priority smallint NOT NULL DEFAULT 3 CHECK (stability_priority BETWEEN 1 AND 5),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ingredients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  name_ko text NOT NULL UNIQUE,
  category ingredient_category_enum NOT NULL,
  default_price_krw_per_kg numeric(12,2) NOT NULL CHECK (default_price_krw_per_kg >= 0),
  description text NOT NULL DEFAULT '',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE ingredient_nutrition_versions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ingredient_id uuid NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  moisture_pct numeric(6,2) NOT NULL CHECK (moisture_pct >= 0 AND moisture_pct <= 100),
  dm_pct numeric(6,2) NOT NULL CHECK (dm_pct >= 0 AND dm_pct <= 100),
  ash_pct_dm numeric(6,2) NOT NULL CHECK (ash_pct_dm >= 0 AND ash_pct_dm <= 100),
  cp_pct_dm numeric(6,2) NOT NULL CHECK (cp_pct_dm >= 0 AND cp_pct_dm <= 100),
  tdn_pct_dm numeric(6,2) NOT NULL CHECK (tdn_pct_dm >= 0 AND tdn_pct_dm <= 100),
  ndf_pct_dm numeric(6,2) NOT NULL CHECK (ndf_pct_dm >= 0 AND ndf_pct_dm <= 100),
  adf_pct_dm numeric(6,2) NOT NULL CHECK (adf_pct_dm >= 0 AND adf_pct_dm <= 100),
  nfc_pct_dm numeric(6,2) NOT NULL CHECK (nfc_pct_dm >= 0 AND nfc_pct_dm <= 100),
  ee_pct_dm numeric(6,2) NOT NULL CHECK (ee_pct_dm >= 0 AND ee_pct_dm <= 100),
  ca_pct_dm numeric(6,2) NOT NULL CHECK (ca_pct_dm >= 0 AND ca_pct_dm <= 100),
  p_pct_dm numeric(6,2) NOT NULL CHECK (p_pct_dm >= 0 AND p_pct_dm <= 100),
  nfc_source nfc_source_enum NOT NULL DEFAULT 'api',
  source text NOT NULL,
  source_version text NOT NULL,
  analyzed_at date NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  trust_level text NOT NULL,
  is_current boolean NOT NULL DEFAULT false,
  CONSTRAINT ingredient_nutrition_versions_moisture_dm_consistency CHECK (
    abs((100 - moisture_pct) - dm_pct) <= 0.5
  ),
  CONSTRAINT ingredient_nutrition_versions_unique UNIQUE (ingredient_id, source_version, analyzed_at)
);

CREATE UNIQUE INDEX ingredient_nutrition_versions_current_unique
ON ingredient_nutrition_versions (ingredient_id)
WHERE is_current = true;

CREATE TABLE ingredient_ai_profiles (
  ingredient_id uuid PRIMARY KEY REFERENCES ingredients(id) ON DELETE CASCADE,
  definition text NOT NULL DEFAULT '',
  benefits text[] NOT NULL DEFAULT '{}',
  cautions text[] NOT NULL DEFAULT '{}',
  storage_note text NOT NULL DEFAULT '',
  palatability_note text NOT NULL DEFAULT '',
  recommended_stage_notes text[] NOT NULL DEFAULT '{}',
  tags jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE farm_ingredient_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  ingredient_id uuid NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  is_enabled boolean NOT NULL DEFAULT true,
  is_banned boolean NOT NULL DEFAULT false,
  custom_price_krw_per_kg numeric(12,2) CHECK (custom_price_krw_per_kg >= 0),
  price_source price_source_enum NOT NULL DEFAULT 'market_default',
  inventory_kg numeric(12,2) CHECK (inventory_kg >= 0),
  max_as_fed_kg_per_head_day numeric(10,3) CHECK (max_as_fed_kg_per_head_day >= 0),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT farm_ingredient_settings_unique UNIQUE (farm_id, ingredient_id)
);

CREATE TABLE farm_ingredient_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  ingredient_id uuid NOT NULL REFERENCES ingredients(id) ON DELETE CASCADE,
  preference_type preference_type_enum NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT farm_ingredient_preferences_unique UNIQUE (farm_id, ingredient_id, preference_type)
);

CREATE TABLE requirement_profiles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stage stage_enum NOT NULL,
  min_weight_kg numeric(8,2) NOT NULL CHECK (min_weight_kg >= 0),
  max_weight_kg numeric(8,2) NOT NULL CHECK (max_weight_kg >= min_weight_kg),
  min_adg numeric(6,3) CHECK (min_adg >= 0),
  max_adg numeric(6,3) CHECK (max_adg >= 0),
  target_cp_pct_dm numeric(6,2) NOT NULL CHECK (target_cp_pct_dm >= 0),
  target_tdn_pct_dm numeric(6,2) NOT NULL CHECK (target_tdn_pct_dm >= 0),
  target_ndf_min_pct_dm numeric(6,2) NOT NULL CHECK (target_ndf_min_pct_dm >= 0),
  target_ndf_max_pct_dm numeric(6,2) NOT NULL CHECK (target_ndf_max_pct_dm >= target_ndf_min_pct_dm),
  target_adf_min_pct_dm numeric(6,2) NOT NULL CHECK (target_adf_min_pct_dm >= 0),
  target_adf_max_pct_dm numeric(6,2) NOT NULL CHECK (target_adf_max_pct_dm >= target_adf_min_pct_dm),
  target_ca_pct_dm numeric(6,2) NOT NULL CHECK (target_ca_pct_dm >= 0),
  target_p_pct_dm numeric(6,2) NOT NULL CHECK (target_p_pct_dm >= 0),
  version text NOT NULL,
  is_current boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT requirement_profiles_unique UNIQUE (stage, min_weight_kg, max_weight_kg, version)
);

CREATE TABLE formulas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  name text NOT NULL,
  stage stage_enum NOT NULL,
  avg_weight_kg numeric(8,2) NOT NULL CHECK (avg_weight_kg >= 0),
  head_count integer NOT NULL CHECK (head_count > 0),
  objective objective_enum NOT NULL,
  target_adg numeric(6,3) CHECK (target_adg >= 0),
  status formula_status_enum NOT NULL DEFAULT 'draft',
  notes text,
  created_by uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  updated_by uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT formulas_name_unique UNIQUE (farm_id, name),
  CONSTRAINT formulas_id_farm_unique UNIQUE (id, farm_id)
);

CREATE TABLE formula_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  formula_id uuid NOT NULL,
  ingredient_id uuid NOT NULL REFERENCES ingredients(id) ON DELETE RESTRICT,
  as_fed_kg_per_head_day numeric(10,3) NOT NULL CHECK (as_fed_kg_per_head_day >= 0),
  price_override_krw_per_kg numeric(12,2) CHECK (price_override_krw_per_kg >= 0),
  price_source price_source_enum NOT NULL DEFAULT 'market_default',
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT formula_items_unique UNIQUE (formula_id, ingredient_id),
  CONSTRAINT formula_items_formula_farm_fk FOREIGN KEY (formula_id, farm_id) REFERENCES formulas(id, farm_id) ON DELETE CASCADE
);

CREATE TABLE analysis_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  formula_id uuid,
  mode analysis_mode_enum NOT NULL,
  stage stage_enum NOT NULL,
  avg_weight_kg numeric(8,2) NOT NULL CHECK (avg_weight_kg >= 0),
  head_count integer NOT NULL CHECK (head_count > 0),
  objective objective_enum NOT NULL,
  target_adg numeric(6,3) CHECK (target_adg >= 0),
  input_snapshot jsonb NOT NULL,
  total_as_fed_kg numeric(12,3) NOT NULL CHECK (total_as_fed_kg >= 0),
  total_dm_kg numeric(12,3) NOT NULL CHECK (total_dm_kg >= 0),
  moisture_pct numeric(6,2) NOT NULL CHECK (moisture_pct >= 0 AND moisture_pct <= 100),
  cp_pct_dm numeric(6,2) NOT NULL CHECK (cp_pct_dm >= 0),
  tdn_pct_dm numeric(6,2) NOT NULL CHECK (tdn_pct_dm >= 0),
  ndf_pct_dm numeric(6,2) NOT NULL CHECK (ndf_pct_dm >= 0),
  adf_pct_dm numeric(6,2) NOT NULL CHECK (adf_pct_dm >= 0),
  nfc_pct_dm numeric(6,2) NOT NULL CHECK (nfc_pct_dm >= 0),
  ee_pct_dm numeric(6,2) NOT NULL CHECK (ee_pct_dm >= 0),
  ca_pct_dm numeric(6,2) NOT NULL CHECK (ca_pct_dm >= 0),
  p_pct_dm numeric(6,2) NOT NULL CHECK (p_pct_dm >= 0),
  ca_p_ratio numeric(8,3) NOT NULL CHECK (ca_p_ratio >= 0),
  cost_per_head_day numeric(12,2) NOT NULL CHECK (cost_per_head_day >= 0),
  cost_per_kg numeric(12,2) NOT NULL CHECK (cost_per_kg >= 0),
  warnings jsonb NOT NULL DEFAULT '[]'::jsonb,
  status_cp nutrient_status_enum NOT NULL,
  status_tdn nutrient_status_enum NOT NULL,
  status_ndf nutrient_status_enum NOT NULL,
  status_adf nutrient_status_enum NOT NULL,
  status_ca nutrient_status_enum NOT NULL,
  status_p nutrient_status_enum NOT NULL,
  status_ca_p_ratio nutrient_status_enum NOT NULL,
  status_moisture nutrient_status_enum NOT NULL,
  target_cp_pct_dm numeric(6,2) NOT NULL CHECK (target_cp_pct_dm >= 0),
  target_tdn_pct_dm numeric(6,2) NOT NULL CHECK (target_tdn_pct_dm >= 0),
  target_ndf_min_pct_dm numeric(6,2) NOT NULL CHECK (target_ndf_min_pct_dm >= 0),
  target_ndf_max_pct_dm numeric(6,2) NOT NULL CHECK (target_ndf_max_pct_dm >= target_ndf_min_pct_dm),
  target_adf_min_pct_dm numeric(6,2) NOT NULL CHECK (target_adf_min_pct_dm >= 0),
  target_adf_max_pct_dm numeric(6,2) NOT NULL CHECK (target_adf_max_pct_dm >= target_adf_min_pct_dm),
  target_ca_pct_dm numeric(6,2) NOT NULL CHECK (target_ca_pct_dm >= 0),
  target_p_pct_dm numeric(6,2) NOT NULL CHECK (target_p_pct_dm >= 0),
  created_by uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT analysis_runs_id_farm_unique UNIQUE (id, farm_id),
  CONSTRAINT analysis_runs_formula_farm_fk FOREIGN KEY (formula_id, farm_id) REFERENCES formulas(id, farm_id) ON DELETE SET NULL,
  CONSTRAINT analysis_runs_input_snapshot_shape CHECK (
    jsonb_typeof(input_snapshot) = 'object'
    AND input_snapshot ? 'stage'
    AND input_snapshot ? 'avg_weight_kg'
    AND input_snapshot ? 'head_count'
    AND input_snapshot ? 'objective'
    AND input_snapshot ? 'season_code'
    AND input_snapshot ? 'items'
    AND input_snapshot ? 'farm_profile_summary'
    AND input_snapshot ? 'banned_ingredient_ids'
    AND input_snapshot ? 'inventory_items'
  )
);

CREATE INDEX analysis_runs_farm_created_at_idx ON analysis_runs (farm_id, created_at DESC);

CREATE TABLE recommendations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid NOT NULL REFERENCES farms(id) ON DELETE CASCADE,
  analysis_run_id uuid NOT NULL,
  rank smallint NOT NULL CHECK (rank BETWEEN 1 AND 3),
  action_type action_type_enum NOT NULL,
  ingredient_id uuid REFERENCES ingredients(id) ON DELETE RESTRICT,
  alternative_ingredient_id uuid REFERENCES ingredients(id) ON DELETE RESTRICT,
  suggested_delta_as_fed_kg numeric(10,3) NOT NULL,
  suggested_delta_dm_kg numeric(10,3) NOT NULL,
  estimated_cost_delta numeric(12,2) NOT NULL,
  estimated_changes jsonb NOT NULL DEFAULT '{}'::jsonb,
  score numeric(8,3) NOT NULL CHECK (score >= 0),
  reason_text text NOT NULL,
  caution_text text NOT NULL,
  alternative_text text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT recommendations_rank_unique UNIQUE (analysis_run_id, rank),
  CONSTRAINT recommendations_analysis_farm_fk FOREIGN KEY (analysis_run_id, farm_id) REFERENCES analysis_runs(id, farm_id) ON DELETE RESTRICT,
  CONSTRAINT recommendations_id_farm_unique UNIQUE (id, farm_id)
);

CREATE INDEX recommendations_farm_analysis_idx ON recommendations (farm_id, analysis_run_id, rank);

CREATE TABLE recommendation_memos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recommendation_id uuid NOT NULL,
  farm_id uuid NOT NULL REFERENCES farms(id) ON DELETE RESTRICT,
  applied boolean NOT NULL,
  memo text NOT NULL,
  created_by uuid NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT recommendation_memos_recommendation_farm_fk FOREIGN KEY (recommendation_id, farm_id) REFERENCES recommendations(id, farm_id) ON DELETE RESTRICT
);

CREATE INDEX recommendation_memos_recommendation_created_idx
ON recommendation_memos (recommendation_id, created_at DESC);

CREATE TABLE audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  farm_id uuid REFERENCES farms(id) ON DELETE SET NULL,
  actor_user_id uuid REFERENCES users(id) ON DELETE SET NULL,
  event_type audit_event_type_enum NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_logs_farm_created_at_idx ON audit_logs (farm_id, created_at DESC);

CREATE TRIGGER users_set_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER farms_set_updated_at
BEFORE UPDATE ON farms
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER farm_members_set_updated_at
BEFORE UPDATE ON farm_members
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER farm_profiles_set_updated_at
BEFORE UPDATE ON farm_profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER ingredients_set_updated_at
BEFORE UPDATE ON ingredients
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER ingredient_nutrition_versions_protect_update
BEFORE UPDATE ON ingredient_nutrition_versions
FOR EACH ROW EXECUTE FUNCTION protect_ingredient_nutrition_version();

CREATE TRIGGER ingredient_ai_profiles_set_updated_at
BEFORE UPDATE ON ingredient_ai_profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER farm_ingredient_settings_set_updated_at
BEFORE UPDATE ON farm_ingredient_settings
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER requirement_profiles_set_updated_at
BEFORE UPDATE ON requirement_profiles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER formulas_set_updated_at
BEFORE UPDATE ON formulas
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER formula_items_set_updated_at
BEFORE UPDATE ON formula_items
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER recommendation_memos_no_update
BEFORE UPDATE ON recommendation_memos
FOR EACH ROW EXECUTE FUNCTION prevent_mutation();

CREATE TRIGGER recommendation_memos_no_delete
BEFORE DELETE ON recommendation_memos
FOR EACH ROW EXECUTE FUNCTION prevent_mutation();
