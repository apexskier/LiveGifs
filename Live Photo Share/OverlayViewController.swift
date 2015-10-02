//
//  OverlayViewController.swift
//  LiveGifs
//
//  Created by Cameron Little on 9/28/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import UIKit
import PhotosUI

@available(iOS 9.1, *)
class OverlayViewController: UIViewController {
    @IBOutlet weak var gifButton: UIBarButtonItem!
    @IBOutlet weak var movieButton: UIBarButtonItem!
    @IBOutlet weak var livephotoView: PHLivePhotoView!
    @IBOutlet weak var progressBarContainer: UIView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var toolbar: UIToolbar!

    var running = false
    var progressIsUp = false

    var observers: [AnyObject] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("shareGif", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification: NSNotification!) -> Void in
            self.gifTap(notification)
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("shareMov", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification: NSNotification!) -> Void in
            self.movieTap(notification)
        }))
        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("shareSilentMov", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification: NSNotification!) -> Void in
            self.silentMovTap(notification)
        }))

        // Do any additional setup after loading the view.
        progressBar.progress = 0
    }

    override func viewDidAppear(animated: Bool) {
        if progressIsUp {
            progressBarContainer.frame.size.height = 0
            self.progressBarContainer.frame.origin.y += 6
            progressIsUp = false
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func progressUp() {
        if !progressIsUp {
            toolbar.clipsToBounds = true
            UIView.animateWithDuration(0.2, delay: 0, options: .CurveEaseInOut, animations: {
                self.progressBarContainer.frame.size.height = 6
                self.progressBarContainer.frame.origin.y -= 6
            }) { finished in
                if finished {
                    self.progressIsUp = true
                }
            }
        }
    }

    func progressDown() {
        if progressIsUp {
            UIView.animateWithDuration(0.4, delay: 0.2, options: .CurveEaseInOut, animations: {
                self.progressBarContainer.frame.size.height = 0
                self.progressBarContainer.frame.origin.y += 6
            }) { finished in
                self.progressBar.progress = 0
                if finished {
                    self.progressIsUp = false
                    self.toolbar.clipsToBounds = false
                }
            }
        }
    }

    @available(iOS 9.1, *)
    var livePhoto: PHLivePhoto {
        get {
            return self.livephotoView.livePhoto!
        }
    }

    func fetchResources() -> (movie: PHAssetResource, jpeg: PHAssetResource) {
        let resources = PHAssetResource.assetResourcesForLivePhoto(livePhoto)
        var movieFile: PHAssetResource?
        var jpegFile: PHAssetResource?
        for item in resources {
            switch item.type {
            case .Photo:
                jpegFile = item as PHAssetResource
            case .PairedVideo:
                movieFile = item as PHAssetResource
            default:
                break
            }
        }

        if movieFile == nil || jpegFile == nil {
            dispatch_async(dispatch_get_main_queue(), {
                let alert = UIAlertController(title: "Error", message: "No movie file found for this photo.", preferredStyle: .Alert)
                let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                alert.addAction(okay)
                self.presentViewController(alert, animated: true, completion: nil)
            })
        }

        return (movieFile!, jpegFile!)
    }

    @IBAction func movieTap(sender: AnyObject) {
        if self.livephotoView.livePhoto == nil {
            return
        }
        running = true
        let files = fetchResources()
        let movieFile = files.movie
        progressUp()

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            livePhotoToMovie(movieFile: movieFile, progressHandler: { (progress) in
                print("mov creation progress: \(progress)")
                dispatch_async(dispatch_get_main_queue(), {
                    self.progressBar.setProgress(Float(progress), animated: true)
                })
            }, completionHandler: { (url: NSURL, error: NSError?) in
                dispatch_async(dispatch_get_main_queue(), {
                    if error != nil {
                        print(error?.usefulDescription)
                        let alert = UIAlertController(title: "Error", message: "Failed to fetch movie.", preferredStyle: .Alert)
                        let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                        alert.addAction(okay)
                        self.presentViewController(alert, animated: true) {
                            self.progressDown()
                            self.running = false
                        }
                    } else {
                        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        sheet.excludedActivityTypes = [UIActivityTypePrint]
                        self.presentViewController(sheet, animated: true) {
                            self.progressDown()
                            self.running = false
                        }
                    }
                })
            })
        })
    }

    @IBAction func gifTap(sender: AnyObject) {
        if self.livephotoView.livePhoto == nil {
            return
        }
        running = true
        progressUp()
        let files = fetchResources()
        let movieFile = files.movie
        let jpegFile = files.jpeg
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            livePhotoToGif(movieFile: movieFile, jpegFile: jpegFile, progressHandler: { (progress) in
                print("gif creation progress: \(progress)")
                dispatch_async(dispatch_get_main_queue(), {
                    self.progressBar.setProgress(Float(progress), animated: true)
                })
            }, completionHandler: { (url: NSURL, error: NSError?) in
                dispatch_async(dispatch_get_main_queue(), {
                    if error != nil {
                        print(error?.usefulDescription)
                        let alert = UIAlertController(title: "Error", message: "Failed to generate GIF.", preferredStyle: .Alert)
                        let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                        alert.addAction(okay)
                        self.presentViewController(alert, animated: true) {
                            self.progressDown()
                            self.running = false
                        }
                    } else {
                        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        sheet.excludedActivityTypes = [UIActivityTypePrint]
                        self.presentViewController(sheet, animated: true) {
                            self.progressDown()
                            self.running = false
                        }
                    }
                })
            })
        })
    }

    @IBAction func silentMovTap(sender: AnyObject) {
        if self.livephotoView.livePhoto == nil {
            return
        }
        running = true
        let files = fetchResources()
        let movieFile = files.movie
        progressUp()

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            livePhotoToSilentMovie(movieFile: movieFile, progressHandler: { (progress) in
                print("silent mov creation progress: \(progress)")
                dispatch_async(dispatch_get_main_queue(), {
                    self.progressBar.setProgress(Float(progress), animated: true)
                })
            }, completionHandler: { (url: NSURL, error: NSError?) in
                dispatch_async(dispatch_get_main_queue(), {
                    if error != nil {
                        print(error?.usefulDescription)
                        let alert = UIAlertController(title: "Error", message: "Failed to fetch movie.", preferredStyle: .Alert)
                        let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                        alert.addAction(okay)
                        self.presentViewController(alert, animated: true) {
                            self.progressDown()
                            self.running = false
                        }
                    } else {
                        let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                        sheet.excludedActivityTypes = [UIActivityTypePrint]
                        self.presentViewController(sheet, animated: true) {
                            self.progressDown()
                            self.running = false
                        }
                    }
                })
            })
        })
    }

    @IBAction func doneTap(sender: AnyObject) {
        if !self.running {
            dismissViewControllerAnimated(true) {
                self.progressDown()
                // self.livephotoView.livePhoto = nil
            }
        }
    }
}
