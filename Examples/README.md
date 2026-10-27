# UIKit example

Open `UIKitDemo/TMProgressHudDemo.xcodeproj` in Xcode 27+, select `TMProgressHudDemo` and run on iOS 17+ or tvOS 17+. The project uses the local Swift package.

Try all six modes, the Close action and bottom placement. The view controller adds outer spacing to its safe area and updates it when that area changes; physical left/right placement remains unchanged in RTL. On tvOS, the view controller directs focus to the HUD action button and restores the menu after dismissal. The example opts into accessibility modal scope, requests focus on its action when VoiceOver is running, and requests return to the initiating control after dismissal. It uses the typed notification API available from iOS/tvOS 17; an actual VoiceOver session is still unverified. The Objective-C test reference is not linked into the example.
