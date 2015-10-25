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

enum VideoEditorHandle {
    case Left
    case Right
    case Center
}

class VideoEditorControls: UIViewController {
    @IBOutlet weak var thumbnailView: UIView!
    @IBOutlet weak var scrubberView: UIView!
    @IBOutlet weak var leftHandle: VideoEditorLeftHandle!
    @IBOutlet weak var leftCropOverlay: UIView!
    @IBOutlet weak var centerHandle: VideoEditorCenterHandle!
    @IBOutlet weak var rightHandle: VideoEditorRightHandle!
    @IBOutlet weak var rightCropOverlay: UIView!
    @IBOutlet weak var muteButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!

    var delegate: VideoEditorControlsDelegate?

    override func viewDidLoad() {
        let cornerRadius: CGFloat = 4

        leftHandle.subviews.first?.layer.cornerRadius = cornerRadius
        leftHandle.subviews.first?.layer.masksToBounds = true
        rightHandle.subviews.first?.layer.cornerRadius = cornerRadius
        rightHandle.subviews.first?.layer.masksToBounds = true
        centerHandle.subviews.first?.layer.cornerRadius = cornerRadius
        centerHandle.subviews.first?.layer.masksToBounds = true
        
        delegate!.editInformation = EditInformation()
    }
    
    func updateSavable() {
        if delegate!.editInformation.dirty {
            resetButton.enabled = true
            self.delegate?.becameSavable()
        } else {
            resetButton.enabled = false
            self.delegate?.becameUnsavable()
        }
    }

    func setUp(completionHandler: (() -> Void)) {
        let movAsset = AVAsset(URL: self.delegate!.videoURL!)
        
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
                    let image = UIImage(CGImage: try generator.copyCGImageAtTime(time, actualTime: nil), scale: 1, orientation: self.delegate!.orientation!)
                    delegate!.imageUpdated(image)
                } catch {}
            }
        }
        
        setImage(0.5)
        
        let handleWidth = self.scrubberView.bounds.width - (self.rightHandle.frame.width + self.leftHandle.frame.width + self.centerHandle.frame.width)
        self.centerHandle.onMove({ p in
            self.leftHandle.rightBound = self.centerHandle.frame.minX
            self.rightHandle.leftBound = self.centerHandle.frame.maxX
            let percent = (p - (self.leftHandle.frame.width + self.centerHandle.frame.width / 2)) / handleWidth
            self.delegate?.editInformation.centerImage = Double(percent)
            setImage(percent)
            self.delegate?.editInformation.centerImage = Double(percent)
        })
        self.leftHandle.onMove({ p in
            self.centerHandle.leftBound = self.leftHandle.frame.maxX
            let percent = (p - self.leftHandle.frame.width / 2) / handleWidth
            self.delegate?.editInformation.leftBound = Double(percent)
            self.leftCropOverlay.frame.size.width = self.leftHandle.frame.midX
            setImage(percent)
            self.delegate?.editInformation.leftBound = Double(percent)
        })
        self.rightHandle.onMove({ p in
            self.centerHandle.rightBound = self.rightHandle.frame.minX
            let percent = (p - (self.leftHandle.frame.width + self.centerHandle.frame.width + self.rightHandle.frame.width / 2)) / handleWidth
            self.delegate?.editInformation.rightBound = Double(percent)
            let m = self.rightHandle.frame.midX
            self.rightCropOverlay.frame.origin.x = m
            self.rightCropOverlay.frame.size.width = self.scrubberView.bounds.width - m
            setImage(percent)
            self.delegate?.editInformation.rightBound = Double(percent)
        })
        
        self.centerHandle.onTouchDown({
            self.delegate?.scrubbingStarted(.Center)
        })
        self.leftHandle.onTouchDown({
            self.delegate?.scrubbingStarted(.Left)
        })
        self.rightHandle.onTouchDown({
            self.delegate?.scrubbingStarted(.Right)
        })
        
        self.centerHandle.onTouchUp({
            self.delegate?.scrubbingEnded(.Center)
            self.updateSavable()
        })
        self.leftHandle.onTouchUp({
            self.delegate?.scrubbingEnded(.Left)
            self.updateSavable()
        })
        self.rightHandle.onTouchUp({
            self.delegate?.scrubbingEnded(.Right)
            self.updateSavable()
        })
        
        let totalWidth = self.thumbnailView.bounds.size.width
        let height = Int(self.thumbnailView.bounds.size.height)
        let width = Int(self.delegate!.frameRatio! * CGFloat(height))
        
        dispatch_async(dispatch_get_main_queue(), {
            do {
                var widthSoFar = 0
                var i = 0
                while CGFloat(widthSoFar) < totalWidth {
                    let seconds = totalTime * Double(CGFloat(widthSoFar) / totalWidth)
                    let time = CMTime(seconds: seconds, preferredTimescale: 6000)
                    let image = UIImage(CGImage: try generator.copyCGImageAtTime(time, actualTime: nil), scale: 1, orientation: self.delegate!.orientation!)
                    let thisWidth = min(Int(Int(totalWidth) - widthSoFar), width)
                    let imageView = UIImageView(frame: CGRect(x: i * width, y: 0, width: thisWidth, height: height))
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
            
            completionHandler()
        })
    }
    
    func setBounds() {
        self.leftHandle.rightBound = (self.scrubberView.bounds.width - self.centerHandle.frame.width) / 2
        self.rightHandle.leftBound = (self.scrubberView.bounds.width + self.centerHandle.frame.width) / 2
        self.centerHandle.leftBound = self.leftHandle.frame.width
        self.centerHandle.rightBound = self.scrubberView.bounds.width - self.rightHandle.frame.width
    }

    func tearDown() {
        self.thumbnailView.subviews.forEach({ $0.removeFromSuperview() })
        self.leftHandle.clearHandlers()
        self.rightHandle.clearHandlers()
        self.centerHandle.clearHandlers()
    }

    @IBAction func muteTap(sender: UIButton?) {
        self.delegate?.editInformation.muted = !self.delegate!.editInformation.muted
        if self.delegate!.editInformation.muted {
            self.muteButton.setTitle("Unmute", forState: .Normal)
        } else {
            self.muteButton.setTitle("Mute", forState: .Normal)
        }
        updateSavable()
    }

    @IBAction func resetTap(sender: AnyObject) {
        delegate!.editInformation.reset()
        UIView.animateWithDuration(0.2, delay: 0, options: .CurveEaseInOut, animations: {
            self.centerHandle.frame.origin.x = (self.scrubberView.bounds.width - self.centerHandle.frame.width) / 2
            self.leftHandle.frame.origin.x = 0
            self.rightHandle.frame.origin.x = self.scrubberView.bounds.width - self.rightHandle.frame.width
            let m = self.rightHandle.frame.midX
            self.rightCropOverlay.frame.origin.x = m
            self.rightCropOverlay.frame.size.width = self.scrubberView.bounds.width - m
            self.leftCropOverlay.frame.size.width = self.leftHandle.frame.midX
        }) { finished in
            self.muteButton.setTitle("Mute", forState: .Normal)
            self.setBounds()
            self.updateSavable()
        }
    }
}

protocol VideoEditorControlsDelegate {
    var editInformation: EditInformation { get set }
    
    var videoURL: NSURL? { get set }
    var orientation: UIImageOrientation? { get set }
    var frameRatio: CGFloat?  { get set }
    
    func imageUpdated(image: UIImage)
    func scrubbingStarted(handle: VideoEditorHandle)
    func scrubbingEnded(handle: VideoEditorHandle)
    
    func becameSavable()
    func becameUnsavable()
}