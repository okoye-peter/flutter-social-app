# Post Sharing & App Links / Universal Links

How tapping "share" on a reel gets from the device's native share sheet to
either a rich link-preview card (WhatsApp, Twitter, etc.) or straight back
into the app, on both Android and iOS. Implemented — spans `mobile` and
`backend`.

## Decisions

- **Share plain text + a link, not a custom URI scheme.** A custom scheme
  (`socialapp://post/123`) only works if the app is already installed and
  can't be unfurled into a preview card by WhatsApp/Twitter — they only
  render previews for real `https://` URLs by fetching Open Graph tags from
  them server-side. So sharing needed a real, publicly fetchable webpage per
  post.
- **The preview page is unauthenticated and lives outside `/api`.** Link
  crawlers (WhatsApp, Twitter, etc.) have no auth token, so
  `GET /share/posts/:id` is mounted directly on the app (not behind
  `requireAuth`, not under the `/api` prefix — this isn't a JSON API
  response, it's an HTML page).
- **App Links / Universal Links, not a browser-only link.** Since the link
  is a real `https://` URL, the OS can also be told "this app handles links
  from this domain" — Android verifies that via `assetlinks.json` and iOS
  via `apple-app-site-association`, both hosted on the same domain, so
  tapping the link opens the app directly instead of falling back to a
  browser tab. This is why the domain in `APP_URL` and the domain
  referenced on both native sides must always match exactly.
- **iOS uses the free Xcode Personal Team, for now.** Universal Links need
  an Apple Team ID in the `appID`/entitlement. No paid Apple Developer
  Program account exists for this project yet, so it's wired up with the
  free Personal Team (`T22LW4QXWX`) cached in Xcode locally — works fine
  for on-device dev/testing, but that provisioning profile expires after 7
  days (re-open the project in Xcode to refresh it), and this ID must be
  swapped for a real paid-account Team ID before shipping.

## Structure

**Backend** (`backend/src/`):
- `lib/html.ts` — `escapeHtml()`, used so user-generated captions/names
  can't inject HTML/script into the preview page.
- `services/post.ts` — `getPostPreview(postId)`: minimal, viewer-agnostic
  fetch (caption, mediaType, mediaUrl, thumbnailUrl, author name/username).
  No `likedByMe`/etc. — there's no authenticated viewer for a crawler.
- `controllers/share.ts` + `routes/share.ts` — `GET /share/posts/:id`
  renders the OG/Twitter-card HTML. 404s render a plain HTML "not
  available" page rather than a JSON error, since a browser/crawler hits
  this, not the app.
- `routes/well-known.ts` — `GET /.well-known/assetlinks.json`, the Android
  Digital Asset Links file. Declares the app's package name
  (`com.okoye.socialapp`) and signing-key SHA256 fingerprint(s) as
  authorized to open links from this domain. **Only the local debug
  keystore's fingerprint is listed right now** — add the release keystore's
  SHA256 here too before shipping a release build, or App Link verification
  will fail for it. Same file also serves
  `GET /.well-known/apple-app-site-association` for iOS — the `appID` is
  `<Apple Team ID>.com.okoye.socialapp`.
- `.env` — `APP_URL`: the server's own public base URL, used to build the
  absolute `og:url` and to know what domain the app should be told to
  claim. No trailing slash.

**Mobile** (`mobile/lib/`):
- `core/constants/api_constants.dart` — `ApiConstants.appUrl`: derives the
  public base URL from `API_BASE_URL` by stripping the trailing `/api`, so
  there's one source of truth for the host instead of a second env var.
- `views/feeds/widgets/reels_tile.dart` — `_shareReel()` builds
  `'${ApiConstants.appUrl}/share/posts/$postId'` and passes it to
  `SharePlus.instance.share(ShareParams(...))` (the current `share_plus`
  v13+ API — the old static `Share.share()` is deprecated).
- `android/app/src/main/AndroidManifest.xml` — a second `intent-filter` on
  `MainActivity` with `android:autoVerify="true"`, matching
  `https://<APP_URL host>/share/posts/*`.
- `ios/Runner/Runner.entitlements` — `com.apple.developer.associated-domains`
  = `applinks:<APP_URL host>`.
- `ios/Runner.xcodeproj/project.pbxproj` — the Runner target's Debug/
  Release/Profile configs now set `CODE_SIGN_ENTITLEMENTS`,
  `CODE_SIGN_STYLE = Automatic`, and `DEVELOPMENT_TEAM` (previously unset —
  iOS signing wasn't configured in this project at all before this).
- `core/router/routes.dart` — the `GoRouter` `redirect:` callback maps an
  incoming `/share/posts/:id` link (App Link or Universal Link — the OS
  hands go_router the same thing either way) to the existing `/feeds/:id`
  route, so it opens the same `ViewReelDetailsScreen` an in-app tap would.
  No platform-specific code needed here.

## Maintenance: the ngrok domain rotates

`APP_URL` currently points at the dev ngrok tunnel
(`impure-hungry-gentleman.ngrok-free.dev`), which is **not stable** — a free
ngrok tunnel gets a new random subdomain every time it restarts. Whenever
that happens, all of the following must be updated together, or App Links
silently fall back to opening the browser instead of the app:

1. `backend/.env` — `APP_URL`
2. `mobile/.env` — `API_BASE_URL` (already needs updating for the API to
   work at all)
3. `mobile/android/app/src/main/AndroidManifest.xml` — the App Links
   intent-filter's `android:host`
4. `mobile/ios/Runner/Runner.entitlements` — the `applinks:` domain
5. Reinstall the app on Android (manifest changes require a fresh install,
   not just hot reload/restart) and re-verify:
   `adb shell pm verify-app-links --re-verify com.okoye.socialapp`
6. Rebuild/reinstall on iOS too — a changed Associated Domains entitlement
   needs a fresh provisioning profile, which Xcode only regenerates on a
   real build, not a hot reload

Before this goes out for real, swap `APP_URL` for a stable domain so shared
links (and App Link verification) don't break on every backend restart.

## Follow-up (not yet done)

- **Real Apple Team ID.** `IOS_APP_ID` in `well-known.ts` and
  `DEVELOPMENT_TEAM` in the Xcode project both use the free Personal Team
  (`T22LW4QXWX`) — fine for local dev, but swap both for a paid Apple
  Developer Program Team ID before shipping (personal-team provisioning
  also expires every 7 days, so it isn't viable for distribution anyway).
- **Release keystore fingerprint (Android).** `well-known.ts` only lists
  the local debug keystore's SHA256. Add the release signing key's
  fingerprint before shipping, or release builds won't verify as App
  Links.
- **Deep-link target lost through a login redirect.** If someone taps a
  shared link while logged out, `redirect:` sends them to `/login` and the
  original post id isn't preserved — they land on the default feed after
  logging in, not the shared post. Not handled; low priority since this is
  mainly a dev-testing flow today.
- **`shareCount`.** Purely a widget-level default (`0`) — there's no
  backend field or endpoint tracking it, so tapping share never increments
  anything real.
