# KneeHope 2.1 — restored original interface
The iOS target compiles XiWang (UIKit/WKWebView), not Native SwiftUI screens. The original production web layout, animations, glass navigation, AI, training, care and synchronized appearance are retained. No business webpage or backend is replaced by this release.
Keep desktop name KneeHope and full-bleed opaque icon. iOS applies the icon mask. iOS 27 SDK supplies Liquid Glass to native system share sheets and the network retry control. No second navigation bar is added over the original layout.
Default persistent website storage preserves the old container identity if the signing bundle identity matches. If signing creates a different identity, connect the original private sync code inside the webpage.
No reload on foreground: dispatch a focus event for sync. Web gestures are enabled. Weak script handler avoids an ownership cycle. Download security is restricted to the original HTTPS origin and 10 MB JSON/HTML exports.
CI builds an unsigned IPA, checks route policy and download bridge behavior, tests original webpage navigation without submitting health records, and captures the iOS desktop icon.
Sign with Sideloadly after the user wakes. Actual device smoothness, permissions and identity continuity require on-device acceptance; simulator tests do not establish zero bugs or device FPS.
