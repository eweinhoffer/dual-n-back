# Release Signing Setup (Optional)

This project can optionally sign release checksum manifests in CI.

When configured, each GitHub Release also includes:
- `SHA256SUMS.txt.sig`
- `release-signing-public.pem`

Users can then verify authenticity with:

```bash
openssl dgst -sha256 -verify release-signing-public.pem -signature SHA256SUMS.txt.sig SHA256SUMS.txt
```

## 1) Generate a key pair

```bash
mkdir -p ~/.dual-n-back-signing
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out ~/.dual-n-back-signing/release-signing-private.pem
openssl pkey -in ~/.dual-n-back-signing/release-signing-private.pem -pubout -out ~/.dual-n-back-signing/release-signing-public.pem
chmod 600 ~/.dual-n-back-signing/release-signing-private.pem
```

## 2) Add private key to GitHub Actions secrets

Base64-encode the private key:

```bash
base64 < ~/.dual-n-back-signing/release-signing-private.pem
```

Create repository secret:
- Name: `RELEASE_SIGNING_PRIVATE_KEY_B64`
- Value: base64 output above

## 3) Verify workflow behavior

- Push a test tag (or run manual release workflow with `release_tag`).
- Confirm release includes:
  - `SHA256SUMS.txt`
  - `SHA256SUMS.txt.sig`
  - `release-signing-public.pem`

## Security notes

- Never commit the private key.
- Rotate keys if compromise is suspected.
- Keep key material out of shell history and shared screenshots.
