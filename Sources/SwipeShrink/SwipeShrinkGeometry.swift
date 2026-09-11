import Foundation
import CoreGraphics

/// Tunable values that describe where the collapsed ("mini") view comes to rest
/// and how the transition animates.
public struct SwipeShrinkConfiguration: Equatable, Sendable {
    /// Width of the collapsed view as a fraction of the parent's width, before
    /// `horizontalInset` is subtracted. Clamped to `0.1 ... 1.0`.
    public var collapsedWidthRatio: CGFloat

    /// Distance kept between the collapsed view's trailing edge and the parent's
    /// trailing edge.
    public var horizontalInset: CGFloat

    /// Distance kept between the collapsed view's bottom edge and the parent's
    /// bottom edge.
    public var bottomInset: CGFloat

    /// Duration of the settle animation once the gesture ends.
    public var animationDuration: TimeInterval

    /// Vertical gesture speed (points per second) above which the pan is treated
    /// as a flick and settles in the direction of travel regardless of position.
    public var flickVelocityThreshold: CGFloat

    public init(collapsedWidthRatio: CGFloat = 0.5,
                horizontalInset: CGFloat = 10,
                bottomInset: CGFloat = 2,
                animationDuration: TimeInterval = 0.4,
                flickVelocityThreshold: CGFloat = 600) {
        self.collapsedWidthRatio = collapsedWidthRatio
        self.horizontalInset = horizontalInset
        self.bottomInset = bottomInset
        self.animationDuration = animationDuration
        self.flickVelocityThreshold = flickVelocityThreshold
    }

    /// The stock configuration. Immutable and `Sendable`, so it is safe to
    /// read from any isolation domain.
    public static let `default` = SwipeShrinkConfiguration()
}

/// The two resting positions of a swipe-shrink view.
public enum SwipeShrinkState: Equatable, CaseIterable, Sendable {
    case expanded
    case collapsed
}

/// Pure geometry for the swipe-shrink transition.
///
/// This type contains no UIKit dependency so the layout maths can be unit
/// tested on any platform.
public struct SwipeShrinkGeometry: Equatable, Sendable {
    /// Centre of the view in its expanded resting position.
    public let expandedCenter: CGPoint
    /// Size of the view in its expanded resting position.
    public let expandedSize: CGSize
    /// Centre of the view in its collapsed resting position.
    public let collapsedCenter: CGPoint
    /// Size of the view in its collapsed resting position.
    public let collapsedSize: CGSize
    /// height / width of the expanded view, preserved throughout the transition.
    public let aspectRatio: CGFloat

    /// Builds the geometry for `expandedFrame` shrinking inside `parentBounds`.
    ///
    /// - Note: `aspectRatio` is derived from `expandedFrame` rather than assumed,
    ///   so the view never jumps on the first pan. If `expandedFrame` is
    ///   degenerate, 16:9 is used as a fallback.
    public init(expandedFrame: CGRect,
                parentBounds: CGRect,
                configuration: SwipeShrinkConfiguration = .default) {
        let ratio: CGFloat
        if expandedFrame.width > 0 && expandedFrame.height > 0 {
            ratio = expandedFrame.height / expandedFrame.width
        } else {
            ratio = 9.0 / 16.0
        }
        aspectRatio = ratio

        expandedSize = expandedFrame.size
        expandedCenter = CGPoint(x: expandedFrame.midX, y: expandedFrame.midY)

        let widthRatio = min(max(configuration.collapsedWidthRatio, 0.1), 1.0)
        // Never let the collapsed view end up wider than the expanded one, nor
        // collapse to a non-positive width on a very narrow parent.
        let rawWidth = parentBounds.width * widthRatio - configuration.horizontalInset
        let collapsedWidth = min(max(rawWidth, 1), max(expandedFrame.width, 1))
        let collapsedHeight = collapsedWidth * ratio
        collapsedSize = CGSize(width: collapsedWidth, height: collapsedHeight)

        // Anchor the collapsed view to the parent's bottom-trailing corner using
        // its *own* size, so the resting position no longer depends on how tall
        // the expanded view happened to be.
        collapsedCenter = CGPoint(
            x: parentBounds.maxX - configuration.horizontalInset - collapsedWidth / 2,
            y: parentBounds.maxY - configuration.bottomInset - collapsedHeight / 2
        )
    }

    /// Vertical distance the centre travels between the two resting positions.
    public var verticalTravel: CGFloat {
        collapsedCenter.y - expandedCenter.y
    }

    /// `false` when the two resting positions coincide (or invert), in which
    /// case there is nothing meaningful to interpolate.
    public var isValid: Bool {
        verticalTravel > 0 && expandedSize.width > 0 && collapsedSize.width > 0
    }

    /// Maps a centre-y value onto `0` (expanded) ... `1` (collapsed).
    public func progress(forCenterY centerY: CGFloat) -> CGFloat {
        guard isValid else { return 0 }
        return clampedProgress((centerY - expandedCenter.y) / verticalTravel)
    }

    /// Centre-y for a given progress.
    public func centerY(at progress: CGFloat) -> CGFloat {
        expandedCenter.y + verticalTravel * clampedProgress(progress)
    }

    /// Centre-x for a given progress.
    public func centerX(at progress: CGFloat) -> CGFloat {
        let t = clampedProgress(progress)
        return expandedCenter.x + (collapsedCenter.x - expandedCenter.x) * t
    }

    /// Size for a given progress. Width is interpolated linearly and height
    /// follows `aspectRatio`, so progress `0` reproduces `expandedSize` exactly.
    public func size(at progress: CGFloat) -> CGSize {
        let t = clampedProgress(progress)
        let width = expandedSize.width + (collapsedSize.width - expandedSize.width) * t
        return CGSize(width: width, height: width * aspectRatio)
    }

    /// Convenience accessor for a resting state's centre.
    public func center(for state: SwipeShrinkState) -> CGPoint {
        switch state {
        case .expanded: return expandedCenter
        case .collapsed: return collapsedCenter
        }
    }

    /// Convenience accessor for a resting state's size.
    public func size(for state: SwipeShrinkState) -> CGSize {
        switch state {
        case .expanded: return expandedSize
        case .collapsed: return collapsedSize
        }
    }

    /// Where the view should settle when the gesture ends.
    ///
    /// A flick (vertical speed above `flickVelocityThreshold`) wins over
    /// position; otherwise the nearer resting position is chosen.
    public func restingState(forCenterY centerY: CGFloat,
                             velocityY: CGFloat,
                             configuration: SwipeShrinkConfiguration = .default) -> SwipeShrinkState {
        if abs(velocityY) >= configuration.flickVelocityThreshold {
            return velocityY > 0 ? .collapsed : .expanded
        }
        return progress(forCenterY: centerY) >= 0.5 ? .collapsed : .expanded
    }

    private func clampedProgress(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}
