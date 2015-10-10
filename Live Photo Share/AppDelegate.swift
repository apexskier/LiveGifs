//
//  AppDelegate.swift
//  LiveGifs
//
//  Created by Cameron Little on 9/25/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    let recentLivePhotoQuickAction = "recentLivePhotoQuickAction"

    var window: UIWindow?
    var onceViewControllerListening = runWhenReady()

    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.

        NSNotificationCenter.defaultCenter().addObserverForName("viewControllerListening", object: nil, queue: nil) { (notification: NSNotification!) in
            self.onceViewControllerListening.ready = true
        }

        window?.tintColor = darkYellow

        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        NSNotificationCenter.defaultCenter().postNotificationName("wakeUp", object: nil)
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
        print(self.window!.rootViewController)
        if shortcutItem.type == "\(NSBundle.mainBundle().bundleIdentifier!).most-recent" {
            onceViewControllerListening.queue {
                NSNotificationCenter.defaultCenter().postNotificationName("trigger", object: Action(indexPath:  NSIndexPath(forItem: 0, inSection: 0), action: ""))
            }
        }
    }
}

class runWhenReady {
    var _ready = false
    var actions: [() -> Void] = []

    func queue(actionFunc: () -> Void) {
        if _ready {
            actionFunc()
        } else {
            actions.append(actionFunc)
        }
    }

    var ready: Bool {
        get {
            return _ready
        }
        set (val) {
            if val {
                for action in actions {
                    action()
                }
            }
            _ready = val
        }
    }
}
