# Weekly Reflection

This week I set up the Baliwag EduConnect Flutter project end-to-end: the four core screens (Student Dashboard, Scholarship Application, Application Tracker, Admin Dashboard), the data models, and working navigation between them. Based on my adviser's suggestion, I revised the proposal to add OCR-based document verification — checking uploaded requirements against the applicant's own submitted information — and built it into the app, including the "Verifying with OCR…", "Matched", and "Needs manual review" status flow.

The main challenge was running real OCR without a backend server, since this is a Flutter prototype with no server infrastructure yet. I resolved this by designing around a cloud OCR REST API (OCR.space) that works across web and mobile, with fuzzy name-matching logic done client-side. The real OCR call is implemented and gated behind a config flag while I finish testing an API key, with a simulated pass standing in for demos.
