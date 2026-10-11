# CampusSphere — five-feature update

This project uses your existing Firebase project `campussphere-61a10`. No club, event, student or registration data is seeded, deleted or overwritten by installing it.

## 1. Install and run the Flutter update

Stop the running app, back up your existing folder, then extract this ZIP and open its `campus_sphere` folder in VS Code. Open PowerShell in that folder:

```powershell
flutter pub get
firebase.cmd deploy --only "firestore:rules,firestore:indexes" --project campussphere-61a10
flutter analyze
flutter test
flutter run -d chrome
```

Wait until the new checkins collection-group index finishes building in Firebase Console before testing attendance counts. Index creation is asynchronous; deployment success does not mean the index is ready immediately.

The app changes and QR attendance work after the rules/index deployment. Registration and attendance notifications now save atomically in the app and need only the updated rules. Automatic event-update notifications and confirmation emails require the Functions deployment in step 2. Do not expect email delivery from `flutter run` alone.

## 2. Activate notifications and registration emails

Sender: **achyutha0506@gmail.com**. This address is configured in `functions/index.js`. Firebase Authentication password-reset emails use Firebase's configured auth sender, independently of registration emails.

Firebase Cloud Functions deployment requires the **Blaze billing plan**. Enable billing in Firebase Console only if you want to deploy this backend; it can incur charges. The scheduled retry runs every ten minutes. Configure budget alerts/spend controls as appropriate. If you keep Spark, the frontend, settings and QR attendance remain usable, but automatic event-update notifications/emails are inactive. Registration and attendance confirmations remain active.

1. Sign into the sender Google account privately.
2. Enable Google **2-Step Verification**.
3. Create an **App Password** named CampusSphere in https://myaccount.google.com/apppasswords . If unavailable, check Google's account restrictions; do not use your normal Gmail password.
4. In the project root, run:

```powershell
firebase.cmd functions:secrets:set GMAIL_APP_PASSWORD --project campussphere-61a10
```

Enter the app password into the CLI's private prompt. Never paste it into ChatGPT, Dart/JavaScript source, a screenshot or a ZIP. No service-account JSON is needed by deployed functions.

5. Install the backend dependencies and run its tests:

```powershell
cd functions
npm.cmd ci
npm.cmd test
cd ..
firebase.cmd deploy --only functions --project campussphere-61a10
```

Use Node.js 22 locally for the backend. Firebase runs the functions on Node.js 22; your previously installed Node 24 may print an engine warning during local installation.

The functions run in `asia-south1`. Existing Firestore data is not moved. If your database is in another location, account for inter-region latency/transfer when reviewing deployment.

If deployment reports service/API/IAM errors, keep the exact error and resolve it through the Firebase project owner. Do not change Firestore rules to allow students to write mail jobs or notifications.

Google may restrict Gmail SMTP sending or place mail in spam. This is a small-project integration; Gmail is not a bulk transactional email service. No Gmail access has been granted and no real email has been sent as part of preparing this ZIP.

Official references:
- Firebase Functions setup/billing: https://firebase.google.com/docs/functions/get-started
- Firebase secrets: https://firebase.google.com/docs/functions/config-env
- Google app passwords: https://support.google.com/accounts/answer/185833
- Gmail SMTP behavior: https://nodemailer.com/guides/using-gmail

## 3. Test the exact student → admin QR flow

1. Log in as a student, open a **new** scheduled event and register. Existing registrations do not receive retrospective confirmation emails when you deploy Functions.
2. Open **My Registered Events → View QR ticket**. Each student/event pair has a separate random ticket token. Its QR contains the event ID, student ID and token; it does not contain their name/email.
3. Log in as an approved admin on another device/browser session. For that event choose **Scan QR**, then **Scan next ticket**, and allow camera access. Chrome camera use requires HTTPS or localhost; Windows/Linux desktop apps can use the paste-code fallback.
4. Scan the student QR. Check the displayed student name/email and confirm **Check in**.
5. Open **Attendance list** for that event. The student's name, email, attendance status and time appear. The event card's **attended count** updates live.
6. Scan again. The app says **Already checked in** and the count stays unchanged.
7. Scan that ticket from a different event's scanner. It must be rejected.

Camera-free test: use **Copy ticket code** on the student QR page, paste it in the admin scanner's text field, and choose **Verify and check in**. This exercises the same validation/database transaction as camera scanning.

Check-in opens **two hours before the start** and closes **at the end**. The event must have `status: scheduled`, valid Firestore Timestamp `startAt`/`endAt`, and a matching confirmed registration. For a demonstration, use the admin event form to schedule an event starting about 30 minutes from now, register, and scan. Completed/cancelled events cannot accept new attendance.

The Firestore rules use server time to enforce the window. The UI uses device time for initial feedback; keep the device clock accurate.

