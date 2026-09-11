import CoreGraphics
import XCTest
@testable import SwipeShrink

final class SwipeShrinkGeometryTests: XCTestCase {

    private let parentBounds = CGRect(x: 0, y: 0, width: 414, height: 896)
    private let expandedFrame = CGRect(x: 0, y: 44, width: 414, height: 233)

    private func makeGeometry(expandedFrame: CGRect? = nil,
                              parentBounds: CGRect? = nil,
                              configuration: SwipeShrinkConfiguration = .default) -> SwipeShrinkGeometry {
        SwipeShrinkGeometry(expandedFrame: expandedFrame ?? self.expandedFrame,
                            parentBounds: parentBounds ?? self.parentBounds,
                            configuration: configuration)
    }

    // MARK: - Aspect ratio

    func testAspectRatioIsDerivedFromExpandedFrame() {
        let geometry = makeGeometry(expandedFrame: CGRect(x: 0, y: 0, width: 300, height: 300))
        XCTAssertEqual(geometry.aspectRatio, 1.0, accuracy: 0.0001)
    }

    func testAspectRatioFallsBackTo16By9ForDegenerateFrame() {
        let geometry = makeGeometry(expandedFrame: CGRect(x: 0, y: 0, width: 0, height: 0))
        XCTAssertEqual(geometry.aspectRatio, 9.0 / 16.0, accuracy: 0.0001)
    }

    /// Regression: the size at progress 0 must equal the expanded size exactly,
    /// otherwise the view visibly jumps as soon as the pan begins.
    func testSizeAtZeroProgressMatchesExpandedSizeForNonVideoAspectRatio() {
        let square = CGRect(x: 0, y: 0, width: 300, height: 300)
        let geometry = makeGeometry(expandedFrame: square)
        let size = geometry.size(at: 0)
        XCTAssertEqual(size.width, square.width, accuracy: 0.0001)
        XCTAssertEqual(size.height, square.height, accuracy: 0.0001)
    }

    func testSizeAtFullProgressMatchesCollapsedSize() {
        let geometry = makeGeometry()
        let size = geometry.size(at: 1)
        XCTAssertEqual(size.width, geometry.collapsedSize.width, accuracy: 0.0001)
        XCTAssertEqual(size.height, geometry.collapsedSize.height, accuracy: 0.0001)
    }

    func testAspectRatioIsPreservedThroughoutTheTransition() {
        let geometry = makeGeometry(expandedFrame: CGRect(x: 0, y: 0, width: 300, height: 200))
        for step in 0...10 {
            let size = geometry.size(at: CGFloat(step) / 10)
            XCTAssertEqual(size.height / size.width, geometry.aspectRatio, accuracy: 0.0001)
        }
    }

    // MARK: - Collapsed resting position

    /// Regression: the collapsed resting position must derive from the collapsed
    /// size, not from the expanded view's height.
    func testCollapsedViewRestsAgainstParentBottomRegardlessOfExpandedHeight() {
        let short = makeGeometry(expandedFrame: CGRect(x: 0, y: 0, width: 414, height: 100))
        let tall = makeGeometry(expandedFrame: CGRect(x: 0, y: 0, width: 414, height: 400))

        for geometry in [short, tall] {
            let bottomEdge = geometry.collapsedCenter.y + geometry.collapsedSize.height / 2
            XCTAssertEqual(bottomEdge,
                           parentBounds.maxY - SwipeShrinkConfiguration.default.bottomInset,
                           accuracy: 0.0001)
        }
    }

    func testCollapsedViewRestsAgainstParentTrailingEdge() {
        let geometry = makeGeometry()
        let trailingEdge = geometry.collapsedCenter.x + geometry.collapsedSize.width / 2
        XCTAssertEqual(trailingEdge,
                       parentBounds.maxX - SwipeShrinkConfiguration.default.horizontalInset,
                       accuracy: 0.0001)
    }

    func testCollapsedViewStaysInsideParentBounds() {
        let geometry = makeGeometry()
        let frame = CGRect(x: geometry.collapsedCenter.x - geometry.collapsedSize.width / 2,
                           y: geometry.collapsedCenter.y - geometry.collapsedSize.height / 2,
                           width: geometry.collapsedSize.width,
                           height: geometry.collapsedSize.height)
        XCTAssertTrue(parentBounds.contains(frame))
    }

