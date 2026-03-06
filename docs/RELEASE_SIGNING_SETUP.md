# Release Signature Setup

This is optional. It lets GitHub Releases publish:
- `SHA256SUMS.txt.sig`
- `release-signing-public.pem`

That gives users a way to verify that the checksum file came from your release pipeline.

## User-side verification command

```bash
openssl dgst -sha256 -verify release-signing-public.pem -signature SHA256SUMS.txt.sig SHA256SUMS.txt
```

## Step 1: create a signing key pair

```bash
mkdir -p ~/.dual-n-back-signing
openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out ~/.dual-n-back-signing/release-signing-private.pem
openssl pkey -in ~/.dual-n-back-signing/release-signing-private.pem -pubout -out ~/.dual-n-back-signing/release-signing-public.pem
chmod 600 ~/.dual-n-back-signing/release-signing-private.pem
```

## Step 2: add the private key to GitHub Actions

Base64-encode the private key:

```bash
base64 < ~/.dual-n-back-signing/release-signing-private.pem
```

Create this repository secret:
- Name: `RELEASE_SIGNING_PRIVATE_KEY_B64`
- Value: the base64 output above

## Step 3: verify a release

Push a test tag, or run the release workflow manually with a tag.

The release should include:
- `SHA256SUMS.txt`
- `SHA256SUMS.txt.sig`
- `release-signing-public.pem`

## Security rules

- Never commit the private key
- Rotate the key if compromise is suspected
- Keep key material out of screenshots, notes, and shell history
