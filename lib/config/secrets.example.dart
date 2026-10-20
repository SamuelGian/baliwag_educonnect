// Copy this file to secrets.dart (same folder) and fill in your own values.
// secrets.dart is gitignored - it will never be committed.
//
// Get a free OCR.space API key at: https://ocr.space/ocrapi (no credit card needed)
const ocrSpaceApiKey = 'YOUR_OCR_SPACE_API_KEY_HERE';

// Gemini Vision - used as an immediate "does this even look like the right
// kind of document" gate at upload time. Get a free key at:
// https://aistudio.google.com/apikey
const geminiApiKey = 'YOUR_GEMINI_API_KEY_HERE';

// Anyone who knows this code can register an Admin account from the app's
// Register screen. Change it to something private before sharing the app.
const adminAccessCode = 'BALIWAG-ADMIN-2026';

// Supabase Storage (document files). The "publishable" key is meant to be
// embedded in client apps (same model as Firebase config) - access control
// is enforced by Storage policies on the bucket, not by keeping this value
// secret. NEVER put the Supabase "secret" key here or anywhere in app code.
const supabaseUrl = 'YOUR_SUPABASE_PROJECT_URL_HERE';
const supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY_HERE';
