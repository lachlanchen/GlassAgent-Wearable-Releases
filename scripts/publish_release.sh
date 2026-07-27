#!/usr/bin/env bash
set -euo pipefail

repo="lachlanchen/GlassAgent-Wearable-Releases"
channel="stable"
profile=""
apk=""
private_key=""
release_id=""
publish="false"

usage() {
  cat <<'EOF'
Usage:
  publish_release.sh --profile lightmind|glassagent --apk FILE \
    --private-key FILE --release-id ID [--publish]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) profile="${2:-}"; shift 2 ;;
    --apk) apk="${2:-}"; shift 2 ;;
    --private-key) private_key="${2:-}"; shift 2 ;;
    --release-id) release_id="${2:-}"; shift 2 ;;
    --publish) publish="true"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ "$profile" == "lightmind" || "$profile" == "glassagent" ]] || {
  echo "--profile must be lightmind or glassagent" >&2
  exit 2
}
[[ -f "$apk" ]] || { echo "APK not found: $apk" >&2; exit 2; }
[[ -f "$private_key" ]] || { echo "Private key not found: $private_key" >&2; exit 2; }
[[ "$release_id" =~ ^[A-Za-z0-9._-]+$ ]] || {
  echo "--release-id must contain only letters, digits, dot, underscore, or hyphen" >&2
  exit 2
}

for command in aapt apksigner jq openssl gh sha256sum; do
  command -v "$command" >/dev/null || {
    echo "Required command not found: $command" >&2
    exit 1
  }
done

case "$profile" in
  lightmind)
    display_name="LightMind Glasses"
    expected_package="art.lightmind.glasses"
    expected_activity="art.lightmind.glasses.GlassesActivity"
    expected_signer_sha1="294c8eaa3e922d461f69e385df143b261d0b4865"
    expected_signer_sha256="24e9af7fc69edf7e204dbd404515bdfdf66fbb37a331241cf9eedc032229539e"
    ;;
  glassagent)
    display_name="GlassAgent Glasses"
    expected_package="art.lazying.glassagent.glasses"
    expected_activity="art.lightmind.glasses.GlassesActivity"
    expected_signer_sha1="6d99e90adf0062336ed033731ea2594c9786a721"
    expected_signer_sha256="23bbb892b6c73566ca8a2fdb15117b61dd536ed555e0404b5da6cd2fd81d43cb"
    ;;
esac

badging="$(aapt dump badging "$apk")"
package_line="$(printf '%s\n' "$badging" | sed -n '1p')"
package_name="$(printf '%s\n' "$package_line" | sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p")"
version_code="$(printf '%s\n' "$package_line" | sed -n "s/^package: name='[^']*' versionCode='\\([^']*\\)'.*/\\1/p")"
version_name="$(printf '%s\n' "$package_line" | sed -n "s/^package: name='[^']*' versionCode='[^']*' versionName='\\([^']*\\)'.*/\\1/p")"
min_sdk="$(printf '%s\n' "$badging" | sed -n "s/sdkVersion:'\\([^']*\\)'/\\1/p" | head -1)"
certificate_output="$(apksigner verify --print-certs "$apk")"
signer_sha1="$(printf '%s\n' "$certificate_output" | sed -n 's/.*SHA-1 digest: //p' | head -1 | tr -d ':' | tr '[:upper:]' '[:lower:]')"
signer_sha256="$(printf '%s\n' "$certificate_output" | sed -n 's/.*SHA-256 digest: //p' | head -1 | tr -d ':' | tr '[:upper:]' '[:lower:]')"

[[ "$package_name" == "$expected_package" ]] || {
  echo "Package mismatch: expected $expected_package, got $package_name" >&2
  exit 1
}
[[ "$signer_sha1" == "$expected_signer_sha1" ]] || {
  echo "SHA-1 signer mismatch" >&2
  exit 1
}
[[ "$signer_sha256" == "$expected_signer_sha256" ]] || {
  echo "SHA-256 signer mismatch" >&2
  exit 1
}
printf '%s\n' "$badging" | grep -Fq "name='$expected_activity'" || {
  echo "Required activity is not declared: $expected_activity" >&2
  exit 1
}

