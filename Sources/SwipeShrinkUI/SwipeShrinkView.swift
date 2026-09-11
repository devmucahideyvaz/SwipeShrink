import CoreGraphics
import Foundation
import SwipeShrink

#if canImport(SwiftUI)
import SwiftUI

/// What the content needs to know about the transition it is being drawn in.
public struct SwipeShrinkProxy: Equatable, Sendable {
    /// The resting state the view is in, or is animating towards.
    public let state: SwipeShrinkState
    /// `0` while fully expanded, `1` while fully collapsed, interpolated during
    /// a drag. Useful for cross-fading controls as the view shrinks.
    public let progress: CGFloat

    public var isCollapsed: Bool { state == .collapsed }
    public var isExpanded: Bool { state == .expanded }
}

/// Approximate seconds of deceleration represented by
/// `DragGesture.Value.predictedEndTranslation`, used to recover a velocity on
/// systems that predate `DragGesture.Value.velocity`.
private let predictedEndInterval: CGFloat = 0.25

/// The SwiftUI counterpart of `SwipeShrink`: swipe the content down to shrink
/// it into a mini player docked in the bottom-trailing corner, tap to restore.
///
/// The view fills the space it is offered and positions its content inside it,
/// so give it the area the content should be able to travel across — typically
/// as the top layer of a `ZStack` covering the screen:
///
/// ```swift
/// struct ContentView: View {
///     @State private var playerState: SwipeShrinkState = .expanded
///
///     var body: some View {
///         ZStack {
///             FeedList()
///
///             SwipeShrinkView(state: $playerState) { proxy in
///                 VideoPlayer(player: player)
///                     .overlay(proxy.isCollapsed ? CloseButton() : nil,
///                              alignment: .topTrailing)
///             }
///         }
///     }
/// }
/// ```
///
/// - Note: The transition maths is shared with the UIKit `SwipeShrink` — both
///   are driven by `SwipeShrinkGeometry`, so the two behave identically.
@available(iOS 14.0, macOS 11.0, *)
@MainActor
public struct SwipeShrinkView<Content: View>: View {

    @Binding private var state: SwipeShrinkState
    private let configuration: SwipeShrinkConfiguration
    private let expandedFrame: SwipeShrinkExpandedFrame
    private let content: (SwipeShrinkProxy) -> Content

    /// Non-`nil` only while a drag is in flight; otherwise `state` decides.
    @State private var dragProgress: CGFloat?

    /// - Parameters:
    ///   - state: The resting state, owned by the caller so the transition can
    ///     also be driven programmatically.
    ///   - configuration: Geometry and animation values, shared with UIKit.
    ///   - expandedFrame: How the expanded resting frame is derived from the
    ///     space this view is given.
    ///   - content: The content to shrink. It is handed a `SwipeShrinkProxy` so
    ///     it can adapt as the transition runs.
    public init(state: Binding<SwipeShrinkState>,
                configuration: SwipeShrinkConfiguration = .default,
                expandedFrame: SwipeShrinkExpandedFrame = .video,
                @ViewBuilder content: @escaping (SwipeShrinkProxy) -> Content) {
        self._state = state
        self.configuration = configuration
        self.expandedFrame = expandedFrame
        self.content = content
    }

    public var body: some View {
        GeometryReader { proxy in
            // Recomputed on every layout, so a rotation or a split-view resize
            // needs no explicit invalidation the way UIKit does.
            let geometry = SwipeShrinkGeometry(
                expandedFrame: expandedFrame.rect(in: proxy.size),
                parentBounds: CGRect(origin: .zero, size: proxy.size),
                configuration: configuration
            )
            let progress = resolvedProgress
            let size = geometry.size(at: progress)

            content(SwipeShrinkProxy(state: state, progress: progress))
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .position(x: geometry.centerX(at: progress),
                          y: geometry.centerY(at: progress))
                // Simultaneous so the content's own gestures keep working.
                .simultaneousGesture(dragGesture(for: geometry))
                // While expanded, taps belong to the content (a player's
                // transport controls, say); while collapsed they restore.
                .gesture(tapGesture, including: state == .collapsed ? .gesture : .subviews)
        }
    }

    // MARK: - Progress

    private var resolvedProgress: CGFloat {
        if let dragProgress = dragProgress {
            return dragProgress
        }
        return state == .collapsed ? 1 : 0
    }

    /// `DragGesture` reports translation cumulatively from where the drag
    /// started, so the centre is measured from the current resting position
    /// rather than accumulated frame by frame.
    private func centerY(forTranslation translation: CGFloat,
                         geometry: SwipeShrinkGeometry) -> CGFloat {
        let base = geometry.centerY(at: state == .collapsed ? 1 : 0)
        return min(max(base + translation, geometry.expandedCenter.y),
                   geometry.collapsedCenter.y)
    }

    // MARK: - Gestures

    private func dragGesture(for geometry: SwipeShrinkGeometry) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard geometry.isValid else { return }
                let targetCenterY = centerY(forTranslation: value.translation.height,
                                            geometry: geometry)
                dragProgress = geometry.progress(forCenterY: targetCenterY)
            }
            .onEnded { value in
                guard geometry.isValid else {
                    dragProgress = nil
                    return
                }
                let targetCenterY = centerY(forTranslation: value.translation.height,
                                            geometry: geometry)
                let resting = geometry.restingState(forCenterY: targetCenterY,
                                                    velocityY: verticalVelocity(of: value),
                                                    configuration: configuration)
                withAnimation(.easeOut(duration: configuration.animationDuration)) {
                    dragProgress = nil
                    state = resting
                }
            }
    }

    private var tapGesture: some Gesture {
        TapGesture().onEnded {
            withAnimation(.easeOut(duration: configuration.animationDuration)) {
                state = .expanded
            }
        }
    }

    private func verticalVelocity(of value: DragGesture.Value) -> CGFloat {
        if #available(iOS 17.0, macOS 14.0, *) {
            return value.velocity.height
        }
        // Older systems only expose where the drag is predicted to land, so
        // back out an approximate velocity from that projection.
        return (value.predictedEndTranslation.height - value.translation.height) / predictedEndInterval
    }
}

#if DEBUG
@available(iOS 14.0, macOS 11.0, *)
struct SwipeShrinkView_Previews: PreviewProvider {
    private struct Demo: View {
        @State private var state: SwipeShrinkState = .expanded

        var body: some View {
            ZStack {
                Color.gray.opacity(0.15).ignoresSafeArea()

                SwipeShrinkView(state: $state) { proxy in
                    ZStack {
                        Color.red
                        Text(proxy.isCollapsed ? "Mini" : "Full screen")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                }
            }
        }
    }

    static var previews: some View {
        Demo()
    }
}
#endif

#endif
