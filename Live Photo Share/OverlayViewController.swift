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
class OverlayViewController: UIViewController, VideoEditorControlsDelegate {
    @IBOutlet weak var gifButton: UIBarButtonItem!
    @IBOutlet weak var movieButton: UIBarButtonItem!
    @IBOutlet weak var livephotoView: PHLivePhotoView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var progressBarContainer: UIView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var stackViewContainer: UIView!
    @IBOutlet weak var editingView: UIView!
    @IBOutlet weak var editingControls: UIView!
    @IBOutlet weak var editDoneButton: UIButton!
    @IBOutlet weak var editSaveButton: UIButton!
    @IBOutlet weak var stackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var editViewBottomConstraint: NSLayoutConstraint!
    var editingControlsController: VideoEditorControls?

    var running = false
    var progressIsUp = false

    var editIsSetUp = false
    var editInformation = EditInformation()
    var videoURL: NSURL?
    var orientation: UIImageOrientation?
    var frameRatio: CGFloat?

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
        editViewBottomConstraint.active = false
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        self.editingControlsController = segue.destinationViewController as? VideoEditorControls
        self.editingControlsController?.delegate = self
    }

    override func viewDidAppear(animated: Bool) {
        if progressIsUp {
            progressBarContainer.frame.size.height = 0
            self.progressBarContainer.frame.origin.y += 6
            progressIsUp = false
        }
        // DEBUG
        livephotoView.startPlaybackWithStyle(.Full)
        // TODO editInformation = EditInformation()
        // TODO updateSavable()
    }

    override func viewWillDisappear(animated: Bool) {
        livephotoView.stopPlayback()
        if !editingView.hidden {
            editDoneTap(nil)
            editViewBottomConstraint.active = false
        }
        if editIsSetUp {
            editingControlsController?.tearDown()
            editIsSetUp = false
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
                self.progressBarContainer.frame.origin.y = self.stackViewContainer.frame.minY - 6
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
                self.progressBarContainer.frame.origin.y = self.stackViewContainer.frame.minY
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

    func fetchResources() -> (movie: PHAssetResource, jpeg: PHAssetResource)? {
        let movieFile: PHAssetResource
        let jpegFile: PHAssetResource
        let error: NSError?
        (movieFile, jpegFile, error) = resourcesForLivePhoto(livePhoto)

        if error != nil {
            dispatch_async(dispatch_get_main_queue(), {
                let alert = UIAlertController(title: "Error", message: "Files not found for this photo.", preferredStyle: .Alert)
                let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                alert.addAction(okay)
                self.presentViewController(alert, animated: true, completion: nil)
            })
            return nil
        } else {
            return (movieFile, jpegFile)
        }
    }

    @IBAction func movieTap(sender: AnyObject) {
        if self.livephotoView.livePhoto == nil {
            return
        }
        running = true
        progressUp()

        if let files = fetchResources() {
            let movieFile = files.movie
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
    }

    @IBAction func gifTap(sender: AnyObject) {
        if self.livephotoView.livePhoto == nil {
            return
        }
        running = true
        progressUp()
        if let files = fetchResources() {
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
    }

    @IBAction func silentMovTap(sender: AnyObject) {
        if self.livephotoView.livePhoto == nil {
            return
        }
        running = true
        progressUp()
        if let files = fetchResources() {
            let movieFile = files.movie
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
    }

    @IBAction func editTap(sender: UIButton) {
        if !self.running {
            UIView.animateWithDuration(0.2, delay: 0, options: .CurveEaseInOut, animations: {
                self.stackViewContainer.frame.size.height = 0
                self.stackViewContainer.frame.origin.y = self.stackViewContainer.superview!.frame.height
            }) { finished in
                self.stackView.hidden = true
                self.editViewBottomConstraint.active = true
                self.stackViewBottomConstraint.active = false

                if !self.editIsSetUp {
                    self.setUpEditView({
                        self.stackViewContainer.setNeedsUpdateConstraints()
                        self.editingView.hidden = false
                        UIView.animateWithDuration(0.2, delay: 0, options: .CurveEaseInOut, animations: {
                            let h = self.editingView.frame.size.height + 20
                            self.stackViewContainer.frame.origin.y = self.stackViewContainer.superview!.frame.height - h
                            self.stackViewContainer.frame.size.height = h
                        }) { finished in
                        }
                    })
                } else {
                    self.stackViewContainer.setNeedsUpdateConstraints()
                    self.editingView.hidden = false
                    UIView.animateWithDuration(0.2, delay: 0, options: .CurveEaseInOut, animations: {
                        let h = self.editingView.frame.size.height + 20
                        self.stackViewContainer.frame.origin.y = self.stackViewContainer.superview!.frame.height - h
                        self.stackViewContainer.frame.size.height = h
                    }) { finished in
                    }
                }
            }
        }
    }
    
    // MARK: VideoEditorControls
    
    func setUpEditView(completionHandler: (() -> Void)) {
        let videoResource: PHAssetResource
        let jpegResource: PHAssetResource
        (videoResource, jpegResource) = self.fetchResources()!
        fileForResource(jpegResource, progressHandler: {_ in}, completionHandler: { jpegUrl, error in
            let liveImageJpeg = UIImage(contentsOfFile: jpegUrl.path!)!
            self.orientation = liveImageJpeg.imageOrientation
            self.frameRatio = liveImageJpeg.size.width / liveImageJpeg.size.height
            
            fileForResource(videoResource, progressHandler: {_ in }, completionHandler: { (url: NSURL, error: NSError?) -> Void in
                if error != nil {
                    print(error?.usefulDescription)
                    return
                }
                self.videoURL = url
                self.editingControlsController?.setUp({
                    self.editIsSetUp = true
                    completionHandler()
                })
            })
        })
    }
    
    func imageUpdated(image: UIImage) {
        imageView.image = image
    }
    
    func scrubbingStarted(handle: VideoEditorHandle) {
        livephotoView.hidden = true
        imageView.hidden = false
    }
    
    func scrubbingEnded(handle: VideoEditorHandle) {
        livephotoView.hidden = false
        imageView.hidden = true
    }

    @IBAction func editSaveTap(sender: UIButton?) {
        if self.livephotoView.livePhoto == nil {
            return
        }
        running = true
        progressUp()
        if let files = fetchResources() {
            let movieFile = files.movie
            let jpegFile = files.jpeg
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                editLivePhoto(movieFile: movieFile, jpegFile: jpegFile, editInfo: self.editInformation, progressHandler: { progress in
                    dispatch_async(dispatch_get_main_queue(), {
                        self.progressBar.setProgress(Float(progress), animated: true)
                    })
                }) { error in
                    dispatch_async(dispatch_get_main_queue(), {
                        if error != nil {
                            print(error?.usefulDescription)
                            let alert = UIAlertController(title: "Error", message: "Failed to edit Live Photo.", preferredStyle: .Alert)
                            let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                            alert.addAction(okay)
                            self.presentViewController(alert, animated: true) {
                                self.progressDown()
                                self.running = false
                            }
                        } else {
                            self.progressDown()
                            self.running = false
                            self.doneTap(nil)
                        }
                    })
                }
            })
        }
    }

    @IBAction func editDoneTap(sender: UIButton?) {
        if !running {
            if progressIsUp {
                self.progressDown()
            }
            UIView.animateWithDuration(0.2, delay: 0, options: .CurveEaseInOut, animations: {
                self.stackViewContainer.frame.size.height = 0
                self.stackViewContainer.frame.origin.y = self.stackViewContainer.superview!.frame.height
            }) { finished in
                self.stackView.hidden = false
                self.editingView.hidden = true
                self.editViewBottomConstraint.active = false
                self.stackViewBottomConstraint.active = true
                self.stackViewContainer.setNeedsUpdateConstraints()

                UIView.animateWithDuration(0.2, delay: 0, options: .CurveEaseInOut, animations: {
                    let h = self.stackView.frame.size.height + 20
                    self.stackViewContainer.frame.origin.y = self.stackViewContainer.superview!.frame.height - h
                    self.stackViewContainer.frame.size.height = h
                }) { finished in
                    if finished {
                    }
                }
            }
        }
    }

    @IBAction func doneTap(sender: AnyObject?) {
        if !self.running {
            dismissViewControllerAnimated(true) {
                self.progressDown()
                // self.livephotoView.livePhoto = nil
            }
        }
    }
}
