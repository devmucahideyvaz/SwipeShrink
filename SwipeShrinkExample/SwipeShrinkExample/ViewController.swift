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
        shrink.prepare(view: shrinkedView, in: view)
    }

    override func viewWillTransition(to size: CGSize,
                                     with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            // `shrinkedView` is positioned by a fixed frame in the storyboard,
            // so hand SwipeShrink the expanded frame for the new size instead
            // of letting it read a stale one.
            self.shrink.updateLayout(expandedFrame: self.expandedPlayerFrame(forParentSize: size))
        })
    }

    /// Full-width, 16:9, tucked under the status bar.
    private func expandedPlayerFrame(forParentSize size: CGSize) -> CGRect {
        let top = view.safeAreaInsets.top
        return CGRect(x: 0, y: top, width: size.width, height: size.width * 9 / 16)
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
