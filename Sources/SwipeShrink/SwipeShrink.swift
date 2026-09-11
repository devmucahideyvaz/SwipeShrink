import Foundation

#if canImport(UIKit) && !os(watchOS)
import UIKit

/// Drives a "swipe down to shrink" transition on a view, like the YouTube
/// video player.
///
/// Usage:
/// ```swift
/// private let shrink = SwipeShrink()
///
/// override func viewDidAppear(_ animated: Bool) {
///     super.viewDidAppear(animated)
///     shrink.prepare(view: playerContainer, in: view)
/// }
///
/// override func viewWillTransition(to size: CGSize,
///                                  with coordinator: UIViewControllerTransitionCoordinator) {
///     super.viewWillTransition(to: size, with: coordinator)
///     coordinator.animate(alongsideTransition: { _ in self.shrink.updateLayout() })
/// }
/// ```
///
/// - Important: `SwipeShrink` positions the managed view by writing to its
///   `bounds` and `center`. The view must therefore be laid out by its
///   autoresizing mask, not by Auto Layout constraints that pin its position or
///   size — a layout pass would otherwise undo the transition. Subviews of the
///   managed view may use Auto Layout freely.
public final class SwipeShrink: NSObject {

    // MARK: - Public API

    /// Tunable geometry and animation values. Assigning re-derives the layout.
    public var configuration: SwipeShrinkConfiguration {
        didSet {
            guard configuration != oldValue else { return }
            updateLayout()
        }
    }

    /// The resting state the view is in, or is currently animating towards.
    public private(set) var state: SwipeShrinkState = .expanded

    /// Called when `state` changes, once the transition into it has finished.
    public var onStateChange: ((SwipeShrinkState) -> Void)?

    /// The geometry currently driving the transition, or `nil` before `prepare`.
    public private(set) var geometry: SwipeShrinkGeometry?

    public init(configuration: SwipeShrinkConfiguration = .default) {
        self.configuration = configuration
        super.init()
    }

    // MARK: - Private state

    private weak var managedView: UIView?
    private weak var parentView: UIView?
    private var panGesture: UIPanGestureRecognizer?
    private var tapGesture: UITapGestureRecognizer?

    /// The expanded frame, in the parent's coordinate space. Kept explicitly
    /// because `managedView.frame` is not the expanded frame while collapsed.
    private var expandedFrame: CGRect = .zero
    /// The parent bounds `expandedFrame` was measured against, used to rescale
    /// it when the parent resizes.
    private var lastParentBounds: CGRect = .zero
    private var isAnimating = false

    // MARK: - Setup

    /// Attaches the pan and tap gestures to `view` and computes the layout.
    ///
    /// Safe to call more than once (for example from `viewDidAppear`): a second
    /// call detaches the gestures installed by the previous one instead of
    /// stacking a duplicate set on the view.
    public func prepare(view: UIView, in parentView: UIView) {
        assert(view.superview === parentView,
               "SwipeShrink expects `view` to be a direct subview of `parentView`; "
                   + "frames are interpreted in `parentView`'s coordinate space.")
        detachGestures()

        managedView = view
        self.parentView = parentView

        expandedFrame = view.frame
        lastParentBounds = parentView.bounds
        state = .expanded

        attachGestures(to: view)
        rebuildGeometry()
    }

    /// Removes the gestures installed by `prepare` and forgets the layout.
    public func invalidate() {
        detachGestures()
        managedView = nil
        parentView = nil
        geometry = nil
        expandedFrame = .zero
        lastParentBounds = .zero
    }

    /// Recomputes the layout, then snaps the view to its current resting state
    /// without animating. Call this after the parent's size changes (rotation,
    /// split view, and so on).
    ///
    /// - Parameter expandedFrame: The new expanded frame. When `nil`, the
    ///   previous expanded frame is scaled proportionally into the parent's new
    ///   bounds, preserving the view's aspect ratio.
    public func updateLayout(expandedFrame newExpandedFrame: CGRect? = nil) {
        guard let view = managedView, let parent = parentView else { return }
        let parentBounds = parent.bounds

        if let newExpandedFrame = newExpandedFrame {
            expandedFrame = newExpandedFrame
        } else if state == .expanded {
            // The layout system has already sized the view for us.
            expandedFrame = view.frame
        } else {
            expandedFrame = rescaledExpandedFrame(into: parentBounds)
        }

        lastParentBounds = parentBounds
        rebuildGeometry()
        applyState(state, animated: false)
    }

    // MARK: - Transitions

