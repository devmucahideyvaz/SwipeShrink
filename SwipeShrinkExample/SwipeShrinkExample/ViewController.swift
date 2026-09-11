//
//  ViewController.swift
//  SwipeShrinkExample
//
//  Created by Mücahid Eyvaz on 10.07.2020.
//  Copyright © 2020 Mücahid Eyvaz. All rights reserved.
//

import AVFoundation
import AVKit
import SwipeShrink
import UIKit

// `UIViewController` is `@MainActor`-isolated, so this subclass and everything
// it touches — including `SwipeShrink` — is on the main actor.
final class ViewController: UIViewController {
    @IBOutlet weak var shrinkedView: UIView!

    private let shrink = SwipeShrink()
    private let player = AVPlayer()
    private let playerViewController = AVPlayerViewController()

    private var hasPreparedShrink = false
    private var lastLayoutSize: CGSize = .zero

    override func viewDidLoad() {
        super.viewDidLoad()
        embedPlayer()
        loadVideo()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // `prepare` needs the final laid-out frames, which are only settled by
        // the time the view has appeared. It is idempotent, but there is no
        // reason to redo the work on every appearance.
        guard !hasPreparedShrink else { return }
        hasPreparedShrink = true
        shrinkedView.frame = expandedPlayerFrame()
        shrink.prepare(view: shrinkedView, in: view)
        lastLayoutSize = view.bounds.size
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard hasPreparedShrink else { return }
        // Recompute only when the parent actually resized, so ordinary layout
        // passes never snap the view out from under a drag.
        guard view.bounds.size != lastLayoutSize else { return }
        lastLayoutSize = view.bounds.size
        // Both the new size and the new safe-area insets are final here. Doing
        // this from `viewWillTransition`'s alongside block instead would pair
        // the post-rotation size with the pre-rotation insets, which differ
        // between portrait and landscape.
        shrink.updateLayout(expandedFrame: expandedPlayerFrame())
    }

    /// Full-width, 16:9, tucked under the safe area.
    private func expandedPlayerFrame() -> CGRect {
        let width = view.bounds.width
        return CGRect(x: 0,
                      y: view.safeAreaInsets.top,
                      width: width,
                      height: width * 9 / 16)
    }

    private func embedPlayer() {
        playerViewController.player = player
        addChild(playerViewController)
        // Pinned with an autoresizing mask rather than constraints so the
        // player tracks `shrinkedView` as SwipeShrink resizes it.
        playerViewController.view.frame = shrinkedView.bounds
        playerViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shrinkedView.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)
    }

    private func loadVideo() {
        guard let url = Bundle.main.url(forResource: "bayw-HD", withExtension: "mp4") else {
            assertionFailure("Sample video is missing from the app bundle.")
            return
        }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
    }
}
