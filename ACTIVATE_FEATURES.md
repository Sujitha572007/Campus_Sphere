# Install this corrected update first

1. Stop the running Flutter process. Back up your project. Extract this revised ZIP and open its campus_sphere folder, or copy its lib/, firestore.rules, firestore.indexes.json, functions/ and firebase.json into your current project.
2. Run in the project root:

```powershell
flutter pub get
firebase.cmd deploy --only "firestore:rules,firestore:indexes" --project campussphere-61a10
flutter analyze
flutter test
flutter run -d chrome
```

After this deployment, a NEW student registration creates its in-app notification immediately (unless the student disabled notifications). Check-in creates its attendance notification in the same transaction. Old registrations are not retrospectively changed. Leave Settings → In-app notifications enabled for your test. Do not test the revised client against the old rules: its atomic notifications need the matching rules.

# Test attendance before email setup

Create an event starting about 30 minutes from now and ending in about 90 minutes, status scheduled, registration open. Register as a student, then open that ticket from an approved admin's scanner for that same event. Scan, check identity, confirm. Attendance and count update. Scan twice: the second scan says already checked in.

The check-in window remains two hours before start through end. The scanner displays the event's actual window. For a future event outside that window, attendance must not be accepted. The revised scanner displays the actual error/code if Firebase rejects a read/write. Send that exact message if it fails; it identifies the next fix. Paste the copied ticket code to test the database independently of camera hardware.

# Activate confirmation emails and event updates

Sender: achyutha0506@gmail.com. This is still a separate private setup: extracting/running Flutter or deploying Firestore rules cannot activate Gmail.

1. Firebase project must be on Blaze (billing may apply).
2. In the sender's Google account, enable 2-Step Verification and create an app password at https://myaccount.google.com/apppasswords . Keep it private.
3. Run these commands from the project root:

```powershell
firebase.cmd functions:secrets:set GMAIL_APP_PASSWORD --project campussphere-61a10
```

Enter the app password in the private terminal prompt, then:

```powershell
cd functions
npm.cmd ci
npm.cmd test
cd ..
firebase.cmd deploy --only functions --project campussphere-61a10
```

Use Node 22 for backend setup. After Deploy complete, register for a NEW event using an email address whose inbox you can read. Keep Registration emails enabled in Settings. Look for queued/sent delivery status in My Registered Events and check inbox/spam. Existing registrations do not trigger new mail automatically.

If emails fail, show the Functions deployment/log error, never the password. No real email delivery or camera-device test has been performed here; the revised transaction security and backend behavior were tested with emulators/mocked SMTP.

Read START_HERE.md for the complete details and troubleshooting.
