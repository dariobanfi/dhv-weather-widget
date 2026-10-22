# DHV Wetter for iOS

A native iOS 26 app and WidgetKit widgets for the [DHV-Wetter](https://www.dhv.de/wetter/dhv-wetter/) paragliding forecast (Deutschland, Nordalpen, Südalpen), designed for Liquid Glass.

## Widgets

| Widget | Sizes | Shows |
| --- | --- | --- |
| **DHV Wetter** | Medium, Large | All three regions × the next days. Medium: headline per day. Large: headline, DHV's key phrase and wind. |
| **DHV Region** | Small, Lock Screen (rectangular, inline) | One region (long-press → Edit Widget to choose). |

- Each day is a tile. The icon shows the sky as DHV describes it (sun, cloud, showers, rain, snow, Föhn), read from DHV's bold key phrase.
- When DHV marks a day as Thermikwetter (👍), Störungswetter (👎) or with a Warnhinweis (⚠︎), the tile is tinted green, red or yellow and shows the badge. DHV mostly sets these markers in thermal season; outside it the tiles stay blue-grey.
- Columns are matched by date and labelled from the real date (Today / Tomorrow / weekday), so they roll over at midnight and never show yesterday as "Today".
- The Liquid Glass comes from iOS, as Apple's widget guidance intends: with a **Clear** or **Tinted** Home Screen (long-press the Home Screen → Edit → Customize) iOS renders the widget in accented mode, removes its sky background and draws real glass or your tint behind the content. The widget doesn't fake glass itself (a custom glass effect doesn't render inside widgets). Everything stays readable there because the sky and DHV's markers are symbols, not only colours.
- The widget refreshes shortly after DHV's announced next update (morning ~7–8 h, evening ~18–19 h) and at least every 3 hours, as far as iOS's widget budget allows. Opening the app refreshes everything immediately.
- Tapping a widget opens the app on that region.

## Get the IPA

Every push to `ios/` builds an **unsigned** IPA on a macOS runner:

1. Open the repo's **Actions** tab → workflow **iOS** → the latest green run.
2. Download the artifact **DHVWeather-unsigned-ipa** (a zip containing `DHVWeather-unsigned.ipa`).

Pushing a tag like `ios-v1.0.0` also attaches the IPA to a GitHub Release.

## Sign and install

The IPA is unsigned on purpose: sign it with your own certificate and provisioning profile in the tool you normally use (ESign, Feather, Scarlet, Sideloadly, zsign, …), then install it.

Things to know:

- **Keep the widget inside the app.** The widget is an app extension at `Payload/DHVWeather.app/PlugIns/DHVWidget.appex` and must be signed too. All the common tools do this, but if you change the app's bundle ID, the extension's ID must stay `<app bundle ID>.widget` or iOS won't show the widget.
- **App Group is optional.** The app and widget can share their cache through `group.com.dariobanfi.dhvweather`, but shared-certificate profiles usually can't grant App Groups. That's fine: the widget then downloads the forecast itself and works the same.
- **Shared certificates get revoked.** When Apple revokes the certificate, the app and widget stop opening until you re-sign and reinstall with a working one. A free Apple ID via Xcode or Sideloadly also works (re-sign every 7 days).
- After installing, open the app once, then add the widget: long-press the Home Screen → **Edit** → **Add Widget** → **DHV Wetter**.

## Build locally

```sh
brew install xcodegen
cd ios
xcodegen generate
open DHVWeather.xcodeproj   # pick your Team under Signing & Capabilities for both targets
```

Requires Xcode 26 (iOS 26 SDK).

## Layout

```
ios/
├── project.yml        XcodeGen project (app + widget extension)
├── DHVKit/            Swift package: DHV page parser, model, cache, tests
│   └── Sources/dhv-check   `swift run dhv-check` prints the live forecast as parsed (`--html` dumps the raw markup)
├── App/               SwiftUI host app (+ debug-only widget gallery for screenshots)
├── UITests/           CI-only SpringBoard test: real Home Screen shots in Default, Dark, Clear, Tinted
├── Widget/            WidgetKit extension
└── Shared/            Widget views, colours and symbols used by both
```

`swift test` in `ios/DHVKit` runs the parser tests on any Mac. CI also runs `dhv-check` against the live page, so a DHV layout change shows up in the build log.
