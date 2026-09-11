import Foundation
import CoreGraphics

/// Describes the expanded resting frame in terms of the parent's size.
///
/// UIKit callers hand `SwipeShrink` a concrete `CGRect` because they already
/// have a laid-out view. SwiftUI has no frame to read until layout runs, so the
/// expanded frame is described declaratively instead and resolved against
/// whatever size the container is given.
public struct SwipeShrinkExpandedFrame: Equatable, Sendable {
    /// Width of the expanded view as a fraction of the parent's width.
    /// Clamped to `0.1 ... 1.0`.
    public var widthRatio: CGFloat

    /// height / width of the expanded view. Clamped to a positive value.
    public var aspectRatio: CGFloat

    /// Distance between the parent's top edge and the expanded view's top edge.
    public var topInset: CGFloat

    public init(widthRatio: CGFloat = 1,
                aspectRatio: CGFloat = 9.0 / 16.0,
                topInset: CGFloat = 0) {
        self.widthRatio = widthRatio
        self.aspectRatio = aspectRatio
        self.topInset = topInset
    }

    /// Full-width 16:9, flush with the parent's top edge.
    public static let video = SwipeShrinkExpandedFrame()

    /// Resolves the expanded frame for a parent of `parentSize`.
    public func rect(in parentSize: CGSize) -> CGRect {
        let clampedWidthRatio = min(max(widthRatio, 0.1), 1)
        let width = parentSize.width * clampedWidthRatio
        let height = width * max(aspectRatio, 0.01)
        return CGRect(x: (parentSize.width - width) / 2,
                      y: topInset,
                      width: width,
                      height: height)
    }
}
