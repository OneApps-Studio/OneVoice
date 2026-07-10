# CloudKit schema

OneVoice syncs through the private database of `iCloud.studio.oneapps.onevoice` in the custom zone `OneVoiceSync`. The app never uses a public CloudKit database or a OneVoice-operated server.

## Record types

### `VoiceEntry`

| Field | CloudKit type | Required by new records |
| --- | --- | --- |
| `id` | String | Yes |
| `rawTranscript` | String | Yes |
| `transcript` | String | Yes |
| `createdAt` | Date/Time | Yes |
| `duration` | Double | Yes |
| `localeIdentifier` | String | Yes |
| `engineIdentifier` | String | Yes |
| `source` | String | Yes |
| `isFavorite` | Int64 | Yes |
| `title` | String | No, for compatibility with 1.0 records |
| `audioFileName` | String | No |
| `audioByteCount` | Int64 | No |
| `audioAsset` | Asset | No |

### `DictionaryReplacement`

| Field | CloudKit type | Required |
| --- | --- | --- |
| `id` | String | Yes |
| `spoken` | String | Yes |
| `written` | String | Yes |

## Release gate

1. Run a development-signed Release build on a physical device signed into iCloud.
2. Create one voice note and one dictionary replacement, then verify both record types and `audioAsset` in the development environment.
3. Deploy the development schema to production in CloudKit Console before uploading the App Store build.
4. Install the exported distribution build and verify that it uses the production CloudKit environment.
5. Record on iOS, wait for sync, and verify playback plus transcript search on the notarized macOS build.

Never reset the development schema when it contains the only copy of release-test recordings. CloudKit production deployment changes schema only; it does not copy development records into production.