Attendance is stored at `users/{studentId}/checkins/{eventId}`, not in a separate admin database. Admins have authorized read access and can query attendance for each event. Deterministic immutable documents prevent duplicate attendance. A QR can be copied; admins should compare the student identity before admitting them.

## 4. Notifications

- Registration confirmed.
- Event changes: title/description, date/time, venue, deadline, registration status, completion/cancellation.
- Attendance recorded.
- Bell unread badge; notification page; mark-read actions; tapping an entry opens its event.
- Recent updates on the student home page.

These are **in-app notifications**, not operating-system push notifications or scheduled event reminders. Registration/attendance confirmations are written together with the matching new registration/check-in. Rules reject forged notifications and replayed confirmations. Firebase Functions creates event-update notifications. Students may only mark their own notifications read. Event-count changes from other students registering do not spam notification feeds. The feed displays the latest 100 notifications; “mark these notifications read” applies to those loaded entries.

Preferences affect future notification creation. Old notifications remain visible after opting out.

## 5. Email delivery and troubleshooting

Confirmation emails include student greeting, event title, club, date/time in IST, venue and instructions for finding the QR ticket. The private QR token is not emailed. My Registered Events displays queued/sent/failed/skipped email status when the backend has processed it. `sent` means Gmail accepted the message, not guaranteed inbox delivery.

Firebase Console → Firestore → `mail_jobs` lets the project owner inspect job status. The app cannot create or edit these jobs. Delivery retries at most five times; failures never undo registration. `users/{studentId}/email_receipts/{eventId}` contains the app-visible delivery status.

Notification/job IDs are deterministic and SMTP delivery uses an atomic lease to suppress ordinary concurrent/repeated sends. SMTP cannot guarantee exactly-once delivery if the process dies after Gmail accepts mail but before Firestore records success; a retry in that rare situation can duplicate mail.

If there is no email status for a *new* registration, verify the Functions deployment/logs. If queued/failed, check the secret, sender account, opt-out preferences and SMTP errors. Logs intentionally do not print credentials or full message contents. Successful email tests still require your private sender setup.

## 6. Settings

Student drawer → Settings. Admin toolbar → settings icon. Admin maps and notifications have been removed.

- Light, dark or device theme, persisted per account.
- In-app notification preference.
- Registration email preference.
- Send Firebase password-reset email.
- App information.

Preferences are stored in `users/{uid}/preferences/settings`. They cannot change a user's role.

## 7. Map update

The map now has a campus header, rounded responsive panel, named markers, search, zoom/recenter controls, place chips, a selected-place information card, and building/floor-directory shortcuts. Google Maps opens walking directions to a verified selected destination. Google determines routing; the app has not built an internal campus path graph.

The blue reference comes from your supplied Maps link (16.5645537, 81.5222806); it is a reference, not a verified SVECW block entrance. No A/B/C/D coordinates have been invented. The admin dashboard no longer includes a map. The project owner can add verified locations through Firebase Console → Firestore → campus_places. Each document needs name (string), latitude/longitude (number), verified (true), and updatedAt (Timestamp). Student maps update automatically. A labelled campus image/layout would be needed for a custom geographically accurate illustrated campus map.

Jewel Labs and Seetha Auditorium remain independent facilities. D Block details remain pending. The room directory remains `assets/campus_rooms.json`.

Map tiles need internet. OpenStreetMap attribution is visible. Review your tile provider's usage policy before larger/public deployment. `MAP_TILE_URL` can configure an alternative licensed XYZ provider, but its attribution must also be updated; this build uses OpenStreetMap only.

## Verification completed here

- 67 Firestore Emulator security checks passed: roles, registration/capacity, private ticket data, immutable attendance, admin-only place edits, notification/privacy/settings permissions and attendance group query access.
- 8 Node backend tests passed: stable IDs, event-update filtering, IST email content, opt-out, idempotent notification/job creation, ordinary duplicate delivery suppression and capped failure retries. SMTP is mocked in these tests.
- Dart files parsed/formatted with standalone Dart. Existing room/QR Flutter tests remain in `test/` and the welcome test does not require Firebase initialization.
- Full Flutter analyze/widget tests, camera hardware, visual rendering and live Gmail delivery were **not** run here. Run the Flutter checks in step 1 and the device flow above.
- Earlier Flutter tool bootstrap was rejected by automatic approval review because it attempted a cloud instance-metadata request outside this task. That execution was not repeated or bypassed. Safe standalone Dart, Node tests and the Firestore Emulator were used instead.

To repeat the 67 emulator checks locally (optional), install Java 17+, then run `cd security_tests`, `npm.cmd install`, `npm.cmd test`, and `cd ..`. These tests use only the demo project `demo-campus-admin`, never production data.
