//
//  MainTabBarViewController.swift
//  Live Photo Share
//
//  Created by Cameron Little on 10/21/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Foundation
import UIKit

class MainTabBarViewController: UITabBarController {
    @IBAction func infoTap(sender: UIButton) {
        let overlayNavController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("InfoNavigationController")
        self.presentViewController(overlayNavController, animated: true, completion: nil)
    }
}