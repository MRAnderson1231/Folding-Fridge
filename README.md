# Folding Fridge

Native SwiftUI iOS project for a single-purpose fridge-to-recipe app.

## Open in Xcode

Open:

- `FoldingFridge.xcodeproj`

## API wiring

Set these values in `FoldingFridge/Info.plist`:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

If either value is empty, remote mode is disabled.

## Supabase prototype backend

The project now includes a Supabase scaffold in:

- `supabase/`

This is not run in Xcode.

Use:

- Supabase Dashboard Editor
- or Supabase CLI

Then enable remote mode in:

- `FoldingFridge/Info.plist`

Fill:

- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

## Current flow

- One-page onboarding
- Full-screen camera
- Single photo capture
- Upload/analyze transition
- Recipe results with save and share
- Profile archive with recipe roll and tear-off cook mode

## Suggested production backend

Prefer a small backend over calling OpenAI directly from the iOS app. That keeps your API key off-device, lets you validate structured outputs, and gives you a place to store saved recipes.
