# SwipeShrink

Swipe a view down to shrink it into a mini player docked in the bottom-trailing
corner — like the YouTube video player. Tap the mini player to restore it.

![](swipe_shrink.gif)

## Requirements

- iOS 11.0+ / tvOS 11.0+
- Swift 5.3+
- No third-party dependencies

## Installation

### Swift Package Manager

Add the package in Xcode via **File → Add Packages…**, or declare it in your
`Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/devmucahideyvaz/SwipeShrink.git", from: "1.0.0")
]
```

### CocoaPods

```ruby
pod 'SwipeShrink'
```

### Manually

Copy `Sources/SwipeShrink/SwipeShrink.swift` and
`Sources/SwipeShrink/SwipeShrinkGeometry.swift` into your project.

## Usage

```swift
import AVFoundation
import AVKit
import SwipeShrink
import UIKit

final class ViewController: UIViewController {
    @IBOutlet weak var shrinkedView: UIView!

    private let shrink = SwipeShrink()
    private let player = AVPlayer()
    private let playerViewController = AVPlayerViewController()

    private var hasPreparedShrink = false

    override func viewDidLoad() {
        super.viewDidLoad()

        playerViewController.player = player
        addChild(playerViewController)
        playerViewController.view.frame = shrinkedView.bounds
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shrinkedView.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)

        if let url = Bundle.main.url(forResource: "bayw-HD", withExtension: "mp4") {
            player.replaceCurrentItem(with: AVPlayerItem(url: url))
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasPreparedShrink else { return }
        hasPreparedShrink = true
        shrink.prepare(view: shrinkedView, in: view)
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            // Pass an explicit frame when the managed view is positioned by a
            // fixed frame; omit it when its autoresizing mask keeps it correct.
            self.shrink.updateLayout(expandedFrame: CGRect(x: 0,
                                                           y: self.view.safeAreaInsets.top,
                                                           width: size.width,
                                                           height: size.width * 9 / 16))
        })
    }
}
```

`prepare(view:in:)` must be called once the managed view has its final expanded
frame — `viewDidAppear` is a good place. Calling it again is safe: it detaches
the gestures it installed previously rather than stacking a second set.

## Configuration

```swift
var configuration = SwipeShrinkConfiguration()
configuration.collapsedWidthRatio = 0.45   // mini player width, as a fraction of the parent
configuration.horizontalInset = 12         // margin from the trailing edge
configuration.bottomInset = 8              // margin from the bottom edge
configuration.animationDuration = 0.3
configuration.flickVelocityThreshold = 600 // pt/s above which a flick wins over position

let shrink = SwipeShrink(configuration: configuration)
```

Assigning `shrink.configuration` after `prepare` re-derives the layout
immediately.

## API

| Member | Description |
| --- | --- |
| `prepare(view:in:)` | Attaches the gestures and computes the layout. Idempotent. |
| `updateLayout(expandedFrame:)` | Recomputes the layout after the parent resizes. Pass a frame to override, or `nil` to derive one. |
| `setState(_:animated:completion:)` | Moves to `.expanded` or `.collapsed`. |
| `toggle(animated:)` | Switches between the two states. |
| `state` | The current resting state (read-only). |
| `onStateChange` | Called when the resting state changes. |
| `geometry` | The `SwipeShrinkGeometry` currently driving the transition. |
| `invalidate()` | Detaches the gestures and forgets the layout. |

## Behaviour notes

- **Aspect ratio** is derived from the managed view's expanded frame, so the
  view never jumps when the pan begins, and it is preserved for the whole
  transition. Non-16:9 views are supported.
- **The collapsed resting position** is anchored to the parent's
  bottom-trailing corner using the collapsed size, so it does not depend on how
  tall the expanded view is.
- **Flicks** settle in the direction of travel; slower drags settle to whichever
  resting position is nearer.
- **Cancelled gestures** (an incoming call, a system alert) settle the view
  rather than leaving it mid-drag.
- **While expanded, taps pass through** to your content, so an
  `AVPlayerViewController`'s transport controls keep working. The tap gesture
  only activates while collapsed.

## Layout requirements

SwipeShrink positions the managed view by writing to its `bounds` and `center`.
The view must therefore be laid out by its autoresizing mask, **not** by Auto
Layout constraints that pin its position or size — a layout pass would otherwise
undo the transition. Subviews of the managed view may use Auto Layout freely.

## Example

Open `SwipeShrinkExample/SwipeShrinkExample.xcodeproj` and run.

## Tests

```sh
swift test
```

The transition maths lives in `SwipeShrinkGeometry`, which has no UIKit
dependency and is covered by unit tests.

## License

MIT — see [LICENSE](LICENSE).
