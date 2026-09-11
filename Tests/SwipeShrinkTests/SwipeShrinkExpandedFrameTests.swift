import CoreGraphics
import XCTest
@testable import SwipeShrink

final class SwipeShrinkExpandedFrameTests: XCTestCase {

    private let parentSize = CGSize(width: 414, height: 896)

    func testVideoDefaultIsFullWidth16By9AtTheTop() {
        let rect = SwipeShrinkExpandedFrame.video.rect(in: parentSize)
        XCTAssertEqual(rect.minX, 0, accuracy: 0.0001)
        XCTAssertEqual(rect.minY, 0, accuracy: 0.0001)
        XCTAssertEqual(rect.width, parentSize.width, accuracy: 0.0001)
        XCTAssertEqual(rect.height, parentSize.width * 9 / 16, accuracy: 0.0001)
    }

    func testNarrowerFrameIsHorizontallyCentred() {
        let frame = SwipeShrinkExpandedFrame(widthRatio: 0.5)
        let rect = frame.rect(in: parentSize)
        XCTAssertEqual(rect.midX, parentSize.width / 2, accuracy: 0.0001)
        XCTAssertEqual(rect.width, parentSize.width / 2, accuracy: 0.0001)
    }

    func testTopInsetIsApplied() {
        let rect = SwipeShrinkExpandedFrame(topInset: 44).rect(in: parentSize)
        XCTAssertEqual(rect.minY, 44, accuracy: 0.0001)
    }

    func testWidthRatioIsClamped() {
        let tooWide = SwipeShrinkExpandedFrame(widthRatio: 3).rect(in: parentSize)
        XCTAssertEqual(tooWide.width, parentSize.width, accuracy: 0.0001)

        let tooNarrow = SwipeShrinkExpandedFrame(widthRatio: 0).rect(in: parentSize)
        XCTAssertGreaterThan(tooNarrow.width, 0)
    }

    func testNonPositiveAspectRatioStillYieldsAPositiveHeight() {
        let rect = SwipeShrinkExpandedFrame(aspectRatio: 0).rect(in: parentSize)
        XCTAssertGreaterThan(rect.height, 0)
    }

    /// The resolved frame is what SwiftUI feeds into the shared geometry, so it
    /// has to produce a usable transition rather than a degenerate one.
    func testResolvedFrameDrivesAValidGeometry() {
        let expanded = SwipeShrinkExpandedFrame.video.rect(in: parentSize)
        let geometry = SwipeShrinkGeometry(expandedFrame: expanded,
                                           parentBounds: CGRect(origin: .zero, size: parentSize))
        XCTAssertTrue(geometry.isValid)
        XCTAssertEqual(geometry.aspectRatio, 9.0 / 16.0, accuracy: 0.0001)
        XCTAssertEqual(geometry.size(at: 0).width, expanded.width, accuracy: 0.0001)
    }
}
