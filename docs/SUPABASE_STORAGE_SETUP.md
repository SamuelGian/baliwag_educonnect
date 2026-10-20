# Supabase Storage setup (document files)

Uploaded application documents (Form 137, Certificate of Indigency, COR, etc.)
are stored in a Supabase Storage bucket instead of Firebase Storage, because
Firebase Storage now requires the Blaze (pay-as-you-go) plan. Supabase's free
tier (1GB storage + 2GB bandwidth/month) is more than enough for scanned
documents.

## How it's wired up

- **Project**: `baliwag-educonnect`, region Asia-Pacific (Singapore).
- **Bucket**: `documents` — **private** (not a public bucket), file size
  limit 10MB, MIME types restricted to `image/jpeg`, `image/png`,
  `application/pdf`.
- **Credentials**: the Project URL and the **publishable** (`anon`) key live
  in `lib/config/secrets.dart`, which is gitignored — same pattern as the
  OCR.space API key. The publishable key is *meant* to be embedded in client
  apps (same model as Firebase's config object); it is not a secret on its
  own. Access control comes from the Storage policies below, not from
  keeping this key hidden.
- **The Supabase "secret" key is never used anywhere in this app.** It was
  shown once during setup and should be kept only in your own password
  manager/notes — never paste it into app code, `secrets.dart`, or anywhere
  that could end up in a commit. It's not needed unless you build a separate
  backend/admin script later.

## Access policies (why uploads/views work without Supabase Auth)

This app authenticates users with **Firebase Auth**, not Supabase Auth, so
every request to Supabase arrives as the `anon` role — there's no Supabase
session to check. Access is therefore enforced the same way the rest of this
project already handles it (see the note at the top of `firestore.rules`):
gated by the app's own UI, with the following bucket-level SQL policies
(run once, in the Supabase SQL Editor) allowing the `anon` role to
insert/select/update objects only within the `documents` bucket:

```sql
create policy "Allow anon insert to documents bucket"
on storage.objects for insert
to anon
with check (bucket_id = 'documents');

create policy "Allow anon select from documents bucket"
on storage.objects for select
to anon
using (bucket_id = 'documents');

create policy "Allow anon update in documents bucket"
on storage.objects for update
to anon
using (bucket_id = 'documents')
with check (bucket_id = 'documents');
```

If these ever need to be re-applied (e.g. a new Supabase project), re-run
this SQL in Project → SQL Editor.

## Why paths are stored, not URLs

Because the bucket is private, there is no permanent public URL for an
object. `DocumentItem.storagePath` (Firestore) stores only the object's
*path* inside the bucket (e.g. `abc123/certificate-of-indigency.jpg`). The
admin document viewer calls `SupabaseStorageService.createSignedUrl()` fresh
every time it opens a document, which mints a time-limited (1 hour) signed
URL. Storing a signed URL directly would eventually expire and leave the
viewer permanently broken — minting one on demand avoids that.

## Rotating/replacing credentials

If the publishable key ever needs to change (e.g. new Supabase project):

1. Project Settings → API → copy the new **Project URL** and
   **`anon` `public`** (or "publishable") key.
2. Update `supabaseUrl` and `supabaseAnonKey` in `lib/config/secrets.dart`.
3. Re-run the SQL policies above against the new project if it's a fresh
   project (a brand new bucket has no policies yet — nothing will
   upload/view until they're applied).
