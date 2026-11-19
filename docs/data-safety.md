# Cineva — Google Play "Data safety" form answers

Use this as the source of truth when filling out Play Console →
**App content → Data safety**.

## Does the app collect or share user data?

**Yes — via third-party SDKs.** Cineva itself has no server and collects no
personal data, but the Google Mobile Ads SDK (AdMob) processes device data.

## Data collected

| Data type | Collected? | Shared? | Purpose | Notes |
|---|---|---|---|---|
| Personal info (name, email, phone, address) | No | No | — | App never asks for or sends these |
| Financial info | No | No | — | App is free, no purchases |
| Health & fitness | No | No | — | — |
| Messages | No | No | — | — |
| Photos & videos | No | No | — | Posters load from TMDB CDN but are not stored as user data |
| Audio files | No | No | — | — |
| Files & docs | No | No | — | — |
| Calendar | No | No | — | — |
| Contacts | No | No | — | — |
| App activity (searches, lists, ratings, notes) | No (device-only) | No | — | Stored locally in SQLite; never transmitted |
| Web browsing history | No | No | — | — |
| App info & performance (crash logs, diagnostics) | No | No | — | No crash-reporting SDK integrated |
| Device or other IDs (advertising ID) | **Yes** | **Yes** | Advertising / analytics | Google Mobile Ads SDK |
| Approximate location | **Yes** | **Yes** | Advertising | Country-code level only, via AdMob |
| Other app performance data | Possibly | Possibly | Advertising | AdMob SDK standard collection |

## Required declarations

- **Data is encrypted in transit**: Yes (HTTPS to TMDB, Google, YouTube)
- **Users can request data deletion**: Yes — in-app "delete all data" plus
  uninstall; contact muhammetfatihdemr@gmail.com
- **Committed to Play Families policy**: The app targets 13+; select the
  appropriate target audience accordingly. If the app is **not** directed at
  children, you can state that.
- **Advertising ID declaration**: The app uses the advertising ID → declare it
  in the Play Console advertising ID section.
- **Privacy policy URL**: host `docs/privacy-policy.md` somewhere public
  (e.g. GitHub Pages) and paste the URL in Play Console.

## Notes

- TMDB requests are anonymous (API key only, language + region params). TMDB
  server logs are governed by TMDB's own privacy policy.
- No account system, no analytics SDK, no crash reporting, no data sale.
