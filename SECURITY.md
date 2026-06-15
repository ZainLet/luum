# Security Policy

## Supported Versions

Luum is still in alpha. Security fixes are applied to the active alpha branch and to the newest alpha release only.

| Version | Supported |
| --- | --- |
| `v0.0.x-alpha` / newest alpha | Yes |
| Older alpha builds | Best effort only |
| Unreleased local builds | No public support |

## Reporting a Vulnerability

Report security issues privately to `oluum.app@gmail.com`. Do not open a public issue with secrets, tokens, customer data, screenshots of API keys, or exploit details.

Please include:

- A short description of the issue and affected surface: macOS app, website, Vercel API, Firebase/Firestore, Stripe, or installer.
- Steps to reproduce with a test account when possible.
- Any relevant request IDs, timestamps, or sanitized logs.
- Whether any Firebase ID token, Stripe key, Gemini key, Resend key, webhook secret, or user backup data may have been exposed.

Expected handling:

- We acknowledge reproducible reports as soon as practical.
- We prioritize issues involving account takeover, payment/billing changes, Firebase backup access, leaked integration secrets, or installer trust.
- We publish fixes in the next alpha build when the fix affects the macOS app, or redeploy the Vercel/Firebase backend when the fix is server-side.

## Secret Handling

Never commit production secrets to this repository. Production credentials must live in Vercel environment variables, the encrypted admin integration store, Firebase/Stripe dashboards, or a separate password manager.

Sensitive values include:

- `FIREBASE_SERVICE_ACCOUNT_JSON`
- `LUUM_SETTINGS_ENCRYPTION_KEY`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `GEMINI_API_KEY`
- `RESEND_API_KEY`
- OAuth client secrets, refresh tokens, Zapier webhook URLs, workspace secrets, and private keys.

The repository test suite includes a regression scan for common private key patterns. If a real secret is ever committed, rotate it immediately in the external provider, remove it from the active branch, and treat any built artifacts from that commit as untrusted.

Public Firebase web API keys and public OAuth client IDs are not treated as private secrets, but they must only point at the official Luum project and must be protected by Firebase Auth, Firestore rules, allowed origins, and backend validation.

## Production Boundaries

- Official website: `https://luum-app.web.app`
- Official backend API: `https://luum-app.vercel.app`
- Official Firebase project: `luum-app`
- macOS bundle id: `com.luum.apple`

The macOS app should send Firebase ID tokens only to the official backend. Login, plan status, cloud backup, weekly PDF email, workspace ranking, and AI classification should not be redirected to arbitrary local preferences or third-party endpoints in production.

## macOS Alpha Distribution

Current alpha builds are signed ad-hoc and packaged as a `.pkg` installer that places `luum.app` in `/Applications`. Until the Apple Developer Program, Developer ID signing, hardened runtime, and notarization are configured, Gatekeeper may require `Control-click > Open` on first launch.

The app avoids the macOS Keychain by default in ad-hoc builds and stores local session data in an encrypted local vault to reduce repeated password prompts when signatures change between alpha builds.
