# KneeHope native iOS app

The application target contains SwiftUI sources under Native and its asset catalog. It does not compile the old UIKit/WebKit browser container. Minimum OS and build SDK: iOS 27. Desktop display name: KneeHope. Bundle identity is unchanged so a signed update can replace the previous installation.

## Apple references used

- https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views
- https://developer.apple.com/design/human-interface-guidelines/app-icons
- https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes
- https://developer.apple.com/xcode/system-requirements/

Use system TabView, NavigationStack, toolbars, sheets, glass button styles, PhotosPicker, dynamic text and SF Symbols. The system supplies navigation material and edge-swipe transitions; content panels use material instead of glass stacked throughout the page. System accessibility settings affect the native controls. Icon artwork is opaque and square; the OS applies the rounded mask.

## Cloud integration

Native URLSession calls the existing authenticated business endpoints, not browser SDK or database administrator APIs. A device UUID is kept in Keychain. Connect the existing private XW1 sync code in Settings to access the web account. No API secrets or health data are included in this repository. Writes are queued in a protected, atomic local file before requests. Sessions retain stable UUIDs for idempotent retries. Revision conflicts must be shown rather than overwritten automatically. Wallpaper and appearance use the same cloud account as records.

## Verification

GitHub Actions uses the standard xcode-27 runner to compile an unsigned device IPA, run unit and UI tests on the iOS 27 simulator and capture screenshots. The package must be signed by Sideloadly before installation. Simulator success cannot establish actual device frame-rate, battery behavior, photo permissions or Apple signing success; these need an on-device acceptance pass. Do not advertise a zero-bug guarantee.

Artwork edit prompt: preserve both bears, bandages and pawprint trail; remove inset tile and outer margin; opaque full-bleed cream square; keep ears/feet visible; no text or pre-rounded corners. Built-in image generation was used for the asset edit, followed by deterministic SDK asset resizing.
