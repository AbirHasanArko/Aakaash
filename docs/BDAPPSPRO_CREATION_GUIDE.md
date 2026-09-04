# AppsPro App Creation Guide

Aakaash talks to the **AppsPro** SDK at `https://api.appspro.dev/api/v1/`
for its BDApps subscription flow. AppsPro sits in front of the
[BDApps Developer Portal](https://developer.bdapps.com) and gives you a
hosted checkout, a no-code dashboard, and analytics on top of the raw
BDApps protocol — so you don't need to run a PHP backend or own a
domain.

The app uses the **BDApps OTP flow** (send OTP → user dials USSD or
confirms in-app → registration confirmed). Charges appear on the user's
mobile bill and are remitted to you minus the operator's share.

## 1. Prerequisites

Before you start, you need:

- A **live APK** of Aakaash built in release mode with your AppsPro
  secret key:

  ```bash
  flutter build apk --release \
    --dart-define=APPSPRO_SECRET_KEY=secret_key_live_xxxxxxxxxxxxxxxxxxxxxxxx
  ```

- An **AppsPro** account at <https://appspro.dev> with a fully onboarded
  app (operator approved, BDApps portal URL config completed).
- A short description, full description, and 5–8 screenshots of the app.
- A 512×512 app icon (PNG, transparent background).

## 2. Create the app on AppsPro

1. Sign in to <https://appspro.dev> and click **Create app**.
2. Fill in the basic info:
   - **App name**: `Aakaash`
   - **Short description** (≤ 80 chars):
     `Beautiful Bangladesh weather: 5-day + hourly forecasts, GPS, calamities.`
   - **Long description**: paste the "long description" template below.
   - **Category**: `Utility / Weather`
   - **Default language**: English
   - **Country**: Bangladesh
3. Copy the **App ID** (UUID), **Publishable Key** (`pk_...`), and
   **Secret Key** (`sk_live_...`) from the dashboard — you'll bake the
   secret key into the APK at build time.
4. Set the **Checkout URL slug** (e.g. `f6N5yeCno1`) so the deep-link
   `https://appspro.dev/s/<slug>` matches what Aakaash's "Subscribe"
   flow opens.

## 3. Long description template

Drop this into the long description field on the portal:

```
Aakaash (আকাশ) is the most beautiful weather app made for Bangladesh —
a glassmorphism, gradient-rich forecast app focused on the cities and
storms that matter here.

WHAT'S IN THE APP
• 5-day forecast for 70+ Bangladesh cities (divisions, districts, upazilas)
• 24-hour hourly strip with precipitation chance and temperature curve
• GPS "use my current location" with last-known-position fallback
• Natural Calamities dashboard: earthquakes (USGS), cyclones & floods
  (GDACS), and country briefings (ReliefWeb), filtered to the Bangladesh
  and Bay-of-Bengal region on a hand-drawn Bangladesh map
• Six-tile atmospheric highlights grid (humidity, wind, UV, pressure,
  visibility, dew point)
• Day/night gradient themes that shift with the current weather code
• Glassmorphism cards on adaptive backgrounds
• Works on Robi and Cirkle

WHY SUBSCRIBE (Aakaash Premium)
The free tier gives you 3 city searches per day. Aakaash Premium lifts
that limit so you can check forecasts for your full upazila, every
division, every district — as often as you like. No ads, no daily cap,
no "upgrade" banners.

PRICING
BDT 2.00 / day (auto-renewable). Cancel anytime by replying STOP or
using the Unsubscribe button in the app.
```

## 4. Complete the BDApps portal configuration

AppsPro forwards operator traffic to the BDApps operator network. Paste
these URLs into the **BDApps Developer Portal** under your app's
*API Configuration*:

| Setting | Value |
|---|---|
| **SMS URL** | `https://api.appspro.dev/bdapps/sms` |
| **USSD URL** | `https://api.appspro.dev/bdapps/ussd` |
| **Subscription Notification URL** | `https://api.appspro.dev/bdapps/notify` |
| **Whitelisted IPs** | `217.15.160.79` |

The whitelist is mandatory — AppsPro is the only IP set the BDApps
operator network will accept callbacks from.

## 5. Create the subscription product

In the AppsPro dashboard:

1. Go to **Products → Add subscription**.
2. Fill in:
   - **Product name**: `Aakaash Premium`
   - **Description**: `Unlimited Bangladesh weather forecasts + SMS alerts.`
   - **Charging type**: `Recurring`
   - **Billing interval**: `Daily`
   - **Price**: `7.00 BDT`
   - **Currency**: `BDT`
3. Save and copy the **Product ID** — AppsPro uses it for analytics.

## 6. Configure the WebSDK (optional)

If you also want to surface the *Subscribe* flow as an inline widget
instead of redirecting to the hosted checkout:

```html
<script src="https://appspro.dev/sdk/v1/appspro.js"></script>
<div id="subscribe-box"></div>
<script>
  const sdk = AppsPro('pk_8c8cb9cce5a040581bb32a78', {
    baseUrl: 'https://api.appspro.dev',
  });
  const subscribe = sdk.elements.create('subscribe', {
    buttonText: 'Subscribe Now',
    buttonColor: '#5865F2',
    theme: 'dark',
  });
  subscribe.mount('#subscribe-box');
  subscribe.on('success', (r) => console.log('Subscribed:', r.subscriberId));
</script>
```

Aakaash's default flow uses the redirect-based checkout instead
(`https://appspro.dev/s/<slug>`), so the WebSDK is optional.

## 7. Configure the webhook (optional)

If you want real-time `subscriber.created` / `subscriber.verified` /
`subscriber.cancelled` / `sms.received` / `ussd.received` events POSTed
to your own backend:

1. Provide the webhook URL in the AppsPro dashboard (e.g.
   `https://your-domain.com/webhooks/appspro`).
2. The reference PHP listener in
   `All Backend code/subscription_listener.php` shows the JSON shape
   AppsPro sends. You can re-host it on any HTTPS endpoint to add your
   own business logic (push notifications, CRM sync, billing
   reconciliation).

If you don't need real-time events, skip this step — AppsPro logs every
event in its dashboard and exposes them via
`GET /api/v1/sdk/subscribers`.

## 8. Test the OTP flow end-to-end

> **Common first-time failure**: `HTTP 400` with body
> `{"detail":"App is missing BDApps credentials. Configure them on the Subscription tab."}`
> The SDK secret key is valid (you got past auth), but no
> subscription product is provisioned under it yet. Finish step 5
> (create the product), then re-run step 8.

1. Use a **sandbox number** — AppsPro can register operator test
   numbers that simulate real charging without billing the user.
2. Install the release APK on a device with one of those test SIMs.
3. Open Aakaash, tap **Subscribe**, enter the test number, and request
   an OTP.
4. You should receive an SMS from the operator. Enter the code in the
   app.
5. Verify on the AppsPro dashboard that the subscription shows
   `REGISTERED`.
6. Send `STOP` from the device, confirm the status flips to
   `UNREGISTERED` in the dashboard.

## 9. Submit for review

1. In the AppsPro dashboard, click **Submit for operator review**.
2. Typical review time: 2–5 business days per operator.
3. Once approved, your app becomes available on <https://bdapps.com>
   for users across all five operators.

## 10. After approval

- Monitor subscription events in the AppsPro dashboard (or via your
  webhook listener).
- Adjust `freeDailyLimit` in `lib/core/app_constants.dart` based on
  conversion data.
- Add **Lottie weather animations** to `assets/animations/` to make the
  UI feel even more premium for paying users.

## 11. (Optional) Switch back to the legacy PHP-bdapps backend

If you ever need to run your own backend (e.g. for on-prem BDApps
deployments), edit `buildDefaultBdappsService()` in
`lib/services/bdapps_service.dart`:

```dart
BdappsService buildDefaultBdappsService() {
  return BdappsService(
    backend: 'bdapps',
    baseUrl: 'https://your-domain.com',
    sendOtpPath: '/send_otp.php',
    verifyOtpPath: '/verify_otp.php',
    checkStatusPath: '/check_subscription.php',
    unsubscribePath: '/unsubscribe.php',
  );
}
```

The PHP files in `All Backend code/` speak the BDApps-direct protocol
(`applicationId` + `password` + `subscriberId`) and tunnel through the
AppsPro proxy at `https://api.appspro.dev/bdapps/sms`. Drop the BDApps
portal `applicationId` and `password` into each file alongside the
existing `APP_135889` placeholder.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `401 Unauthorized` from AppsPro | Missing or wrong `APPSPRO_SECRET_KEY` | Rebuild with `flutter build apk --dart-define=APPSPRO_SECRET_KEY=...` |
| OTP never arrives | BDApps portal URLs not set, or IP not whitelisted | Re-check the SMS / USSD / Notify URLs and the `217.15.160.79` whitelist |
| `statusCode: E1351` | Number not in your approved list | Add it under *Sandbox numbers* in the BDApps portal |
| `subscriptionStatus: UNREGISTERED` after verify | Wrong reference number | Confirm `verify_otp.php` returns the same `referenceNo` |
| Subscription not flipping in app | Free quota not reset | `SubscriptionProvider.verifyOtp()` resets `freeSearchesUsedToday` |

Good luck — and may the monsoon be gentle on your users. 🌧️
