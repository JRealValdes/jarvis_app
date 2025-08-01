# 🤖 J.A.R.V.I.S. App

**Front-end mobile app for interacting with the Jarvis assistant.**  
Fast, customizable, and connected to your own backend.
See: https://github.com/JRealValdes/jarvis

---

## 📱 Download

Want to try it now?

👉 [Download APK](.app_release/jarvis_1.1.0.apk) *(Android, latest stable build)*

> You may need to allow installation from unknown sources on your device.

---

## 🚀 Getting Started (Dev)

1. Clone the repo and open it in your favorite Flutter IDE.
2. Add your Firebase config file at:

```
android/app/google-services.json
```

Generate it from: [https://console.firebase.google.com](https://console.firebase.google.com)

3. Build and run:

```bash
flutter pub get
flutter run
```

---

## 📌 Features

- ✅ Basic chat UI with message persistence
- ✅ Reset chat button
- ✅ Secure login with username/password
- ✅ Autocomplete login with stored credentials
- ✅ Token-based session via Firebase
- ⏳ Recover session on app reopen
- ⏳ Admin features (global reset, user tracking)
- ⏳ Voice transcription support

---

## 🛣️ Roadmap

- [x] Basic app
- [x] Reset chat button
- [x] Persistent login
- [x] Remember username and password
- [ ] Individual chat-reset option
- [ ] Admin will have 2 reset buttons: individual and global
- [ ] User identification through first login, username as thread ID
- [ ] Recover chat from session when reopening app
- [ ] Manage token expiration
- [ ] Voice transcription

---

## 🛠 Tech Stack

- Flutter (Dart)
- Firebase Auth + Firestore
- REST API backend (custom)
