<div align="center">

  <img src="assets/images/logo.png" alt="ROCIs Tasks Icon" width="120" style="border-radius: 24px;" />

  # ROCIs Tasks
  **Tasks and your calendar on one timeline. Type a task the way you would say it.**

  [![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
  [![CI](https://img.shields.io/github/actions/workflow/status/RoeeIlouz/ROCIsTasks-Public/flutter-ci.yml?branch=main&style=for-the-badge&logo=githubactions&logoColor=white&label=analyze%20%2B%20tests)](https://github.com/RoeeIlouz/ROCIsTasks-Public/actions/workflows/flutter-ci.yml)
  [![Google Play](https://img.shields.io/badge/Google_Play-ROCIs_Tasks-34A853?style=for-the-badge&logo=googleplay&logoColor=white)](https://play.google.com/store/apps/details?id=com.rocisapps.tasks)
  [![Web App](https://img.shields.io/badge/Web_Version-tasks.rocisapps.com-0284C7?style=for-the-badge&logo=googlechrome&logoColor=white)](https://tasks.rocisapps.com)
  [![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-F59E0B?style=for-the-badge)]()
  [![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)](LICENSE)

  <br />

  <img src="assets/images/play_store/en/feature.jpg" alt="ROCIs Tasks Feature Graphic" width="100%" style="border-radius: 16px;" />

</div>

---

Get it on [Google Play](https://play.google.com/store/apps/details?id=com.rocisapps.tasks) or use the [web version](https://tasks.rocisapps.com).

## What it does

- **Natural language input.** Type `Submit essay tomorrow at 5pm #urgent @school` and the date, time, priority and category are filled in for you.
- **One timeline.** Tasks, Google Calendar events and your phone's calendars side by side.
- **Home screen widgets** for today's agenda and a month view, with tasks you can check off without opening the app.
- **Subtasks, checklists and repeating tasks** (daily, weekly, monthly or custom rules).
- **Insights**: a 7-day completion chart, streaks and a per-category balance.
- **Works offline** and syncs when you are back online.
- **Pairs with [ROCIs Schedule](https://github.com/RoeeIlouz/ROCIs-Schedule)**: send an assignment or exam from your timetable straight into Tasks.

## Screenshots

<div align="center">
  <table>
    <tr>
      <td width="33%"><img src="assets/images/play_store/en/phone/01.jpg" alt="Home Screen Widgets" /></td>
      <td width="33%"><img src="assets/images/play_store/en/phone/02.jpg" alt="Full Calendar Widget" /></td>
      <td width="33%"><img src="assets/images/play_store/en/phone/04.jpg" alt="Quick Add" /></td>
    </tr>
    <tr>
      <td align="center"><b>Home Screen Widgets</b></td>
      <td align="center"><b>Full Calendar Widget</b></td>
      <td align="center"><b>Quick Add</b></td>
    </tr>
    <tr>
      <td width="33%"><img src="assets/images/play_store/en/phone/05.jpg" alt="Calendar and Board" /></td>
      <td width="33%"><img src="assets/images/play_store/en/phone/08.jpg" alt="Share by QR or Link" /></td>
      <td width="33%"><img src="assets/images/play_store/en/phone/06.jpg" alt="8 Languages and RTL" /></td>
    </tr>
    <tr>
      <td align="center"><b>Calendar + Board</b></td>
      <td align="center"><b>Share by QR or Link</b></td>
      <td align="center"><b>8 Languages + RTL</b></td>
    </tr>
  </table>
</div>

## How it works

- **Local first.** Tasks live in Hive on the device, so reads and writes are instant and nothing waits on the network.
- **Sync.** When signed in, changes are pushed to Cloud Firestore and pulled on other devices. Security rules scope every document to its owner. QR "Cloud Link" shares are short-lived snapshots that can be opened by ID but never listed.
- **Widgets** are native Android views fed from the Dart side through `home_widget`, so they update without the app running.
- **Releases** go through GitHub Actions to Google Play. Dart-only fixes ship as Shorebird patches, without a store review.

**Stack:** Flutter, Dart 3, Provider, go_router, Hive CE, Firebase (Auth, Firestore, Crashlytics, Analytics, Remote Config), RevenueCat, Shorebird.

## Run it locally

```bash
git clone https://github.com/RoeeIlouz/ROCIsTasks-Public.git
cd ROCIsTasks-Public
flutter pub get
cp .env.example .env
cp lib/firebase_options.dart.example lib/firebase_options.dart
cp lib/firebase_schedule_options.dart.example lib/firebase_schedule_options.dart
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter run
```

Firebase and RevenueCat setup is in [docs/SETUP.md](docs/SETUP.md). Architecture notes are in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), and the release history in [docs/CHANGELOG.md](docs/CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).
