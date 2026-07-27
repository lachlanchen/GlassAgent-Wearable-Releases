const profiles = new Set(["lightmind", "glassagent"]);
const selector = document.querySelector("#profile");
const status = document.querySelector("#status");
const summary = document.querySelector("#summary");
const version = document.querySelector("#version");
const packageName = document.querySelector("#package");
const size = document.querySelector("#size");
const digest = document.querySelector("#digest");
const download = document.querySelector("#download");
const copy = document.querySelector("#copy");
const publicKeyBase64 =
  "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEtnWXZjnDXmmCHggYZFDfVJo41C9hWyzZIyL31dvsL8FsxX03NpqahHkUhzWUOaDGfx2JB7c6XuUqIRkEjZQi4g==";

function selectedProfile() {
  const requested = new URLSearchParams(location.search).get("profile");
  return profiles.has(requested) ? requested : "lightmind";
}

function formatBytes(bytes) {
  return `${(bytes / 1024 / 1024).toFixed(1)} MiB`;
}

function decodeBase64(value) {
  return Uint8Array.from(atob(value), (character) => character.charCodeAt(0));
}

function derIntegerToFixed(bytes, width) {
  let start = 0;
  while (start < bytes.length - 1 && bytes[start] === 0) start += 1;
  const value = bytes.slice(start);
  if (value.length > width) throw new Error("ECDSA integer is too large");
  const fixed = new Uint8Array(width);
  fixed.set(value, width - value.length);
  return fixed;
}

function derSignatureToRaw(der) {
  let offset = 0;
  if (der[offset++] !== 0x30) throw new Error("Invalid ECDSA sequence");
  const sequenceLength = der[offset++];
  if (sequenceLength !== der.length - offset || der[offset++] !== 0x02) {
    throw new Error("Invalid ECDSA sequence length");
  }
  const rLength = der[offset++];
  const r = der.slice(offset, offset + rLength);
  offset += rLength;
  if (der[offset++] !== 0x02) throw new Error("Invalid ECDSA scalar");
  const sLength = der[offset++];
  const s = der.slice(offset, offset + sLength);
  offset += sLength;
  if (offset !== der.length) throw new Error("Trailing ECDSA data");
  const raw = new Uint8Array(64);
  raw.set(derIntegerToFixed(r, 32), 0);
  raw.set(derIntegerToFixed(s, 32), 32);
  return raw;
}

async function verifyManifest(manifestBytes, signatureText) {
  if (!globalThis.crypto?.subtle) throw new Error("WebCrypto unavailable");
  const publicKey = await crypto.subtle.importKey(
    "spki",
    decodeBase64(publicKeyBase64),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["verify"],
  );
  const signature = derSignatureToRaw(
    decodeBase64(signatureText.trim()),
  );
  return crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    publicKey,
    signature,
    manifestBytes,
  );
}

async function loadRelease(profile) {
  status.textContent = "Checking release";
  status.style.color = "";
  summary.textContent = "Loading the signed release manifest.";
  download.removeAttribute("href");
  download.classList.add("disabled");
  download.setAttribute("aria-disabled", "true");
  copy.disabled = true;

  try {
    const [manifestResponse, signatureResponse] = await Promise.all([
      fetch(`channels/${profile}/stable/manifest.json`, { cache: "no-store" }),
      fetch(`channels/${profile}/stable/manifest.sig`, { cache: "no-store" }),
    ]);
    if (!manifestResponse.ok || !signatureResponse.ok) {
      throw new Error("Release record unavailable");
    }
    const manifestBytes = await manifestResponse.arrayBuffer();
    const signatureText = await signatureResponse.text();
    if (!(await verifyManifest(manifestBytes, signatureText))) {
      throw new Error("Release signature invalid");
    }
    const manifest = JSON.parse(new TextDecoder().decode(manifestBytes));
    if (manifest.profile !== profile || manifest.schemaVersion !== 1) {
      throw new Error("profile mismatch");
    }

    status.textContent = "Signature verified";
    summary.textContent = `${manifest.displayName} is ready for a verified Android or USB setup path.`;
    version.textContent = `${manifest.versionName} (${manifest.versionCode})`;
    packageName.textContent = manifest.packageName;
    size.textContent = formatBytes(manifest.fileSizeBytes);
    digest.textContent = manifest.sha256;
    download.href = manifest.artifactUrl;
    download.classList.remove("disabled");
    download.removeAttribute("aria-disabled");
    copy.disabled = false;
    copy.onclick = async () => {
      await navigator.clipboard.writeText(manifest.artifactUrl);
      copy.textContent = "Copied";
      setTimeout(() => { copy.textContent = "Copy installer link"; }, 1600);
    };
  } catch (error) {
    status.textContent = "Release unavailable";
    status.style.color = "#b33a2f";
    summary.textContent = "The release record could not be loaded. Do not install an unverified file.";
    version.textContent = "-";
    packageName.textContent = "-";
    size.textContent = "-";
    digest.textContent = "-";
  }
}

selector.value = selectedProfile();
selector.addEventListener("change", () => {
  const url = new URL(location.href);
  url.searchParams.set("profile", selector.value);
  history.replaceState({}, "", url);
  loadRelease(selector.value);
});
loadRelease(selector.value);
