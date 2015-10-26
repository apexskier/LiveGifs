//
//  MovieEditing.swift
//  Live Photo Share
//
//  Created by Cameron Little on 10/24/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit
import MobileCoreServices

func orientationFromTransform(transform: CGAffineTransform) -> (orientation: UIImageOrientation, isPortrait: Bool) {
    var assetOrientation = UIImageOrientation.Up
    var isPortrait = false
    if transform.a == 0 && transform.b == 1.0 && transform.c == -1.0 && transform.d == 0 {
        assetOrientation = .Right
        isPortrait = true
    } else if transform.a == 0 && transform.b == -1.0 && transform.c == 1.0 && transform.d == 0 {
        assetOrientation = .Left
        isPortrait = true
    } else if transform.a == 1.0 && transform.b == 0 && transform.c == 0 && transform.d == 1.0 {
        assetOrientation = .Up
    } else if transform.a == -1.0 && transform.b == 0 && transform.c == 0 && transform.d == -1.0 {
        assetOrientation = .Down
    }
    return (assetOrientation, isPortrait)
}

func videoCompositionInstructionForTrack(track: AVCompositionTrack, asset: AVAsset, size: CGSize) -> AVMutableVideoCompositionLayerInstruction {
    let instruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
    let assetTrack = asset.tracksWithMediaType(AVMediaTypeVideo)[0]
    
    let transform = assetTrack.preferredTransform
    let assetInfo = orientationFromTransform(transform)
    print(transform)
    print("isPortrait:  \(assetInfo.isPortrait)")
    let orString = { () -> String in
        switch assetInfo.orientation {
        case .Up:
            return "Up"
        case .Down:
            return "Down"
        case .Left:
            return "Left"
        case .Right:
            return "Right"
        default:
            return "Other"
        }
    }()
    print("orientation: \(orString)")

    var scaleToFitRatio = size.width / assetTrack.naturalSize.width
    var newTransform: CGAffineTransform
    if assetInfo.isPortrait {
        scaleToFitRatio = size.width / assetTrack.naturalSize.height
        newTransform = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio)
    } else {
        let scaleFactor = CGAffineTransformMakeScale(scaleToFitRatio, scaleToFitRatio)
        newTransform = scaleFactor
        /*var concat = CGAffineTransformConcat(CGAffineTransformConcat(assetTrack.preferredTransform, scaleFactor), CGAffineTransformMakeTranslation(0, size.width / 2))
        if assetInfo.orientation == .Down {
            let fixUpsideDown = CGAffineTransformMakeRotation(CGFloat(M_PI))
            let yFix = assetTrack.naturalSize.height + size.height
            let centerFix = CGAffineTransformMakeTranslation(assetTrack.naturalSize.width, yFix)
            concat = CGAffineTransformConcat(CGAffineTransformConcat(fixUpsideDown, centerFix), scaleFactor)
        }*/
        //instruction.setTransform(concat, atTime: kCMTimeZero)
    }
    instruction.setTransform(newTransform, atTime: kCMTimeZero)
    return instruction
}

