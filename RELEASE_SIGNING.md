# Release signing

The release build is signed from `android/key.properties`. That file and the
keystore it points at are gitignored and **must never be committed** — anyone
holding them can ship updates impersonating this app.

If `key.properties` is absent the build falls back to the debug key so
`flutter run --release` still works, and prints a warning. A debug-signed APK
**cannot be uploaded to Play Console** and will fail to install over a build
signed with any other key.

---

## One-time setup

### 1. Generate a keystore

Run from the repo root. Choose a strong password and answer the prompts:

```bash
keytool -genkey -v \
  -keystore ~/magnum-opus-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias magnumopus
```

> Keep `~/magnum-opus-release.jks` **outside** the repo so it cannot be
> committed by accident.

### 2. Create `android/key.properties`

```properties
storePassword=<the store password you just chose>
keyPassword=<the key password you just chose>
keyAlias=magnumopus
storeFile=/home/user/magnum-opus-release.jks
```

`storeFile` must be an absolute path, or a path relative to `android/`.

### 3. Build

```bash
flutter build apk --release
```

Gradle prints no warning when the keystore is picked up. If you still see the
"signing the release build with the DEBUG key" warning, `key.properties` was
not found — check the path and filename.

---

## Back this up

**If you lose the keystore you can never update the app on Play again.** You
would have to publish under a new package name and lose all installs and
reviews. Store the `.jks` and both passwords in a password manager before
publishing.

(Play App Signing mitigates this — Google holds the signing key and you upload
with an upload key you *can* reset. Enable it when you first create the app in
Play Console; it is the recommended default.)

---

## Store builds

Play wants an App Bundle, not an APK:

```bash
flutter build appbundle --release
```

Use `flutter build apk --release` only for sideloading and manual testing.
