/// Largest raw file this app will accept for an application document —
/// enforced client-side before upload, with headroom under the Supabase
/// Storage `documents` bucket's own 10 MB hard limit (see
/// docs/SUPABASE_STORAGE_SETUP.md).
const int kMaxDocumentFileBytes = 8 * 1024 * 1024;