func stdMovToLivephotoMov(assetID: String, movAsset: AVAsset, editInfo: EditInformation, progressHandler: (Double -> Void), completionHandler: ((NSURL, NSError?) -> Void)) {
    // 1 - Create AVMutableComposition object. This object will hold your AVMutableCompositionTrack instances.
    let mixComposition = AVMutableComposition()
    
    let refVideoAsset = AVAsset(URL: NSURL(fileURLWithPath: NSBundle.mainBundle().pathForResource("REFVIDEO", ofType: "MOV")!))
    
    // 2 - Create video track
    let movVideoTrack = movAsset.tracksWithMediaType(AVMediaTypeVideo).first
    if movVideoTrack == nil {
        return completionHandler(NSURL(), NSError(domain: "Video file invalid.", code: 1, userInfo: nil))
    }
    let duration = { () -> CMTime in
        let d = movAsset.duration
        if d.seconds > 3 {
            return CMTime(seconds: 3, preferredTimescale: 6000)
        }
        return d
    }()
    if duration.seconds < 2 {
        return completionHandler(NSURL(), NSError(domain: "Video too short", code: 1, userInfo: nil))
    }

    progressHandler(1/7)
    
    let preferredSize = CGSize(width: 1440, height: 1080)
    var size = movVideoTrack!.naturalSize
    let maxDimension = max(size.height, size.width)
    let minDimension = min(size.height, size.width)
    var scale: CGFloat
    if maxDimension / minDimension < preferredSize.width / preferredSize.height {
        scale = preferredSize.height / minDimension
    } else {
        scale = preferredSize.width / maxDimension
    }
    size = CGSize(width: size.width * scale, height: size.height * scale)
    
    let movTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
    
    // let timeRange = CMTimeRange(start: kCMTimeZero, duration: duration)
    let targetMiddleSeconds = (movAsset.duration.seconds * editInfo.centerImage)
    let targetStartSeconds = max(targetMiddleSeconds - (duration.seconds / 2), 0)
    let start = CMTime(seconds: targetStartSeconds, preferredTimescale: 6000)
    var movTimeRange: CMTimeRange
    
    print("clip duration: \(duration.seconds)")
    print("original duration: \(movAsset.duration.seconds)")
    print("start: \(start.seconds)")
    
    if (movAsset.duration - (start + duration)).seconds < 0 {
        movTimeRange = CMTimeRange(start: movAsset.duration - duration, end: movAsset.duration)
        print("newStart: \((movAsset.duration - duration).seconds)")
    } else {
        movTimeRange = CMTimeRange(start: start, duration: duration)
    }
    let timeRange = CMTimeRange(start: kCMTimeZero, duration: duration)
    print(movTimeRange.start.seconds)
    print(movTimeRange.end.seconds)
    
    do {
        try movTrack.insertTimeRange(movTimeRange, ofTrack: movVideoTrack!, atTime: kCMTimeZero)
    } catch {
        return completionHandler(NSURL(), NSError(domain: "Failed to generate video.", code: 1, userInfo: nil))
    }
    
    progressHandler(2/7)
    
    let mainInstruction = AVMutableVideoCompositionInstruction()
    mainInstruction.timeRange = timeRange
    
    let firstInstruction = videoCompositionInstructionForTrack(movTrack, asset: movAsset, size: size)
    
    mainInstruction.layerInstructions = [firstInstruction]
    let mainComposition = AVMutableVideoComposition()
    mainComposition.instructions = [mainInstruction]
    let fps = min(Int32(movVideoTrack?.nominalFrameRate ?? 14.0), 14)
    mainComposition.frameDuration = CMTimeMake(1, fps)
    mainComposition.renderSize = size
    
    // 3 - Audio track
    if let movAudioTrack = movAsset.tracksWithMediaType(AVMediaTypeAudio).first {
        let audioTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeAudio, preferredTrackID: 0)
        do {
            try audioTrack.insertTimeRange(movTimeRange, ofTrack: movAudioTrack, atTime: kCMTimeZero)
        } catch {
            return completionHandler(NSURL(), NSError(domain: "Failed to generate audio.", code: 1, userInfo: nil))
        }
    }
    
    progressHandler(3/7)
    
    if let refMetadataTrack = refVideoAsset.tracksWithMediaType(AVMediaTypeMetadata).first {
        let metadataTrack = mixComposition.addMutableTrackWithMediaType(AVMediaTypeMetadata, preferredTrackID: 0)
        do {
            try metadataTrack.insertTimeRange(movTimeRange, ofTrack: refMetadataTrack, atTime: kCMTimeZero)
        } catch {
            return completionHandler(NSURL(), NSError(domain: "Failed to generate metadata.", code: 1, userInfo: nil))
        }
    }
    
    progressHandler(4/7)

    // 4 - Get path
    let dateFormatter = NSDateFormatter()
    dateFormatter.dateStyle = .LongStyle
    dateFormatter.timeStyle = .ShortStyle
    let savePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("\(assetID).MOV")
    let url = NSURL(fileURLWithPath: savePath)

    progressHandler(5/7)

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
    let idMeta = AVMutableMetadataItem()
    idMeta.identifier = AVMetadataIdentifierQuickTimeMetadataContentIdentifier
    idMeta.key = AVMetadataQuickTimeMetadataKeyContentIdentifier
    idMeta.keySpace = AVMetadataKeySpaceQuickTimeMetadata
    idMeta.dataType = "com.apple.metadata.datatype.UTF-8"
    idMeta.value = NSUUID().UUIDString
    idMeta.extraAttributes = [
        "dataType": 1,
        "dataTypeNamespace": "com.apple.quicktime.mdta"
    ]
    let dateMeta = AVMutableMetadataItem()
    dateMeta.identifier = AVMetadataIdentifierQuickTimeMetadataCreationDate
    dateMeta.key = AVMetadataQuickTimeMetadataKeyCreationDate
    dateMeta.keySpace = AVMetadataKeySpaceQuickTimeMetadata
    dateMeta.dataType = "com.apple.metadata.datatype.UTF-8"
    let enUSPosixLocale = NSLocale(localeIdentifier: "en_US_POSIX")
    dateFormatter.locale = enUSPosixLocale
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    dateMeta.value = dateFormatter.stringFromDate(NSDate())
    dateMeta.extraAttributes = [
        "dataType": 1,
        "dataTypeNamespace": "com.apple.quicktime.mdta"
    ]
    let stillImageMeta = AVMutableMetadataItem()
    let kKeyStillImageTime = "com.apple.quicktime.still-image-time"
    let kKeySpaceQuickTimeMetadata = "mdta"
    stillImageMeta.key = kKeyStillImageTime
    stillImageMeta.keySpace = kKeySpaceQuickTimeMetadata
    stillImageMeta.value = "30"
    stillImageMeta.dataType = "com.apple.metadata.datatype.int8"
    dateMeta.extraAttributes = [
        "dataType": 1,
        "dataTypeNamespace": "com.apple.quicktime.mdta"
    ]
    
    exporter.metadata = [idMeta, dateMeta] //, stillImageMeta]
    // print(exporter.metadata)
    progressHandler(6/7)

    // 6 - Perform the Export
    exporter.exportAsynchronouslyWithCompletionHandler() {
        guard exporter.status == .Completed else {
            return completionHandler(url, NSError(domain: "Failed to export video", code: 1, userInfo: nil))
        }
        progressHandler(7/7)
        completionHandler(url, nil)
    }
}
