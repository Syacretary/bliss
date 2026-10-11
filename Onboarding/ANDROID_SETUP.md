# Android development setup

The project-local Flutter SDK and Pub cache are stored in ignored folders so
they can be writable without changing the machine-wide SDK or user directory:

- `.tooling/flutter-sdk/`
- `.pub-cache/`

Use `./flutter-dev.sh` for Flutter commands from this directory. For example:

```sh
./flutter-dev.sh pub get
./flutter-dev.sh analyze
./flutter-dev.sh run
```

The first setup requires network access to fetch packages. To build the local
WhatsApp runtime as part of the Android APK, install its Node dependencies from
`../WhatsAppBot` first:

```sh
cd ../WhatsAppBot
npm install
cd ../Onboarding
./flutter-dev.sh build apk
```

The Android build also downloads the pinned Node.js Mobile runtime and verifies
its SHA-256 digest. Physical-device pairing and background lifecycle behavior
still need to be tested on an Android phone; this setup does not imply Play
Store publication or readiness.
