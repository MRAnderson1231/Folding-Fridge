# Supabase Setup

These files are the backend scaffold for Folding Fridge.

You do not run these inside Xcode.

Use one of these two paths:

1. Supabase Dashboard
   - Open `Edge Functions`
   - Create:
     - `fridge-analyze`
     - `save-recipe`
     - `my-recipes`
   - Paste the matching `index.ts` from this folder into each function
   - Disable JWT verification for this prototype if you plan to call the functions with only the publishable key

2. Supabase CLI
   - Install Supabase CLI
   - In this project folder:
     - `supabase login`
     - `supabase link --project-ref gwudjuhkjnokzisnyzdu`
     - `supabase db push`
     - `supabase functions deploy fridge-analyze --no-verify-jwt`
     - `supabase functions deploy save-recipe --no-verify-jwt`
     - `supabase functions deploy my-recipes --no-verify-jwt`

## Database

Run the SQL in `schema.sql` to create the `saved_recipes` table.

## iOS app switch

The iOS app is already prefilled with:

- project URL
- publishable key
- default function paths

But remote mode is intentionally disabled until these functions are deployed.

To enable remote mode after deployment:

1. Open `/Users/developer/Desktop/Folding Fridge/FoldingFridge/APIClient.swift`
2. Change:
   - `APIConfiguration.Supabase.enabled = false`
3. To:
   - `APIConfiguration.Supabase.enabled = true`

Then run the app again.

## Function contract

### `fridge-analyze`

Input:

```json
{
  "imageBase64": "..."
}
```

Output:

```json
{
  "detectedIngredients": [],
  "uncertainIngredients": [],
  "recipes": [],
  "modelSummary": ""
}
```

### `save-recipe`

Input:

```json
{
  "recipe": {
    "...": "SavedRecipe payload from the app"
  }
}
```

### `my-recipes`

Output:

```json
[
  {
    "...": "SavedRecipe payload"
  }
]
```
