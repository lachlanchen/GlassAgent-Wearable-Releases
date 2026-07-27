# Security

Do not upload credentials, `.lc` authorization files, keystores, private keys,
device backups, or APKs containing them.

Release manifests are signed offline. The pinned public key fingerprint is:

```text
SHA-256 0c10bd1647a87dfe27e05129bfc3869df1d2c0a6ad7e8300fc981201d9c67c31
```

Clients must reject a release when any signature, profile, URL, package,
activity, file-size, file-digest, version, or APK signer check fails.

Report a suspected release-channel issue privately through the security contact
listed on the applicable product support site.

