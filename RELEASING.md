# Releasing DataBar

This document describes how to set up and create releases for DataBar.

## One-Time Setup

Before you can create releases, you need to configure GitHub secrets and generate signing keys.

### 1. Create a Developer ID Application Certificate for CI

Generate a new certificate specifically for CI use:

```bash
# Generate a private key and CSR
openssl req -new -newkey rsa:2048 -nodes \
  -keyout ci_signing_key.key \
  -out ci_signing_request.csr \
  -subj "/CN=DataBar CI/C=US"
```

Then:
1. Go to [developer.apple.com/account/resources/certificates](https://developer.apple.com/account/resources/certificates)
2. Click **+** to create a new certificate
3. Select **Developer ID Application**
4. Upload `ci_signing_request.csr`
5. Download the `.cer` file

Convert to .p12 format:

```bash
# Convert .cer to .pem
openssl x509 -in developerID_application.cer -inform DER -out cert.pem

# Create .p12 with the private key
openssl pkcs12 -export -out ci_certificate.p12 \
  -inkey ci_signing_key.key \
  -in cert.pem \
  -password pass:YOUR_PASSWORD

# Base64 encode for GitHub secret
base64 -i ci_certificate.p12 | pbcopy
```

**Important:** Store `ci_signing_key.key` securely - you'll need it if you ever need to regenerate the .p12.

### 2. Create an App Store Connect API Key

This is used for notarization without needing Apple ID credentials:

1. Go to [appstoreconnect.apple.com/access/integrations/api](https://appstoreconnect.apple.com/access/integrations/api)
2. Click **+** to generate a new key
3. Name it "DataBar CI" and give it **Developer** access
4. Download the `.p8` file (you can only download it once!)
5. Note the **Key ID** (shown in the table) and **Issuer ID** (shown at the top)

Base64 encode the API key:

```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy
```

### 3. Generate Sparkle EdDSA Signing Keys

Sparkle uses EdDSA (Ed25519) keys to sign updates:

```bash
# Download Sparkle tools
curl -L -o sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/download/2.6.4/Sparkle-2.6.4.tar.xz
mkdir sparkle && tar -xf sparkle.tar.xz -C sparkle

# Generate the key pair
./sparkle/bin/generate_keys
```

This outputs:
- A **private key** - add to `SPARKLE_PRIVATE_KEY` secret
- A **public key** - add to `DataBar/Info.plist` as `SUPublicEDKey`

### 4. Configure GitHub Secrets

Go to **Repository → Settings → Secrets and variables → Actions → New repository secret**

Add the following secrets:

| Secret | Description |
|--------|-------------|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded .p12 certificate from step 1 |
| `APPLE_CERTIFICATE_PASSWORD` | Password you used when creating the .p12 |
| `KEYCHAIN_PASSWORD` | Any random password (used temporarily in CI) |
| `CODE_SIGN_IDENTITY` | `Developer ID Application: Samuel Marks (MNG2GFU9S3)` |
| `DEVELOPMENT_TEAM` | `MNG2GFU9S3` |
| `APPLE_API_KEY_ID` | Key ID from App Store Connect (e.g., `XXXXXXXXXX`) |
| `APPLE_API_ISSUER_ID` | Issuer ID from App Store Connect (UUID format) |
| `APPLE_API_KEY_BASE64` | Base64-encoded .p8 API key file |
| `SPARKLE_PRIVATE_KEY` | EdDSA private key from step 3 |

### 5. Update Info.plist with Public Key

Edit `DataBar/Info.plist` and set the `SUPublicEDKey` value:

```xml
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
```

## Creating a Release

Once setup is complete, creating a release is simple:

### 1. Create and Push a Tag

```bash
# Create a new version tag
git tag v1.0.1

# Push the tag to trigger the release workflow
git push origin v1.0.1
```

### 2. Automated Release Process

The GitHub Action will automatically:

1. Build the app in Release configuration
2. Sign with your Developer ID certificate
3. Notarize with Apple (using API key)
4. Staple the notarization ticket
5. Create a GitHub Release with the signed, notarized app
6. Sign the update with Sparkle
7. Update `appcast.xml` with the new version info
8. Commit and push the updated appcast

### 3. Verify the Release

After the workflow completes:

1. Check the [Releases page](https://github.com/sammarks/DataBar/releases)
2. Download and verify the app opens without Gatekeeper warnings
3. Verify "Check for Updates..." works from the menu

## How Auto-Updates Work

1. User clicks "Check for Updates..." in the menu bar
2. Sparkle fetches `appcast.xml` from the raw GitHub URL
3. If a newer version exists, Sparkle shows an update prompt
4. User clicks "Install Update"
5. Sparkle downloads the zip from GitHub Releases
6. Sparkle verifies the EdDSA signature
7. App restarts with the new version

## Troubleshooting

### Build fails with signing errors

- Verify `CODE_SIGN_IDENTITY` matches exactly: `Developer ID Application: Samuel Marks (MNG2GFU9S3)`
- Ensure the certificate hasn't expired
- Check that `DEVELOPMENT_TEAM` is `MNG2GFU9S3`

### Notarization fails

- Verify `APPLE_API_KEY_ID` and `APPLE_API_ISSUER_ID` are correct
- Make sure the API key has **Developer** access level
- Check that the .p8 file was base64 encoded correctly
- Ensure hardened runtime is enabled in Xcode project

### Updates not detected

- Verify `appcast.xml` was updated and pushed to main
- Check that `SUFeedURL` in Info.plist points to: `https://raw.githubusercontent.com/sammarks/DataBar/main/appcast.xml`
- Ensure the version numbers are increasing

### Signature verification fails

- Verify `SUPublicEDKey` in Info.plist matches the private key used for signing
- Ensure `SPARKLE_PRIVATE_KEY` secret contains the full private key

## Security Notes

- The API key approach is more secure than Apple ID + app-specific password
- API keys can be revoked instantly from App Store Connect
- The .p8 file should never be committed to the repository
- Keep backups of `ci_signing_key.key` and the Sparkle private key
