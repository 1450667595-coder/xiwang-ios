# Backend integration boundary

The iOS app does not contain a provider-specific hostname. The hosted web application remains the business client; this repository only supplies the iOS container and its secure same-origin policy.

## Runtime configuration

Set the Xcode build setting `BACKEND_BASE_URL` to the HTTPS origin of the replacement deployment. The value is injected into `Info.plist` and read by `BackendConfiguration`. If it is missing or not HTTPS, the app refuses to navigate and shows its retry state.

## Existing HTTP contract

The hosted web client currently expects these routes from the backend origin:

- `POST /api/auth` — device/session authorization
- `GET|POST /api/records` — training records and plan data
- `GET|POST /api/appearance` — preferences and optional wallpaper data
- `POST /api/care` — care records
- `POST /api/ai` — assistant requests

The replacement service must preserve the JSON contract, bearer-token behavior, revision conflict responses (`409`), and idempotent session identifiers before the iOS app is pointed at it.

## Data ownership

No database driver, schema, credentials, or persistence SDK is present in this iOS repository. Data export and import belong to the backend project. Do not put database credentials in this repository or in the iOS app. Export data separately, validate it against the API contract, then import it into the replacement service.
