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

function selectedProfile() {
  const requested = new URLSearchParams(location.search).get("profile");
  return profiles.has(requested) ? requested : "lightmind";
}

function formatBytes(bytes) {
  return `${(bytes / 1024 / 1024).toFixed(1)} MiB`;
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
    const response = await fetch(`channels/${profile}/stable/manifest.json`, {
      cache: "no-store",
    });
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    const manifest = await response.json();
    if (manifest.profile !== profile || manifest.schemaVersion !== 1) {
      throw new Error("profile mismatch");
    }

    status.textContent = "Release available";
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

