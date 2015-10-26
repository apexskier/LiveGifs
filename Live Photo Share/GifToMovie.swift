//
//  GifToMovie.swift
//  Live Photo Share
//
//  Created by Cameron Little on 10/25/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import MobileCoreServices
import ImageIO

func gifToMov(source: CGImageSource, progressHandler: (Double -> Void), completionHandler: ((NSURL, NSError?) -> Void)) {
    // 1 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
    let mixComposition = AVMutableComposition()
    
    let numFrames = CGImageSourceGetCount(source)
    var durationSeconds: Double = 0
    var images: [CGImage] = []
    var imageTimes: [Double] = []
    for i in 0...(numFrames - 1) {
        var delay: Double = -1
        if let frameProperties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) {
            if let gifFrameProperties = (frameProperties as NSDictionary).valueForKey(kCGImagePropertyGIFDictionary as String) {
                if let d = ((gifFrameProperties as! CFDictionary) as NSDictionary).valueForKey(kCGImagePropertyGIFDelayTime as String) as? Double {
                    delay = d
                }
            }
            print(delay)
        }
        if delay < 0 {
            delay = 1 / 15
            print("default delay")
        }
        if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
            images.append(image)
            imageTimes.append(durationSeconds)
        }
        durationSeconds += delay
    }
    var keyTimes: [Double] = []
    for time in imageTimes {
        keyTimes.append(time / durationSeconds)
    }
    print(keyTimes)
    
    print("gif seconds: \(durationSeconds)")
    
    let animation = CAKeyframeAnimation(keyPath: "contents")
    animation.duration = CFTimeInterval(durationSeconds)
    animation.repeatCount = 1
    animation.removedOnCompletion = false
    animation.fillMode = kCAFillModeForwards
    animation.values = images
    animation.keyTimes = keyTimes
    animation.beginTime = AVCoreAnimationBeginTimeAtZero
    animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
    animation.calculationMode = kCAAnimationDiscrete
    
    let duration = CMTime(seconds: durationSeconds, preferredTimescale: 6000)
    if duration.seconds < 2 {
        return completionHandler(NSURL(), NSError(domain: "GIF too short.", code: 1, userInfo: nil))
    }
    let timeRange = CMTimeRange(start: kCMTimeZero, duration: duration)
    
    var size: CGSize
    if let frameProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) {
        let framePropertiesDict = frameProperties as NSDictionary
        let width = framePropertiesDict.valueForKey(kCGImagePropertyPixelWidth as String) as? Double
        let height = framePropertiesDict.valueForKey(kCGImagePropertyPixelHeight as String) as? Double
        size = CGSize(width: width!, height: height!)
    } else {
        size = CGSize(width: 1440, height: 1080)
    }
    
    print("GIF size: \(size)")
    
    // 2 - Create video track
    let refVideoAsset = AVAsset(URL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("REFVIDEO", ofType: "MOV")!))
    let movVideoTrack = refVideoAsset.tracksWithMediaType(AVMediaTypeVideo).first
    if movVideoTrack == nil {
        return completionHandler(NSURL(), NSError(domain: "Video file invalid.", code: 1, userInfo: nil))
    }
    let movTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
    do {
        try movTrack.insertTimeRange(timeRange, ofTrack: movVideoTrack!, atTime: kCMTimeZero)
    } catch {
        return completionHandler(NSURL(), NSError(domain: "Failed to generate video.", code: 1, userInfo: nil))
    }
    
    let mainInstruction = AVMutableVideoCompositionInstruction()
    mainInstruction.timeRange = timeRange
    
    let firstInstruction = videoCompositionInstructionForTrack(movTrack, asset: refVideoAsset, size: size)
    
    mainInstruction.layerInstructions = [firstInstruction]
    let mainComposition = AVMutableVideoComposition()
    
    // Set up gif as an animation
    let animationLayer = CALayer()
    animationLayer.frame = CGRect(x: 0, y: 0, width: size.width, height: size.height)
    animationLayer.addAnimation(animation, forKey: "contents")
    let parentLayer = CALayer()
    let videoLayer = CALayer()
    parentLayer.frame = CGRectMake(0, 0, size.width, size.height);
    videoLayer.frame = CGRectMake(0, 0, size.width, size.height);
    parentLayer.addSublayer(videoLayer)
    parentLayer.addSublayer(animationLayer)
    
    let animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videoLayer, inLayer: parentLayer)
    
    mainComposition.animationTool = animationTool
    
    mainComposition.frameDuration = CMTime(seconds: 1/60, preferredTimescale: 6000)
    mainComposition.renderSize = size
    print(mainComposition.renderSize)
    mainComposition.instructions = [mainInstruction]
    
    // 4 - Get path
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateStyle = .LongStyle
    dateFormatter.timeStyle = .ShortStyle
    let savePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("\(NSDate()).MOV")
    let url = NSURL(fileURLWithPath: savePath)
    
    // 5 - Create Exporter
    let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality)!
    exporter.outputURL = url
    exporter.outputFileType = AVFileTypeQuickTimeMovie // AVFileTypeMPEG4
    exporter.shouldOptimizeForNetworkUse = true
    exporter.videoComposition = mainComposition
    let authorMeta = AVMutableMetadataItem()
    authorMeta.identifier = AVMetadataCommonIdentifierAuthor
    authorMeta.key = AVMetadataQuickTimeMetadataKeyAuthor
    authorMeta.keySpace = AVMetadataKeySpaceCommon
    authorMeta.value = NSBundle.mainBundle().bundleIdentifier!
    
    exporter.metadata = [authorMeta]
    
    // 6 - Perform the Export
    exporter.exportAsynchronouslyWithCompletionHandler() {
        guard exporter.status == .Completed else {
            return completionHandler(url, NSError(domain: "Failed to export video", code: 1, userInfo: nil))
        }
        completionHandler(url, nil)
    }
}