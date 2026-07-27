# GlassAgent Wearable Releases

This repository is the public, release-only distribution channel for companion
software installed on supported AI glasses.

It intentionally contains:

- signed release manifests;
- detached manifest signatures;
- public verification keys;
- setup documentation; and
- sanitized APK files attached to immutable GitHub Releases.

It intentionally does not contain source credentials, vendor authorization
files, signing keystores, private keys, or device backups.

## Channels

| Product | Stable manifest |
| --- | --- |
| LightMind Agent | [`channels/lightmind/stable/manifest.json`](channels/lightmind/stable/manifest.json) |
| GlassAgent | [`channels/glassagent/stable/manifest.json`](channels/glassagent/stable/manifest.json) |

The phone apps verify the raw manifest with ECDSA P-256/SHA-256, then verify the
APK byte count, SHA-256 digest, Android package ID, declared activity, and APK
signing certificate before enabling any provisioning action.

## Publish

Publishing is intentionally local and fail-closed. The distribution private key
stays outside this repository.

The script supports Linux and macOS. Put Android SDK `aapt` and `apksigner` from
the same build-tools directory on `PATH`, and install `jq`, `openssl`, and `gh`.

```bash
scripts/publish_release.sh \
  --profile lightmind \
  --apk /absolute/path/to/glasses-display-release.apk \
  --private-key /absolute/path/to/private.pem \
  --release-id 20260727-build20 \
  --publish
```

Run the command once per product profile. Without `--publish`, it only builds and
verifies the channel files.

## Platform behavior

- Android can download and verify an APK, then hand it to a supported,
  vendor-authorized glasses transport after explicit confirmation.
- iPhone and iPad can verify and share the same release, but iOS cannot execute
  an Android package installation. A supported Android or USB setup path remains
  required unless the hardware vendor provides an authorized remote installer.
- Existing glasses packages are never silently uninstalled or replaced.

See the [setup site](https://lachlanchen.github.io/GlassAgent-Wearable-Releases/).