for forbidden in '.lc' '.jks' '.keystore' 'private.pem' 'credentials'; do
  if unzip -Z1 "$apk" | grep -Fiq "$forbidden"; then
    echo "APK contains forbidden path fragment: $forbidden" >&2
    exit 1
  fi
done

file_size="$(stat -c %s "$apk")"
file_sha256="$(sha256sum "$apk" | cut -d' ' -f1)"
tag="wearable-v${version_name}-build${version_code}"
asset_name="${profile}-glasses-display-${version_name}-${version_code}.apk"
artifact_url="https://github.com/${repo}/releases/download/${tag}/${asset_name}"
setup_url="https://lachlanchen.github.io/GlassAgent-Wearable-Releases/?profile=${profile}"
published_at="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
channel_dir="channels/${profile}/${channel}"
manifest="${channel_dir}/manifest.json"
signature="${channel_dir}/manifest.sig"

mkdir -p "$channel_dir"
jq -n \
  --arg profile "$profile" \
  --arg channel "$channel" \
  --arg releaseId "$release_id" \
  --arg publishedAt "$published_at" \
  --arg displayName "$display_name" \
  --arg packageName "$package_name" \
  --arg activityName "$expected_activity" \
  --arg versionName "$version_name" \
  --argjson versionCode "$version_code" \
  --argjson minAndroidSdk "$min_sdk" \
  --argjson fileSizeBytes "$file_size" \
  --arg sha256 "$file_sha256" \
  --arg signerSha1 "$signer_sha1" \
  --arg signerSha256 "$signer_sha256" \
  --arg artifactUrl "$artifact_url" \
  --arg setupUrl "$setup_url" \
  '{
    schemaVersion: 1,
    profile: $profile,
    channel: $channel,
    releaseId: $releaseId,
    publishedAt: $publishedAt,
    displayName: $displayName,
    packageName: $packageName,
    activityName: $activityName,
    versionName: $versionName,
    versionCode: $versionCode,
    minAndroidSdk: $minAndroidSdk,
    fileSizeBytes: $fileSizeBytes,
    sha256: $sha256,
    signerSha1: $signerSha1,
    signerSha256: $signerSha256,
    artifactUrl: $artifactUrl,
    setupUrl: $setupUrl
  }' > "$manifest"

openssl dgst -sha256 -sign "$private_key" -out "${signature}.bin" "$manifest"
base64 -w0 "${signature}.bin" > "$signature"
printf '\n' >> "$signature"
rm -f "${signature}.bin"

public_key="$(dirname "$private_key")/public.pem"
[[ -f "$public_key" ]] || {
  echo "Expected sibling public key not found: $public_key" >&2
  exit 1
}
base64 -d "$signature" > "${signature}.verify.bin"
openssl dgst -sha256 -verify "$public_key" -signature "${signature}.verify.bin" "$manifest"
rm -f "${signature}.verify.bin"

if [[ "$publish" == "true" ]]; then
  gh release view "$tag" --repo "$repo" >/dev/null 2>&1 || \
    gh release create "$tag" --repo "$repo" \
      --title "Wearable companion ${version_name} (${version_code})" \
      --notes "Signed companion software for supported AI glasses. Verify through the product app or the signed channel manifest."
  staging_directory="$(mktemp -d)"
  trap 'rm -rf "$staging_directory"' EXIT
  cp "$apk" "${staging_directory}/${asset_name}"
  gh release upload "$tag" "${staging_directory}/${asset_name}" --repo "$repo" --clobber
fi

printf 'Prepared %s\n' "$manifest"
printf 'APK SHA-256 %s\n' "$file_sha256"
printf 'Artifact %s\n' "$artifact_url"
