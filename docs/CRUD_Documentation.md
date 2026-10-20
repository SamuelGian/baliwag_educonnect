# Week 4 Activity — CRUD Implementation Documentation

**Project:** Baliwag EduConnect — Student Scholarship and Educational Assistance Portal
**Main data entity:** Scholarship Program (`scholarships` collection)
**Persistent storage:** Firebase (Cloud Firestore for data, Firebase Authentication for accounts)

## 1. Why "Scholarship Program" is the main entity

Every other piece of data in the system revolves around it: students apply *to* a scholarship, documents are verified *against* its requirements, and the Admin Dashboard's statistics are computed *from* it. It is also the entity administrators manage directly, making it the natural fit for a full Create/Read/Update/Delete workflow with a dedicated UI.

(The `applications` and `announcements` collections also have complete CRUD paths in this app — see §5 — but `scholarships` is the flagship example below.)

## 2. Where the code lives

| Layer | File | Responsibility |
|---|---|---|
| Model | `lib/models/scholarship.dart` | `Scholarship` class + `toMap()` / `fromMap()` Firestore (de)serialization, `copyWith()` |
| Data access | `lib/data/scholarship_repository.dart` | `ScholarshipRepository` — thin wrapper around the Firestore `scholarships` collection: `watchAll()`, `create()`, `update()`, `delete()` |
| State | `lib/data/app_state.dart` | `AppState` subscribes to `watchAll()` on login and exposes `createScholarship()`, `updateScholarship()`, `deleteScholarship()` to the UI |
| UI | `lib/screens/admin_dashboard_screen.dart` (`ScholarshipsTab`, `_ScholarshipAdminCard`, `_ScholarshipFormDialog`) | List view, Add/Edit form dialog, delete confirmation — reachable from the Admin shell's "Scholarships" nav item (`lib/widgets/admin_shell.dart`) |

## 3. How each operation works

### Create
Admin taps **"Add Scholarship"** → `_ScholarshipFormDialog` opens with empty fields → on submit, a `Scholarship` draft is built from the form and passed to `AppState.createScholarship()` → `ScholarshipRepository.create()` calls `_col.doc().set(draft.toMap())`, letting Firestore generate the document ID. The new program appears in the list (and on every student's dashboard) immediately via the live stream — no manual refresh. (A "Load Sample Scholarships" button is also available on the empty state, which seeds several realistic programs through this exact same `createScholarship()` path, for quick setup.)

### Read
`ScholarshipRepository.watchAll()` returns a `Stream<List<Scholarship>>` from `_col.snapshots()`. `AppState` listens to this stream once per session and calls `notifyListeners()` on every update, so any screen using `context.watch<AppState>().scholarships` (Student Dashboard, Apply flow, Admin Dashboard) always reflects current Firestore state in real time.

### Update
Admin taps the edit icon on a scholarship card → the same `_ScholarshipFormDialog` opens pre-filled (`existing: scholarship`) → on submit, `AppState.updateScholarship()` calls `ScholarshipRepository.update()`, which does `_col.doc(scholarship.id).update(scholarship.toMap())`.

### Delete
Admin taps the delete icon → a confirmation `AlertDialog` appears (guards against accidental deletion) → on confirm, `AppState.deleteScholarship(id)` calls `ScholarshipRepository.delete()`, which does `_col.doc(id).delete()`.

## 4. Data validation

- Form-level (`Form` + `TextFormField` validators in `_ScholarshipFormDialog`):
  - Title, Provider, Description, Amount, Total Slots: required, non-empty.
  - Amount, Total Slots, Slots Filled: must parse as numbers; Total Slots ≥ 1, Slots Filled ≥ 0.
- Cross-field validation: Slots Filled cannot exceed Total Slots (checked before save, surfaced via a `SnackBar`).
- Requirements list: at least one non-empty requirement line is required (documents students must upload).
- Access to the "Scholarships" management screen itself is gated by `AuthGate` (`lib/widgets/auth_gate.dart`): only an account whose Firestore `users/{uid}` profile has `role == 'admin'` is ever routed to the Admin shell in the first place — a student account cannot reach this screen. (Firestore security rules for `scholarships` only require the request to be signed in, not specifically an admin — see the note at the top of `firestore.rules` for why the role check couldn't be enforced at the database level in this environment, and how to restore it later.)

## 5. The other CRUD paths in the app

- **Applications** (`lib/data/application_repository.dart`): Create on student submission (`AppState.submitApplication`), Read via `watchAll()` (admin) / `watchForStudent(uid)` (student, auto-filtered), Update via `updateStatus()` / `updateDocuments()` / `addMessage()` (used by the admin's Approve/Reject actions, the automated OCR pipeline, and per-document resubmission requests). No manual delete — applications are a record, not something an admin discards.
- **Announcements** (`lib/data/announcement_repository.dart`): same Create/Read/Update/Delete shape as Scholarships, exposed in the Admin shell's "Announcements" tab.
- **Document files** (`lib/services/supabase_storage_service.dart`): Create on upload (`upload()`), Read on demand when an admin opens the document viewer (`createSignedUrl()`) — see §6.

## 6. Persistent storage details

- **Cloud Firestore** — `scholarships`, `applications`, `announcements`, and `users` collections.
- **Firebase Authentication** — Email/Password sign-in for both Student and Admin accounts; the account's role (`student` or `admin`) is stored in its `users/{uid}` Firestore profile document and read on every login to route to the correct part of the app (see `lib/widgets/auth_gate.dart`).
- **Uploaded application documents** (Form 137, Certificate of Enrollment, etc.) are compressed client-side if needed (`lib/services/image_compression_service.dart`, capped at 8MB — see `lib/data/document_upload_limits.dart`) and uploaded directly to a private **Supabase Storage** bucket (`documents`), one object per (application, requirement) pair. Only the object's storage *path* — never a URL — is saved on the application's `DocumentItem.storagePath` field in Firestore; the admin viewer mints a short-lived signed URL on demand each time it opens a document (see `docs/SUPABASE_STORAGE_SETUP.md`). This lets an admin actually open and manually inspect what a student submitted, not just see the automated OCR verdict, from the Admin Dashboard's document viewer.

Firestore security rules are in `firestore.rules` at the project root. Supabase Storage access policies (who can upload/view objects in the `documents` bucket) are separate from Firestore rules — see `docs/SUPABASE_STORAGE_SETUP.md`.

## 7. Screenshots

_Add screenshots here showing each operation in the running app:_
1. **Create** — the "Add Scholarship" dialog filled in, then the new card appearing in the list.
2. **Read** — the Scholarships list, and the same data appearing on the Student Dashboard.
3. **Update** — editing a scholarship's slots/deadline and seeing the change reflected.
4. **Delete** — the confirmation dialog, then the card gone from the list.