    /// Moves the view to `newState`.
    public func setState(_ newState: SwipeShrinkState,
                         animated: Bool = true,
                         completion: (() -> Void)? = nil) {
        let didChange = newState != state
        state = newState
        applyState(newState, animated: animated) { [weak self] in
            if didChange {
                self?.onStateChange?(newState)
            }
            completion?()
        }
    }

    /// Toggles between the expanded and collapsed states.
    public func toggle(animated: Bool = true) {
        setState(state == .expanded ? .collapsed : .expanded, animated: animated)
    }

    // MARK: - Gestures

    private func attachGestures(to view: UIView) {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.delegate = self
        view.addGestureRecognizer(pan)
        panGesture = pan

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tap.numberOfTapsRequired = 1
        tap.delegate = self
        view.addGestureRecognizer(tap)
        tapGesture = tap
    }

    private func detachGestures() {
        if let pan = panGesture {
            pan.view?.removeGestureRecognizer(pan)
        }
        if let tap = tapGesture {
            tap.view?.removeGestureRecognizer(tap)
        }
        panGesture = nil
        tapGesture = nil
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard !isAnimating,
              let view = managedView,
              let parent = parentView,
              let geometry = geometry,
              geometry.isValid else { return }

        switch recognizer.state {
        case .began, .changed:
            let translation = recognizer.translation(in: parent)
            // Clamp instead of forcing the gesture into `.ended`, so the view
            // simply stops at the boundary and the gesture stays live.
            let centerY = min(max(view.center.y + translation.y, geometry.expandedCenter.y),
                              geometry.collapsedCenter.y)
            apply(progress: geometry.progress(forCenterY: centerY), centerY: centerY, to: view)
            recognizer.setTranslation(.zero, in: parent)

        case .ended, .cancelled, .failed:
            let velocityY = recognizer.state == .ended
                ? recognizer.velocity(in: parent).y
                : 0
            let resting = geometry.restingState(forCenterY: view.center.y,
                                                velocityY: velocityY,
                                                configuration: configuration)
            setState(resting, animated: true)

        default:
            break
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard !isAnimating, state == .collapsed else { return }
        setState(.expanded, animated: true)
    }

    // MARK: - Layout application

    private func rebuildGeometry() {
        guard let parent = parentView else {
            geometry = nil
            return
        }
        geometry = SwipeShrinkGeometry(expandedFrame: expandedFrame,
                                       parentBounds: parent.bounds,
                                       configuration: configuration)
    }

    private func rescaledExpandedFrame(into parentBounds: CGRect) -> CGRect {
        guard lastParentBounds.width > 0, lastParentBounds.height > 0,
              expandedFrame.width > 0 else { return expandedFrame }

        let aspectRatio = expandedFrame.height / expandedFrame.width
        let widthFraction = expandedFrame.width / lastParentBounds.width
        let width = parentBounds.width * widthFraction
        // Preserve the aspect ratio rather than stretching height with the
        // parent — a video must not distort on rotation.
        let height = width * aspectRatio
        let x = parentBounds.width * (expandedFrame.minX / lastParentBounds.width)
        let y = parentBounds.height * (expandedFrame.minY / lastParentBounds.height)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func applyState(_ newState: SwipeShrinkState,
                            animated: Bool,
                            completion: (() -> Void)? = nil) {
        guard let view = managedView, let geometry = geometry else {
            completion?()
            return
        }

        let targetSize = geometry.size(for: newState)
        let targetCenter = geometry.center(for: newState)

        let applyTargets = {
            view.bounds.size = targetSize
            view.center = targetCenter
        }

        guard animated, configuration.animationDuration > 0 else {
            applyTargets()
            completion?()
            return
        }

        isAnimating = true
        UIView.animate(withDuration: configuration.animationDuration,
                       delay: 0,
                       options: [.beginFromCurrentState, .curveEaseOut],
                       animations: applyTargets,
                       completion: { [weak self] _ in
                           self?.isAnimating = false
                           completion?()
                       })
    }

    private func apply(progress: CGFloat, centerY: CGFloat, to view: UIView) {
        guard let geometry = geometry else { return }
        // Setting `bounds.size` (rather than `frame.size`) resizes the view
        // about its centre, so size and position stay independent.
        view.bounds.size = geometry.size(at: progress)
        view.center = CGPoint(x: geometry.centerX(at: progress), y: centerY)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension SwipeShrink: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === tapGesture {
            // While expanded, let taps through to the content (for example an
            // AVPlayerViewController's transport controls).
            return state == .collapsed
        }
        return !isAnimating
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // The pan drives the whole transition and must not be blocked by the
        // content's own recognizers; the tap deliberately does not share.
        return gestureRecognizer === panGesture
    }
}
#endif
