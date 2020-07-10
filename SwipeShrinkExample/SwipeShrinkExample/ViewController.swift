//
//  ViewController.swift
//  SwipeShrinkExample
//
//  Created by Mücahid Eyvaz on 10.07.2020.
//  Copyright © 2020 Mücahid Eyvaz. All rights reserved.
//

import AVFoundation
import AVKit
import UIKit

public class ViewController: UIViewController {
    @IBOutlet weak var shrinkedView: UIView!

    private let shrink: SwipeShrink = SwipeShrink()

    private let player: AVPlayer = AVPlayer()
    private let playerViewController: AVPlayerViewController = AVPlayerViewController()

    public override func viewDidLoad() {
        super.viewDidLoad()
        let url: URL = Bundle.main.url(forResource: "bayw-HD", withExtension: "mp4")!
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        playerViewController.player = player
        playerViewController.willMove(toParent: self)
        addChild(playerViewController)
        shrinkedView.addSubview(playerViewController.view)
        playerViewController.didMove(toParent: self)
        playerViewController.view.snp.makeConstraints({ $0.edges.equalToSuperview() })
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        shrink.prepare(shrinkedView, view)
    }
}
