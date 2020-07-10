import Foundation
import UIKit
import SnapKit

public class SwipeShrink: NSObject {
    private unowned var mView: UIView!
    private var panGesture: ShrinkPanGesture!
    private var tapGesture: ShrinkTapGesture!

    var initialCenter: CGPoint?
    var finalCenter: CGPoint?
    var initialSize: CGSize?
    var finalSize: CGSize?
    var firstX: CGFloat = 0, firstY: CGFloat = 0
    var aspectRatio: CGFloat = 0.5625

    var rangeTotal: CGFloat!
    var widthRange: CGFloat!
    var centerXRange: CGFloat!

    public func prepare(_ view: UIView, _ parentView: UIView) {
        mView = view
        panGesture = ShrinkPanGesture(view, parentView, self)
        tapGesture = ShrinkTapGesture(view, parentView, self)
        configureSizeAndPosition(parentView.frame)
    }

    public func configureSizeAndPosition(_ parentViewFrame: CGRect) {
        let frame: CGRect = mView.frame
        initialCenter = mView.center
        finalCenter = CGPoint(x: parentViewFrame.size.width - parentViewFrame.size.width / 4, y: parentViewFrame.size.height - (frame.size.height / 4) - 2)

        initialSize = frame.size
        finalSize = CGSize(width: parentViewFrame.size.width / 2 - 10, height: (parentViewFrame.size.width / 2 - 10) * aspectRatio)

        // Set common range totals once
        rangeTotal = finalCenter!.y - initialCenter!.y
        widthRange = initialSize!.width - finalSize!.width
        centerXRange = finalCenter!.x - initialCenter!.x
    }

    // MARK: -- ShrinkTapGesture
    public class ShrinkPanGesture: NSObject {
        private unowned var mShrink: SwipeShrink
        private unowned var mView: UIView
        private unowned var mParentView: UIView

        @discardableResult
        public init(_ view: UIView, _ parentView: UIView, _ shrink: SwipeShrink) {
            self.mView = view
            self.mParentView = parentView
            self.mShrink = shrink
            super.init()
            prepare()
        }

        private func prepare() {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panning(_:)))
            panGesture.minimumNumberOfTouches = 1
            panGesture.maximumNumberOfTouches = 1
            mView.addGestureRecognizer(panGesture)
        }

        @objc public func panning(_ panGesture: UIPanGestureRecognizer) {
            let translatedPoint = panGesture.translation(in: mParentView)
            var gestureState = panGesture.state

            let yChange = panGesture.view!.center.y + translatedPoint.y
            if yChange < mShrink.initialCenter!.y {
                gestureState = UIGestureRecognizer.State.ended

            } else if yChange >= mShrink.finalCenter!.y {
                gestureState = UIGestureRecognizer.State.ended
            }

            if gestureState == UIGestureRecognizer.State.began || gestureState == UIGestureRecognizer.State.changed {
                // modify size as view is panned down
                let progress = ((panGesture.view!.center.y - mShrink.initialCenter!.y) / mShrink.rangeTotal)

                let invertedProgress = 1 - progress
                let newWidth = mShrink.finalSize!.width + (mShrink.widthRange * invertedProgress)

                panGesture.view?.frame.size = CGSize(width: newWidth, height: newWidth * mShrink.aspectRatio)
                // ensure center x value moves along with size change
                let finalX = mShrink.initialCenter!.x + (mShrink.centerXRange * progress)

                panGesture.view?.center = CGPoint(x: finalX, y: panGesture.view!.center.y + translatedPoint.y)
                updateConstraintsByRect(panGesture.view!, size: CGSize(width: newWidth, height: newWidth * mShrink.aspectRatio), center: CGPoint(x: finalX, y: panGesture.view!.center.y + translatedPoint.y))
                panGesture.setTranslation(CGPoint(x: 0, y: 0), in: mParentView)

            } else if gestureState == UIGestureRecognizer.State.ended {
                let topDistance = yChange - mShrink.initialCenter!.y
                let bottomDistance = mShrink.finalCenter!.y - yChange

                var chosenCenter: CGPoint = .zero
                var chosenSize: CGSize = .zero
                //            mView.isUserInteractionEnabled = false

                if topDistance > bottomDistance {
                    // animate to bottom
                    chosenCenter = mShrink.finalCenter!
                    chosenSize = mShrink.finalSize!

                } else {
                    // animate to top
                    chosenCenter = mShrink.initialCenter!
                    chosenSize = mShrink.initialSize!
                }

                if panGesture.view?.center != chosenCenter {
                    UIView.animate(withDuration: 0.4, animations: {
                        panGesture.view?.frame.size = chosenSize
                        panGesture.view?.center = chosenCenter
                        self.updateConstraintsByRect(panGesture.view!, size: chosenSize, center: chosenCenter)
                    }, completion: { (_: Bool) in
                        self.mView.isUserInteractionEnabled = true
                    })
                } else {
                    mView.isUserInteractionEnabled = true
                }
            }
        }

        public func updateConstraintsByRect(_ view: UIView, size: CGSize, center: CGPoint){
            view.frame.size.width = size.width
            view.frame.size.height = size.height
            view.center.x = center.x
            view.center.y = center.y
//            view.snp.remakeConstraints({
//                $0.width.equalTo(size.width)
//                $0.height.equalTo(size.height)
//                $0.centerX.equalTo(center.x)
//                $0.centerY.equalTo(center.y)
//            })
        }
    }

    // MARK: -- ShrinkTapGesture
    public class ShrinkTapGesture: NSObject, UIGestureRecognizerDelegate {
        private unowned var mShrink: SwipeShrink
        private unowned var mView: UIView
        private unowned var mParentView: UIView

        @discardableResult
        public init(_ view: UIView, _ parentView: UIView, _ shrink: SwipeShrink) {
            self.mView = view
            self.mShrink = shrink
            self.mParentView = parentView
            super.init()
            prepare()
        }

        private func prepare() {
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            tapGesture.numberOfTapsRequired = 1
            mView.addGestureRecognizer(tapGesture)
            tapGesture.delegate = self
        }

        @objc public func tapped(_ tapGesture: UITapGestureRecognizer) {
            if tapGesture.view?.center == mShrink.finalCenter {
                mView.isUserInteractionEnabled = false
                UIView.animate(withDuration: 0.4, animations: {
                    tapGesture.view?.frame.size = self.mShrink.initialSize!
                    tapGesture.view?.center = self.mShrink.initialCenter!

                }, completion: { (_: Bool) in
                    self.mView.isUserInteractionEnabled = true
                })
            }
        }

        public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}
