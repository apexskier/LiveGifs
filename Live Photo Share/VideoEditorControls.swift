//
//  VideoEditorControls.swift
//  Live Photo Share
//
//  Created by Cameron Little on 10/21/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Foundation
import UIKit
import Photos

class VideoEditorControls: UIViewController {
    @IBOutlet weak var thumbnailView: UIView!
    @IBOutlet weak var leftHandle: VideoEditorLeftHandle!
    @IBOutlet weak var leftCropOverlay: UIView!
    @IBOutlet weak var centerHandle: VideoEditorCenterHandle!
    @IBOutlet weak var rightHandle: VideoEditorRightHandle!
    @IBOutlet weak var rightCropOverlay: UIView!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    @IBOutlet weak var saveButton: UIButton!

    var isSetUp = false
    var editInformation = EditInformation()
    var containsSaveButton = true

    override func viewDidLoad() {
        let cornerRadius: CGFloat = 4
        saveButton.hidden = containsSaveButton

        leftHandle.subviews.first?.layer.cornerRadius = cornerRadius
        leftHandle.subviews.first?.layer.masksToBounds = true
        rightHandle.subviews.first?.layer.cornerRadius = cornerRadius
        rightHandle.subviews.first?.layer.masksToBounds = true
        centerHandle.subviews.first?.layer.cornerRadius = cornerRadius
        centerHandle.subviews.first?.layer.masksToBounds = true
    }

    func updateSavable() {
        if editInformation.dirty {
            saveButton.enabled = true
            resetButton.enabled = true
        } else {
            saveButton.enabled = false
            resetButton.enabled = false
        }
    }

    func setUp(completionHandler: (() -> Void)) {
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

                self.leftHandle.rightBound = (self.view.bounds.width / 2) - (self.centerHandle.frame.width / 2)
                self.rightHandle.leftBound = (self.view.bounds.width / 2) + (self.centerHandle.frame.width / 2)
                self.centerHandle.leftBound = self.leftHandle.frame.width
                self.centerHandle.rightBound = self.view.bounds.width - self.rightHandle.frame.width
                let handleWidth = self.view.bounds.width - (self.rightHandle.frame.width + self.leftHandle.frame.width + self.centerHandle.frame.width)
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
                    self.rightCropOverlay.frame.size.width = self.view.bounds.width - m
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
                let totalWidth = self.view.bounds.size.width - CGFloat(xPadding * 2)
                let height = Int(self.thumbnailView.bounds.size.height) - (yPadding * 2)
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
                            self.thumbnailView.insertSubview(imageView, atIndex: 0)

                            widthSoFar += thisWidth
                            i++
                        }
                    } catch let error as NSError {
                        print(error.usefulDescription)
                    }

                    self.isSetUp = true

                    completionHandler()
                })
            })
        })
    }

    func tearDown() {
        self.thumbnailView.subviews.forEach({ $0.removeFromSuperview() })
        self.isSetUp = false
        self.leftHandle.clearHandlers()
        self.rightHandle.clearHandlers()
        self.centerHandle.clearHandlers()
    }

    @IBAction func saveTap(sender: UIButton?) {
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

    @IBAction func muteTap(sender: UIButton?) {
        self.editInformation.muted = !self.editInformation.muted
        if self.editInformation.muted {
            self.muteButton.setTitle("Unmute", forState: .Normal)
        } else {
            self.muteButton.setTitle("Mute", forState: .Normal)
        }
        updateSavable()
    }

    @IBAction func resetTap(sender: AnyObject) {
        editInformation.reset()
        UIView.animateWithDuration(0.2, delay: 0, options: .CurveEaseInOut, animations: {
            self.centerHandle.frame.origin.x = (self.view.bounds.width / 2) - (self.centerHandle.frame.width / 2)
            self.leftHandle.frame.origin.x = 0
            self.rightHandle.frame.origin.x = self.view.bounds.width - self.rightHandle.frame.width
            let m = self.rightHandle.frame.midX
            self.rightCropOverlay.frame.origin.x = m
            self.rightCropOverlay.frame.size.width = self.view.bounds.width - m
            self.leftCropOverlay.frame.size.width = self.leftHandle.frame.midX
            }) { finished in
                self.muteButton.setTitle("Mute", forState: .Normal)
                self.updateSavable()
        }
    }
}