# Proposal

## Title
Baliwag EduConnect – Student Scholarship and Educational Assistance Portal

## Short Description
A centralized web portal where students can apply for scholarships and educational assistance, upload requirements, track application status, and receive announcements. Administrators can review applications and manage scholarship programs efficiently. Uploaded documents are automatically cross-checked against the applicant's own submitted information using Optical Character Recognition (OCR), flagging mismatches for admin review before manual verification begins.

## SDG Alignment
- **SDG 4 – Quality Education** — removes friction from applying for and tracking scholarships, so more students actually complete the process.
- **SDG 10 – Reduced Inequalities** — gives students without regular access to scholarship offices equal, remote access to apply and follow up.
- **SDG 16 – Peace, Justice and Strong Institutions** — OCR-assisted document verification adds a consistent, auditable first check on submitted requirements, reducing fraudulent or mismatched submissions and making the review process more transparent and accountable.

## Key Feature: OCR-Based Document Verification
Suggested by the adviser: when a student uploads a requirement (e.g. Form 137, Certificate of Enrollment, Certificate of Indigency), the system should check whether what's written on the document matches what the student typed into the application form.

**How it works in this system:**
1. When a student uploads a document in the Documents step of the application, the system sends the file to an OCR engine and extracts its text.
2. The extracted text is compared against the applicant information the student entered in the same application (full name, and other fields present on that document type), using fuzzy text matching to tolerate scan noise and minor OCR errors.
3. Each document is tagged with a status: **Not uploaded**, **Verifying with OCR…**, **Matched with student record**, or **Needs manual review** — shown live to the student in the Application Tracker, and to the admin in the Admin Dashboard.
4. Documents that don't match are flagged for the admin to review manually instead of being silently accepted or rejected — OCR assists the admin, it doesn't replace their judgment.

This turns document verification from a fully manual admin step into an assisted first pass, cutting review time and catching obvious name/detail mismatches before an application reaches a human reviewer.

## 4-Screen UI Mockup Structure

**Screen 1 – Student Dashboard**
Displays available scholarships, application status, announcements, and important deadlines.

**Screen 2 – Scholarship Application**
Allows students to complete application forms, upload required documents, and submit scholarship applications online. Each uploaded document is automatically OCR-scanned and checked against the applicant information entered in the same form.

**Screen 3 – Application Tracker**
Shows the progress of submitted applications, per-document OCR verification status (matched / needs review), and messages from administrators.

**Screen 4 – Admin Dashboard**
Allows administrators to review applications, see which documents were auto-matched vs. flagged by OCR for mismatch, approve or reject requests, and monitor scholarship statistics.
