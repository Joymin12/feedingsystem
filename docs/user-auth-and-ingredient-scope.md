# User Auth And Ingredient Scope

## Current Baseline

The current operating mode is `local persistence first`.

Responsibility split:

- `iOS local`
  - Sign-up
  - Login / logout
  - User profile
  - User-specific ingredient selection
  - Community post create/delete
  - Formula entry
  - Nutrition calculation
  - Composite correction recommendation
  - Diary / recent analysis
  - User-entered ingredient add/edit/delete
- `Supabase`
  - Currently not used in the release path
  - Kept only as reference code/documentation for future remote auth/community migration

## User Policy

- Regular users sign up with email.
- During sign-up, users can select ingredients they use.
- `Skip` is available only during sign-up.
- If a user selects ingredients, the formula ingredient-add list shows only those selected catalog ingredients plus their custom ingredients.
- If the user skips selection, the app shows all catalog ingredients.
- User-entered ingredients are always visible to their owner and are included in calculation/recommendation.

## Storage Structure

### Local Storage

- `AppUser`
  - `loginID`
  - `email`
  - `password`
  - `farmName`
  - `preferredStage`
  - `selectedIngredientIDs`
  - `isAdmin`
- `CommunityPost`
  - `id`
  - `authorLoginID`
  - `title`
  - `excerpt`
  - `label`
  - `createdAt`
- `UserIngredientDefinition`
  - `id`
  - `ownerLoginID`
  - `name`
  - `category`
  - `defaultPriceKrwPerKg`
  - `nutrition`
  - `createdAt`

### Supabase Fallback Code

If Supabase configuration is empty, the app uses local persistence only. This is the default assumption for the current release path.

## Auth Flow

### Login

- Email or admin ID.
- Password.

### Sign-Up

Inputs:

- Email.
- Password.
- Password confirmation.
- Ingredient selection.

Email verification currently uses a local verification-code flow.

## Community Permission

- Regular users:
  - Can create posts.
  - Can delete only their own posts.
- Admin:
  - Can delete every post.

Current implementation uses the local user's `isAdmin = true`.

## Related Code Files

- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/HanwooPrototypeApp.swift`
- `/Users/jowm/Desktop/feedingsystem/apps/ios/HanwooPrototype/HanwooPrototype/SupabaseService.swift`
- `/Users/jowm/Desktop/feedingsystem/docs/supabase/supabase-auth-community-setup.md`

## Current Limitations

- Admin account `qwer123 / asdf123` is currently hardcoded in local fallback logic.
- Password and community persistence are local, so security/sync must be revisited before production release.
- User-entered ingredients are local-only and should eventually move behind a Repository, then to SwiftData/CoreData or server sync.
- Formula calculation remains local by design.