    func testCollapsedWidthNeverExceedsExpandedWidth() {
        let narrow = makeGeometry(expandedFrame: CGRect(x: 0, y: 0, width: 80, height: 45))
        XCTAssertLessThanOrEqual(narrow.collapsedSize.width, narrow.expandedSize.width)
    }

    // MARK: - Progress

    func testProgressIsZeroAtExpandedCenterAndOneAtCollapsedCenter() {
        let geometry = makeGeometry()
        XCTAssertEqual(geometry.progress(forCenterY: geometry.expandedCenter.y), 0, accuracy: 0.0001)
        XCTAssertEqual(geometry.progress(forCenterY: geometry.collapsedCenter.y), 1, accuracy: 0.0001)
    }

    func testProgressIsClampedOutsideTheTravelRange() {
        let geometry = makeGeometry()
        XCTAssertEqual(geometry.progress(forCenterY: geometry.expandedCenter.y - 5_000), 0)
        XCTAssertEqual(geometry.progress(forCenterY: geometry.collapsedCenter.y + 5_000), 1)
    }

    func testProgressAndCenterYRoundTrip() {
        let geometry = makeGeometry()
        for step in 0...10 {
            let progress = CGFloat(step) / 10
            XCTAssertEqual(geometry.progress(forCenterY: geometry.centerY(at: progress)),
                           progress,
                           accuracy: 0.0001)
        }
    }

    /// Regression: a degenerate geometry must yield 0, never NaN — assigning a
    /// NaN size to a UIView traps at runtime.
    func testDegenerateGeometryYieldsFiniteValues() {
        let geometry = makeGeometry(expandedFrame: CGRect(x: 0, y: 0, width: 414, height: 233),
                                    parentBounds: CGRect(x: 0, y: 0, width: 414, height: 0))
        XCTAssertFalse(geometry.isValid)
        let progress = geometry.progress(forCenterY: 100)
        XCTAssertTrue(progress.isFinite)
        XCTAssertEqual(progress, 0)
        XCTAssertTrue(geometry.size(at: progress).width.isFinite)
        XCTAssertTrue(geometry.centerX(at: progress).isFinite)
    }

    func testValidGeometryIsReportedValid() {
        XCTAssertTrue(makeGeometry().isValid)
    }

    // MARK: - Resting state

    func testRestingStateSnapsToNearestPositionAtLowVelocity() {
        let geometry = makeGeometry()
        XCTAssertEqual(geometry.restingState(forCenterY: geometry.centerY(at: 0.4), velocityY: 0), .expanded)
        XCTAssertEqual(geometry.restingState(forCenterY: geometry.centerY(at: 0.6), velocityY: 0), .collapsed)
    }

    func testDownwardFlickCollapsesEvenNearTheTop() {
        let geometry = makeGeometry()
        XCTAssertEqual(geometry.restingState(forCenterY: geometry.centerY(at: 0.05), velocityY: 2_000),
                       .collapsed)
    }

    func testUpwardFlickExpandsEvenNearTheBottom() {
        let geometry = makeGeometry()
        XCTAssertEqual(geometry.restingState(forCenterY: geometry.centerY(at: 0.95), velocityY: -2_000),
                       .expanded)
    }

    // MARK: - Configuration

    func testCollapsedWidthRatioIsClamped() {
        var configuration = SwipeShrinkConfiguration()
        configuration.collapsedWidthRatio = 5
        let geometry = makeGeometry(configuration: configuration)
        XCTAssertLessThanOrEqual(geometry.collapsedSize.width, geometry.expandedSize.width)

        configuration.collapsedWidthRatio = -1
        let tiny = makeGeometry(configuration: configuration)
        XCTAssertGreaterThan(tiny.collapsedSize.width, 0)
    }

    func testCustomInsetsAreRespected() {
        let configuration = SwipeShrinkConfiguration(collapsedWidthRatio: 0.4,
                                                     horizontalInset: 24,
                                                     bottomInset: 16)
        let geometry = makeGeometry(configuration: configuration)
        XCTAssertEqual(geometry.collapsedSize.width, parentBounds.width * 0.4 - 24, accuracy: 0.0001)
        XCTAssertEqual(geometry.collapsedCenter.y + geometry.collapsedSize.height / 2,
                       parentBounds.maxY - 16,
                       accuracy: 0.0001)
    }
}
