# CampusSphere admin setup

This update keeps your student flow and existing Firestore registrations.

## Install

1. Back up your current `C:\project\campus_sphere` folder.
2. Extract this ZIP. Copy its `campus_sphere` files into your existing project, replacing matching files. Keep your separate `C:\project\tools` folder.
3. From `C:\project\campus_sphere`, run:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

No new Flutter packages are required.

## Publish rules and the registrations index

Copy the complete contents of `firestore.rules` into Firebase Console → Firestore Database → Rules and click Publish. These replace the old rules and preserve student registration protections.

For the registered-student list, enable a single-field **collection group** ascending index for collection ID `registrations`, field `eventId`. In Firestore's Indexes → Single field tab, add an exemption for `registrations` / `eventId`, and enable ascending indexing under Collection group scope. Wait for the index to finish building. If the app reports an index error, its Firebase link also opens the required index setup.

Alternatively, deploy the included rules and index configuration together from the project folder:

```powershell
firebase.cmd deploy --only firestore:rules,firestore:indexes --project campussphere-61a10
```

## First admin account

1. Get Started → select Admin → New admin? Register for access.
2. Register using name, email, password, and confirmation.
3. This creates a regular account and `admin_requests/{UID}` with status `pending`. It does not grant admin privileges.
4. As the Firebase project owner, open Firestore Data → users → the matching UID. Check the email and set `role` (string) to `admin`. Existing accounts can be approved the same way without creating a new account.
5. Optionally change that account's request status to `approved` using Firebase Console. The profile role, not the request status, controls permissions.
6. Select Admin on the login page and sign in. The dashboard opens. Pending accounts see an approval message.

Only Firebase project administrators assign roles; app users cannot modify roles or approve themselves. A verified admin signing in through the Student tab is also routed to the admin dashboard. A student signing in through the Admin tab can request access but receives no extra permissions.

## Dashboard

- Search and filter events: all, upcoming, completed, cancelled.
- Add event: select a real saved club; category and club name come from its record.
- Dates use India time in `YYYY-MM-DD HH:mm`, with a 24-hour clock.
- Add title, description, venue, event type, optional HTTPS poster URL, dates, deadline, capacity, eligible years, certificates, and prizes.
- Capacity 0 means unlimited. Empty deadline means registration closes when the event starts.
- Edit event: seat count is preserved. Capacity cannot be lower than existing registrations. Organizing club cannot change after students register.
- Mark completed: records completion time automatically, closes registration, and updates the latest-three club preview.
- Cancel: closes registration, preserves event and student registration history.
- Delete: requires confirmation and zero registered students. Firestore enforces this too.
- Registered students: reads existing `users/{UID}/registrations/{eventId}` records, showing name, email, declared year, and registration time.
- Admin requests: shows applicants and UIDs; approval is performed in Firebase Console.
- Logout: returns to login.

## Verify before presenting

1. Student cannot create/edit/delete events or change their role.
2. Pending admin cannot access the dashboard.
3. Approved admin can create a demo event and edit it.
4. Student registers once; duplicate registration does not increase the count.
5. Admin sees the count and attendee in Registered students.
6. Admin cannot reduce capacity below the count or delete a registered event.
7. Cancelling leaves the student's registration visible as cancelled.
8. Marking a demo event completed moves it to Past Events and the club's latest-three list.
9. Remove admin role in Console: dashboard access is revoked and rules deny subsequent admin operations.

The app uses cloud authentication and data. Do not embed Firebase Admin service-account private keys in Flutter. The delivered ZIP contains application sources, not the uploaded tools, build output, or browser caches.

## Validation performed on this update

- All Dart source files parsed successfully using Dart 3.13.5's formatter.
- 21 Firestore Emulator checks passed: self-promotion denied, student event edits/creation denied, admin create/edit allowed, fabricated counts denied, eligibility enforced, atomic registration allowed, duplicates/capacity protected, student privacy, admin collection-group attendee access, deletion protections, completion/cancellation, retained history, pending access request creation, blocked self-approval, and revoked admin denied.
- Flutter execution, full type analysis, and widget tests were not run in the delivery environment because Flutter SDK was unavailable. Run the local commands above before demonstrating.
