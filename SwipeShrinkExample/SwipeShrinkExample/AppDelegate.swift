//
//  AppDelegate.swift
//  SwipeShrinkExample
//
//  Created by Mücahid Eyvaz on 10.07.2020.
//  Copyright © 2020 Mücahid Eyvaz. All rights reserved.
//

import UIKit

// `@main` replaces the deprecated `@UIApplicationMain`; under Swift 6 the
// delegate conformance is main-actor isolated, which `UIResponder` already is.
@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }
}
