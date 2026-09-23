import { Router } from 'express';

// Digital Asset Links file Android reads to verify this domain is allowed
// to open the app directly (App Links) instead of falling back to the
// browser — must be served at the literal site root, unauthenticated,
// as application/json. See:
// https://developer.android.com/training/app-links/verify-android-applinks
//
// Only the local debug keystore's fingerprint is listed for now — add the
// release keystore's SHA256 (`keytool -list -v -keystore <release>.jks`)
// here too once one exists, or verification will fail for release builds.
const ANDROID_PACKAGE_NAME = 'com.okoye.socialapp';
const ANDROID_SHA256_CERT_FINGERPRINTS = [
  '3F:44:C2:70:48:55:01:62:93:BD:55:E4:21:55:AB:DE:4C:01:95:66:F8:1A:44:A2:ED:5C:82:49:FA:F6:9A:53',
];

// iOS Universal Links equivalent of assetlinks.json — must be served at
// the literal site root (no .json extension), unauthenticated, as
// application/json. See:
// https://developer.apple.com/documentation/xcode/supporting-associated-domains
//
// appID is "<Apple Team ID>.<bundle ID>". T22LW4QXWX is Peter Okoye's free
// Xcode Personal Team, cached locally in
// ~/Library/Preferences/com.apple.dt.Xcode.plist — fine for local dev
// signing, but swap it for the real team ID once this ships under a paid
// Apple Developer Program account.
const IOS_APP_ID = 'T22LW4QXWX.com.okoye.socialapp';

export const wellKnownRouter = Router();

wellKnownRouter.get('/assetlinks.json', (_req, res) => {
  res.json([
    {
      relation: ['delegate_permission/common.handle_all_urls'],
      target: {
        namespace: 'android_app',
        package_name: ANDROID_PACKAGE_NAME,
        sha256_cert_fingerprints: ANDROID_SHA256_CERT_FINGERPRINTS,
      },
    },
  ]);
});

wellKnownRouter.get('/apple-app-site-association', (_req, res) => {
  res.type('application/json').json({
    applinks: {
      details: [
        {
          appIDs: [IOS_APP_ID],
          components: [{ '/': '/share/posts/*' }],
        },
      ],
    },
  });
});
