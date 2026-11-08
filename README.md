# ARTORA — Supabase backend starter

This folder prepares the backend foundation for the ARTORA prototype. It includes:
- Supabase database schema and Row Level Security policies (`schema.sql`)
- Browser-safe Supabase configuration template (`supabase-config.js`)
- Starter functions for sign-up, sign-in, sign-out, artwork uploads, gallery queries, likes and follows (`supabase-client.js`)

## Important
This is a backend starter, not a fully connected website yet. The existing ARTORA homepage still needs its demo interactions replaced with calls to these functions. Do not claim that accounts or uploads are live until the Supabase project has been configured and tested.

## Setup

1. Create a Supabase project at https://supabase.com.
2. In the project, open **SQL Editor → New query**.
3. Paste all of `schema.sql` and run it.
4. Open **Project Settings → API** (or API Keys, depending on the dashboard layout).
5. Copy the Project URL and the `anon` / publishable public key.
6. Paste those values into `supabase-config.js`.
   - Never use a `service_role` or secret key in frontend code.
7. Host the site on a web server such as GitHub Pages or Vercel. ES modules generally should not be opened directly as a `file://` page.
8. Connect the sign-up/login forms and artwork gallery in `index.html` to the exported functions in `supabase-client.js`.
9. Test with a separate user account: sign up, confirm email if enabled, log in, upload an image, then verify it appears in the `artworks` table and `artwork-images` storage bucket.

## Database tables

- `profiles`: public artist profile information
- `artworks`: artwork metadata and public image URL
- `likes`: likes by authenticated users
- `saved_artworks`: private saved-artwork lists
- `follows`: artist follow relationships
- `comments`: artwork comments
- `reports`: user-submitted moderation reports

## Security notes

- Row Level Security is enabled on all public tables.
- Public visitors can read profiles, artworks, likes, follows and comments.
- Only authenticated owners can change their own profile/artworks.
- Saved artworks and reports are private to their owner.
- Storage uploads are restricted to a folder named with the signed-in user's UUID.
- The artwork bucket is public so gallery images can be displayed without signing in. Do not upload private images there.
- The SQL does not create a moderator/admin dashboard. Moderation privileges should be added later with a carefully designed role system; never trust a role value supplied by a browser.

## Current limitation

The starter functions are ready to be imported by frontend code, but the existing homepage's local demo handlers are not yet replaced. The next implementation step is wiring the UI to these functions and testing the complete sign-up → upload → gallery flow.
