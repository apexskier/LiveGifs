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
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var progressBarContainer: UIView!
    @IBOutlet weak var progressBar: UIProgressView!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var stackViewContainer: UIView!
    @IBOutlet weak var editingView: UIView!
    @IBOutlet weak var editingThumbnailView: UIView!
    @IBOutlet weak var leftHandle: VideoEditorLeftHandle!
    @IBOutlet weak var leftCropOverlay: UIView!
    @IBOutlet weak var centerHandle: VideoEditorCenterHandle!
    @IBOutlet weak var rightHandle: VideoEditorRightHandle!
    @IBOutlet weak var rightCropOverlay: UIView!
    @IBOutlet weak var editDoneButton: UIButton!
    @IBOutlet weak var editSaveButton: UIButton!
    @IBOutlet weak var editMuteButton: UIButton!
    @IBOutlet weak var editResetButton: UIButton!
    @IBOutlet weak var stackViewBottomConstraint: NSLayoutConstraint!
    @IBOutlet weak var editViewBottomConstraint: NSLayoutConstraint!

    var running = false
    var progressIsUp = false

    var editIsSetUp = false

    var observers: [AnyObject] = []

    var editInformation = EditInformation()

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

        let cornerRadius: CGFloat = 4

        leftHandle.subviews.first?.layer.cornerRadius = cornerRadius
        leftHandle.subviews.first?.layer.masksToBounds = true
        rightHandle.subviews.first?.layer.cornerRadius = cornerRadius
        rightHandle.subviews.first?.layer.masksToBounds = true
        centerHandle.subviews.first?.layer.cornerRadius = cornerRadius
        centerHandle.subviews.first?.layer.masksToBounds = true
    }

    override func viewDidAppear(animated: Bool) {
        if progressIsUp {
            progressBarContainer.frame.size.height = 0
            self.progressBarContainer.frame.origin.y += 6
            progressIsUp = false
        }
        // DEBUG
        livephotoView.startPlaybackWithStyle(.Full)
        editInformation = EditInformation()
        updateSavable()
    }

    override func viewWillDisappear(animated: Bool) {
        livephotoView.stopPlayback()
        if !editingView.hidden {
            editDoneTap(nil)
            editViewBottomConstraint.active = false
        }
        if editIsSetUp {
            tearDownEditView()
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

    func updateSavable() {
        if editInformation.dirty {
            editSaveButton.enabled = true
            editResetButton.enabled = true
        } else {
            editSaveButton.enabled = false
            editResetButton.enabled = false
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

    func setUpEditView(completionHandler: (() -> Void)) {
        let videoResource: PHAssetResource
        let jpegResource: PHAssetResource
        (videoResource, jpegResource) = self.fetchResources()!
        fileForResource(jpegResource, progressHandler: {_ in}, completionHandler: { jpegUrl, error in
            let liveImageJpeg = UIImage(contentsOfFile: jpegUrl.path!)!
            let orientation = liveImageJpeg.imageOrientation
            let ratio = liveImageJpeg.size.width / liveImageJpeg.size.height

            fileForResource(videoResource, progressHandler: {_ in }, completionHandler: { (url: NSURL, error: NSError?) -> Void in
                if error != nil {
                    print(error?.usefulDescription)
                    return
                }

                let movAsset = AVAsset(URL: url)

                let generator = AVAssetImageGenerator(asset: movAsset)
                generator.requestedTimeToleranceAfter = kCMTimeZero
                generator.requestedTimeToleranceBefore = kCMTimeZero

                let totalTime = movAsset.duration.seconds
                let videoTrack = movAsset.tracks[0]
                let frameRate = videoTrack.nominalFrameRate

                var currentFrame: Float = -1
                func setImage(percent: CGFloat) {
                    let seconds = Double(percent) * totalTime
                    let time = CMTime(seconds: seconds, preferredTimescale: 6000)
                    let frame = floor(frameRate * Float(seconds))
                    // avoid regenerating image if we don't need to
                    if frame != currentFrame {
                        currentFrame = frame
                        do {
                            let image = UIImage(CGImage: try generator.copyCGImageAtTime(time, actualTime: nil), scale: 1, orientation: orientation)
                            self.imageView.image = image
                        } catch {}
                    }
                }

                self.leftHandle.rightBound = (self.editingView.bounds.width / 2) - (self.centerHandle.frame.width / 2)
                self.rightHandle.leftBound = (self.editingView.bounds.width / 2) + (self.centerHandle.frame.width / 2)
                self.centerHandle.leftBound = self.leftHandle.frame.width
                self.centerHandle.rightBound = self.editingView.bounds.width - self.rightHandle.frame.width
                let handleWidth = self.editingView.bounds.width - (self.rightHandle.frame.width + self.leftHandle.frame.width + self.centerHandle.frame.width)
                self.centerHandle.onMove({ p in
                    self.leftHandle.rightBound = self.centerHandle.frame.minX
                    self.rightHandle.leftBound = self.centerHandle.frame.maxX
                    let percent = (p - (self.leftHandle.frame.width + self.centerHandle.frame.width / 2)) / handleWidth
                    self.editInformation.centerImage = Double(percent)
                    setImage(percent)
                })
                self.leftHandle.onMove({ p in
                    self.centerHandle.leftBound = self.leftHandle.frame.maxX
                    let percent = (p - self.leftHandle.frame.width / 2) / handleWidth
                    self.editInformation.leftBound = Double(percent)
                    self.leftCropOverlay.frame.size.width = self.leftHandle.frame.midX
                    setImage(percent)
                })
                self.rightHandle.onMove({ p in
                    self.centerHandle.rightBound = self.rightHandle.frame.minX
                    let percent = (p - (self.leftHandle.frame.width + self.centerHandle.frame.width + self.rightHandle.frame.width / 2)) / handleWidth
                    self.editInformation.rightBound = Double(percent)
                    let m = self.rightHandle.frame.midX
                    self.rightCropOverlay.frame.origin.x = m
                    self.rightCropOverlay.frame.size.width = self.editingView.frame.width - m
                    setImage(percent)
                })

                self.centerHandle.onTouchDown({
                    self.imageView.hidden = false
                    self.livephotoView.stopPlayback()
                    self.livephotoView.hidden = true
                })
                self.leftHandle.onTouchDown({
                    self.imageView.hidden = false
                    self.livephotoView.stopPlayback()
                    self.livephotoView.hidden = true
                })
                self.rightHandle.onTouchDown({
                    self.imageView.hidden = false
                    self.livephotoView.stopPlayback()
                    self.livephotoView.hidden = true
                })

                self.centerHandle.onTouchUp({
                    self.imageView.hidden = true
                    self.livephotoView.hidden = false
                    self.updateSavable()
                })
                self.leftHandle.onTouchUp({
                    self.imageView.hidden = true
                    self.livephotoView.hidden = false
                    self.updateSavable()
                })
                self.rightHandle.onTouchUp({
                    self.imageView.hidden = true
                    self.livephotoView.hidden = false
                    self.updateSavable()
                })

                let yPadding = 4
                let xPadding = 0
                let totalWidth = self.editingView.bounds.size.width - CGFloat(xPadding * 2)
                let height = Int(self.editingThumbnailView.bounds.size.height) - (yPadding * 2)
                let width = Int(ratio * CGFloat(height))

                dispatch_async(dispatch_get_main_queue(), {
                    do {
                        var widthSoFar = 0
                        var i = 0
                        while CGFloat(widthSoFar) < totalWidth {
                            let seconds = totalTime * Double(CGFloat(widthSoFar) / totalWidth)
                            let time = CMTime(seconds: seconds, preferredTimescale: 6000)
                            let image = UIImage(CGImage: try generator.copyCGImageAtTime(time, actualTime: nil), scale: 1, orientation: orientation)
                            let thisWidth = min(Int(Int(totalWidth) - widthSoFar), width)
                            let imageView = UIImageView(frame: CGRect(x: (i * width) + xPadding, y: yPadding, width: thisWidth, height: height))
                            imageView.image = image
                            imageView.contentMode = UIViewContentMode.ScaleAspectFill
                            imageView.clipsToBounds = true
                            self.editingThumbnailView.insertSubview(imageView, atIndex: 0)

                            widthSoFar += thisWidth
                            i++
                        }
                    } catch let error as NSError {
                        print(error.usefulDescription)
                    }

                    self.editIsSetUp = true

                    completionHandler()
                })
            })
        })
    }

    func tearDownEditView() {
        self.editingThumbnailView.subviews.forEach({ $0.removeFromSuperview() })
        self.editIsSetUp = false
        self.leftHandle.clearHandlers()
        self.rightHandle.clearHandlers()
        self.centerHandle.clearHandlers()
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

    @IBAction func editMuteTap(sender: UIButton?) {
        self.editInformation.muted = !self.editInformation.muted
        if self.editInformation.muted {
            self.editMuteButton.setTitle("Unmute", forState: .Normal)
        } else {
            self.editMuteButton.setTitle("Mute", forState: .Normal)
        }
        updateSavable()
    }

    @IBAction func editResetTap(sender: AnyObject) {
        editInformation.reset()
        UIView.animateWithDuration(0.2, delay: 0, options: .CurveEaseInOut, animations: {
            self.centerHandle.frame.origin.x = (self.editingView.bounds.width / 2) - (self.centerHandle.frame.width / 2)
            self.leftHandle.frame.origin.x = 0
            self.rightHandle.frame.origin.x = self.editingView.bounds.width - self.rightHandle.frame.width
            let m = self.rightHandle.frame.midX
            self.rightCropOverlay.frame.origin.x = m
            self.rightCropOverlay.frame.size.width = self.editingView.frame.width - m
            self.leftCropOverlay.frame.size.width = self.leftHandle.frame.midX
        }) { finished in
            self.editMuteButton.setTitle("Mute", forState: .Normal)
            self.updateSavable()
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
