# QA / Review Checklist

## General Code Review

- Are calculation rules preserved during refactor?
- Are growth-stage criteria unchanged unless explicitly approved?
- Are enum values consistent across OpenAPI, DB, TypeScript, and Swift models where applicable?
- Are snapshot-style records reproducible from stored inputs?
- Is there any destructive migration or data-loss path?
- Do tests or manual checks include failure and edge cases?

## DB Changes

- Is the reason for the change documented?
- Is rollback or recovery described?
- Is backfill or data migration required?
- Do indexes, partial unique constraints, and check constraints match performance and integrity needs?

## Analysis Engine

- Do DM, moisture, CP, TDN, EE, NDF, ADF, Ca, and P calculations match fixed fixtures?
- Is Ca:P calculated as a ratio, not a percentage?
- Are target criteria snapshots stored or reproducible?
- Are statuses consistently classified as deficient, caution, adequate, or excess?
- Are warning messages and severity levels consistent?

## Recommendation Engine

- Are recommendation candidates limited to ingredients actually present in the current formula?
- Are user-entered `USER_...` ingredients included when they have nutrition profiles?
- Are ingredients without `definitionID` excluded from recommendation candidates?
- Is the final total as-fed kg normalized back to the user's original total?
- Does the UI show only one primary recommendation?
- Are explanation, caution, and projected-result fields non-empty?

## Frontend

- Is the primary input CTA visible on mobile?
- Are user-entered values preserved after navigation or validation errors?
- Does the client avoid inventing nutrient results outside the app engine?
- Are save success/failure states clear?
- Can users add, edit, and delete custom ingredients?

## Core E2E Scenarios

- User signs up and selects ingredients.
- User skips ingredient selection and sees all catalog ingredients.
- User creates a formula and runs analysis.
- User adds a custom ingredient with nutrition values and sees it in calculation.
- User edits a custom ingredient and formula calculation changes accordingly.
- User deletes a custom ingredient and stale formula references are removed.
- A primary recommendation is generated for representative formulas.
- Admin can delete all community posts; regular users can delete only their own posts.
