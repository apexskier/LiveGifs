//
//  InfoViewController.swift
//  LiveGifs
//
//  Created by Cameron Little on 9/28/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import UIKit

class InfoViewController: UIViewController {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var headerView: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        textView.textContainer.lineFragmentPadding = 0
        // textView.textContainerInset = UIEdgeInsetsZero

        headerView.text = NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? String

        let version = NSBundle.mainBundle().infoDictionary?["CFBundleShortVersionString"] as! String
        let build = NSBundle.mainBundle().infoDictionary?[kCFBundleVersionKey as String] as! String

        textView.text = textView.text + "\n\nVersion \(version) (\(build))"
        if DEBUG {
            textView.text = textView.text + " Debug version"
        }
        
        /*
        let twitterUrl = NSURL(string: "https://twitter.com/apexskier")!
        // let websiteUrl = NSURL(string: "http://camlittle.com")
        let twitterLink = NSMutableAttributedString(string: "Twitter")
        twitterLink.addAttribute(NSLinkAttributeName, value: twitterUrl, range: NSRange(location: 0, length: twitterLink.length))

        let text = NSMutableAttributedString(string: textView.text)
        text.appendAttributedString(NSAttributedString(string: "\n"))
        text.appendAttributedString(NSAttributedString(string: "Follow me on "))
        text.appendAttributedString(twitterLink)
        text.appendAttributedString(NSAttributedString(string: "\n\nVersion \(version) (\(build))"))

        if DEBUG {
        text.appendAttributedString(NSAttributedString(string: " Debug version"))
        }

        textView.attributedText = text
        */
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func tapWipeGeneratedFiles(sender: UIButton) {
        let fileManger = NSFileManager.defaultManager()
        let tempDir = NSTemporaryDirectory() as NSString
        var numErrors = 0
        var count = 0
        do {
            let tempFiles = try fileManger.contentsOfDirectoryAtPath(tempDir as String)
            for file in tempFiles {
                do {
                    try fileManger.removeItemAtPath(tempDir.stringByAppendingPathComponent(file))
                } catch {
                    numErrors++
                }
                count++
            }
        } catch { }
        if numErrors > 0 {
            var plural = ""
            if numErrors == 1 {
                plural = "s"
            }
            let alert = UIAlertController(title: "Error", message: "\(numErrors) error\(plural) occurred.", preferredStyle: .Alert)
            let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
            alert.addAction(okay)
            self.presentViewController(alert, animated: true) {}
        } else {
            var plural = ""
            if count == 1 {
                plural = "s"
            }
            let alert = UIAlertController(title: "Success", message: "\(count) items\(plural) removed.", preferredStyle: .Alert)
            let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
            alert.addAction(okay)
            self.presentViewController(alert, animated: true) {}
        }
    }

    @IBAction func tapDone(sender: UIBarButtonItem) {
        dismissViewControllerAnimated(true, completion: nil)
    }
}
