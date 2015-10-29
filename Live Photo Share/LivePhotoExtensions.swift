//
//  LivePhotoExtensions.swift
//  LiveGifs
//
//  Created by Cameron Little on 9/28/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import AVFoundation
import Photos
import ImageIO
import MobileCoreServices

let targetDimensions: CGSize = UIScreen.mainScreen().bounds.size

let fileManager = NSFileManager.defaultManager()
let resourceManager = PHAssetResourceManager.defaultManager()

struct EditInformation {
    var _leftBound: Double = 0
    var _rightBound: Double = 1
    var _center: Double = 0.5
    var _muted: Bool = false
    var leftBound: Double {
        get {
            return _leftBound
        }
        set (value) {
            leftDirty = true
            _leftBound = value
        }
    }
    var rightBound: Double {
        get {
            return _rightBound
        }
        set (value) {
            rightDirty = true
            _rightBound = value
        }
    }
    var centerImage: Double {
        get {
            return _center
        }
        set (value) {
            centerDirty = true
            _center = value
        }
    }
    var muted: Bool {
        get {
            return _muted
        }
        set (value) {
            mutedDirty = true
            _muted = value
        }
    }
    var dirty: Bool {
        get {
            return leftDirty || rightDirty || centerDirty || mutedDirty
        }
    }
    var leftDirty = false
    var rightDirty = false
    var centerDirty = false
    var mutedDirty = false
    mutating func reset() {
        leftBound = 0
        rightBound = 1
        centerImage = 0.5
        muted = false
        
        leftDirty = false
        rightDirty = false
        centerDirty = false
        mutedDirty = false
    }
}

func resourcesForLivePhoto(livePhoto: PHLivePhoto) -> (movieFile: PHAssetResource, jpegFile: PHAssetResource, error: NSError?) {
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
        return (PHAssetResource(), PHAssetResource(), NSError(domain: "Files not found", code: 1, userInfo: nil))
    } else {
        return (movieFile!, jpegFile!, nil)
    }
}

func fileForResource(resource: PHAssetResource, progressHandler: Double -> Void, completionHandler: (NSURL, NSError?) -> Void) {
    let filename = resource.originalFilename

    let options = PHAssetResourceRequestOptions()
    options.networkAccessAllowed = true
    options.progressHandler = progressHandler

    let fileURL = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(filename))
    // delete any old files
    do { try fileManager.removeItemAtURL(fileURL) }
    catch {}

    resourceManager.writeDataForAssetResource(resource, toFile: fileURL, options: options, completionHandler: { (error: NSError?) -> Void in
        completionHandler(fileURL, error)
    })
}

func livePhotoToGif(movieFile movieFile: PHAssetResource, jpegFile: PHAssetResource, progressHandler: (Double) -> Void, completionHandler: (NSURL, NSError?) -> Void) {
    // get jpeg file
    fileForResource(jpegFile, progressHandler: { progress in
        progressHandler(progress / 4)
    }) { jpegFileURL, error in
        if error != nil {
            print(error?.usefulDescription)
            return completionHandler(NSURL(), error)
        }
        // get movie file
        fileForResource(movieFile, progressHandler: { progress in
            progressHandler(progress / 4 + 0.25)
        }) { movFileURL, error in
            if error != nil {
                print(error?.usefulDescription)
                return completionHandler(NSURL(), error)
            }

            // get orientation
            let liveImageJpeg = UIImage(contentsOfFile: jpegFileURL.path!)!
            let orientation = liveImageJpeg.imageOrientation

            // set up url to save GIF to
            let movFilename: NSString = movieFile.originalFilename
            let gifFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString("\(movFilename.stringByDeletingPathExtension).gif"))
            do { try fileManager.removeItemAtURL(gifFileUrl) }
            catch {}

            // get movie information
            let movAsset = AVAsset(URL: movFileURL)
            let videoTrack = movAsset.tracks[0]
            let frameRate = min(videoTrack.nominalFrameRate, 15)
            let frameCount = frameRate * Float(movAsset.duration.seconds)
            let videoSize = videoTrack.naturalSize

            // get times to pull frames at
            var times: [CMTime] = []
            for i in 1...Int(frameCount) {
                times.append(CMTime(seconds: Double(i) / Double(frameRate), preferredTimescale: 6000))
            }
            let lastTime = times[times.count - 1]

            // set up gif metadata
            let destination = CGImageDestinationCreateWithURL(gifFileUrl, kUTTypeGIF, Int(frameCount), nil)

            var exif: NSDictionary?
            if let imageSource = CGImageSourceCreateWithURL(jpegFileURL, nil), propertiesCF = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) {
                let properties = propertiesCF as NSDictionary
                exif = properties[kCGImagePropertyExifDictionary as NSString] as? NSDictionary
            }
            let gifProperties: CFDictionaryRef = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFLoopCount as String: 0, // loop forever
                ],
                kCGImagePropertyExifDictionary as String: exif ?? []
            ]

            let frameProperties: CFDictionaryRef = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: 1 / Float(frameRate)
                    // kCGImagePropertyGIFHasGlobalColorMap as String: false
                ]
            ]

            let generator = AVAssetImageGenerator(asset: movAsset)
            generator.requestedTimeToleranceAfter = kCMTimeZero
            generator.requestedTimeToleranceBefore = kCMTimeZero

            // variables for saving frames
            // let scale = max(targetDimensions.height / videoSize.height, targetDimensions.width / videoSize.width)
            let scale: CGFloat = 0.3
            let newSize = { (o: UIImageOrientation) -> CGSize in
                if o == .Right || o == .Left {
                    return CGSize(width: videoSize.height * scale, height: videoSize.width * scale)
                } else {
                    return CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
                }
            }(orientation)
            let drawRect = CGRect(x: 0, y: 0, width: videoSize.width * scale, height: videoSize.height * scale)

            // generate frames and add to GIF
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            let context = UIGraphicsGetCurrentContext()
            if (orientation == .Right) {
                CGContextTranslateCTM(context, 0.5 * newSize.width, 0.5 * newSize.height)
                CGContextRotateCTM(context, 0.5 * CGFloat(M_PI))
                CGContextTranslateCTM(context, -0.5 * newSize.height, -0.5 * newSize.width)
            } else if (orientation == .Left) {
                CGContextTranslateCTM(context, 0.5 * newSize.width, 0.5 * newSize.height)
                CGContextRotateCTM(context, -0.5 * CGFloat(M_PI))
                CGContextTranslateCTM(context, -0.5 * newSize.height, -0.5 * newSize.width)
            } else if (orientation == .Down) {
                CGContextTranslateCTM(context, 0.5 * newSize.width, 0.5 * newSize.height)
                CGContextRotateCTM(context, 1 * CGFloat(M_PI))
                CGContextTranslateCTM(context, -0.5 * newSize.width, -0.5 * newSize.height)
            } else if (orientation == .Up) { }

            for time in times {
                do {
                    var actualTime = CMTime()
                    UIImage(CGImage: try generator.copyCGImageAtTime(time, actualTime: &actualTime)).drawInRect(drawRect)
                    let imageFrame = UIGraphicsGetImageFromCurrentImageContext()
                    CGImageDestinationAddImage(destination!, imageFrame.CGImage!, frameProperties)
                    progressHandler((time.seconds / lastTime.seconds) / 4 + 0.5)
                } catch let error as NSError {
                    print(error.usefulDescription)
                    return completionHandler(NSURL(), error)
                }
            }
            UIGraphicsEndImageContext()

            // Save!
            CGImageDestinationSetProperties(destination!, gifProperties)
            CGImageDestinationFinalize(destination!)
            progressHandler(1)
            completionHandler(gifFileUrl, nil)
        }
    }
}

func livePhotoToMovie(movieFile movieFile: PHAssetResource, progressHandler: (Double) -> Void, completionHandler: (NSURL, NSError?) -> Void) {
    fileForResource(movieFile, progressHandler: progressHandler) { movFileURL, error in
        if error != nil {
            print(error?.usefulDescription)
            return completionHandler(NSURL(), error)
        } else {
            progressHandler(1)
            completionHandler(movFileURL, nil)
        }
    }
}

func livePhotoToSilentMovie(movieFile movieFile: PHAssetResource, progressHandler: (Double) -> Void, completionHandler: (NSURL, NSError?) -> Void) {
    fileForResource(movieFile, progressHandler: { progress in
        progressHandler(progress / 2)
    }) { movFileURL, error in
        if error != nil {
            print(error?.usefulDescription)
            return completionHandler(NSURL(), error)
        }

        let silentMovFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString("silent_\(movieFile.originalFilename)"))
        // delete any old files
        do { try fileManager.removeItemAtURL(silentMovFileUrl) }
        catch {}

        let movAsset = AVAsset(URL: movFileURL)
        
        let numTracks = Double(movAsset.tracks.count)
        var count = Double(0)
        let movAssetEditable = AVMutableComposition()
        for type in [AVMediaTypeVideo, AVMediaTypeMetadata, AVMediaTypeTimecode, AVMediaTypeMetadataObject] {
            let typeTrack = movAssetEditable.addMutableTrackWithMediaType(type, preferredTrackID: kCMPersistentTrackID_Invalid)
            for track in movAsset.tracksWithMediaType(type) {
                do {
                    try typeTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: track.timeRange.duration), ofTrack: track, atTime: kCMTimeZero)
                    typeTrack.preferredTransform = track.preferredTransform
                } catch {
                    return completionHandler(silentMovFileUrl, NSError(domain: "Something went wrong generating video", code: 1, userInfo: nil))
                }
                progressHandler((count++ / numTracks) + 0.5)
            }
        }

        let exportSession = AVAssetExportSession(asset: movAssetEditable, presetName: AVAssetExportPresetHighestQuality)!
        exportSession.outputURL = silentMovFileUrl
        exportSession.outputFileType = movieFile.uniformTypeIdentifier
        exportSession.metadata = movAsset.metadata
        exportSession.exportAsynchronouslyWithCompletionHandler({
            progressHandler(1)
            completionHandler(silentMovFileUrl, nil)
        })
    }
}


func editLivePhoto(movieFile movieFile: PHAssetResource, jpegFile: PHAssetResource, editInfo: EditInformation, progressHandler: (Double) -> Void, completionHandler: (NSError? -> Void)) {
    /*if !editInfo.dirty {
        return completionHandler(NSError(domain: "No edits requested", code: 1, userInfo: nil))
    }
    */
    fileForResource(movieFile, progressHandler: { progress in
        progressHandler(progress / 2)
    }) { movFileURL, error in
        if error != nil {
            print(error?.usefulDescription)
            return completionHandler(error)
        }
        let movAsset = AVAsset(URL: movFileURL)
        editMov(movAsset: movAsset, movURL: movFileURL, editInfo: editInfo, progressHandler: { progress in
            progressHandler(progress / 2)
        }) { (newMovURL, error) in
            if error != nil {
                completionHandler(error)
            } else {
                editImg(jpegResource: jpegFile, movAsset: movAsset, editInfo: editInfo, progressHandler: { progress in
                    progressHandler(progress / 4 + 0.5)
                }) { (newJpegURL, error) in
                    if error != nil {
                        completionHandler(error)
                    } else {
                        saveLivePhoto(movURL: newMovURL, jpegURL: newJpegURL, progressHandler: { progress in
                            progressHandler(progress / 4 + 0.75)
                        }) { error in
                            if error != nil {
                                completionHandler(error)
                            } else {
                                progressHandler(1)
                                completionHandler(nil)
                            }
                        }
                    }
                }
            }
        }
    }
}

internal func saveLivePhoto(movURL movURL: NSURL, jpegURL: NSURL, progressHandler: (Double -> Void), completionHandler: (NSError? -> Void)) {
    let writeOptions = PHAssetResourceRequestOptions()
    writeOptions.networkAccessAllowed = true
    writeOptions.progressHandler = { progress in
        progressHandler(Double(progress / 2))
    }

    PHPhotoLibrary.sharedPhotoLibrary().performChanges({
        let request = PHAssetCreationRequest.creationRequestForAsset()

        // These types should be inferred from your files
        let photoOptions = PHAssetResourceCreationOptions()
        photoOptions.uniformTypeIdentifier = kUTTypeJPEG as String
        request.addResourceWithType(.Photo, fileURL: jpegURL, options: photoOptions)

        let videoOptions = PHAssetResourceCreationOptions()
        videoOptions.uniformTypeIdentifier = kUTTypeQuickTimeMovie as String
        request.addResourceWithType(.PairedVideo, fileURL: movURL, options: videoOptions)
        progressHandler(0.7)
    }, completionHandler: { success, error in
        if error != nil {
            completionHandler(error)
        } else {
            progressHandler(1)
            completionHandler(nil)
        }
    })
}

internal func editImg(jpegResource jpegResource: PHAssetResource, movAsset: AVAsset, editInfo: EditInformation, progressHandler: (Double -> Void), completionHandler: ((NSURL, NSError?) -> Void)) {
    fileForResource(jpegResource, progressHandler: { progress in
        progressHandler(progress / 2)
    }) { (jpegURL, error) in
        if error != nil {
            print(error?.usefulDescription)
            return completionHandler(NSURL(), error)
        }
        if editInfo.centerDirty {
            generateImg(NSUUID().UUIDString, movAsset: movAsset, referenceImgURL: jpegURL, editInfo: editInfo, progressHandler: progressHandler, completionHandler: completionHandler)
        } else {
            progressHandler(1)
            completionHandler(jpegURL, nil)
        }
    }
}

func generateImg(assetID: String, movAsset: AVAsset, referenceImgURL: NSURL?, editInfo: EditInformation, progressHandler: (Double -> Void), completionHandler: ((NSURL, NSError?) -> Void)) {
    // Need to generate new image file
    let generator = AVAssetImageGenerator(asset: movAsset)
    generator.requestedTimeToleranceAfter = kCMTimeZero
    generator.requestedTimeToleranceBefore = kCMTimeZero
    progressHandler(0)
    let seconds = editInfo.centerImage * movAsset.duration.seconds
    let time = CMTime(seconds: seconds, preferredTimescale: 6000)
    
    let orientation: UIImageOrientation = { () -> UIImageOrientation in
        if let assetTrack = movAsset.tracksWithMediaType(AVMediaTypeVideo).first {
            let transform = assetTrack.preferredTransform
            return orientationFromTransform(transform).orientation
        }
        return .Up
    }()
    do {
        let properties = { () -> NSDictionary in
            if referenceImgURL != nil {
                if let imageSource = CGImageSourceCreateWithURL(referenceImgURL!, nil), propertiesCF = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) {
                    return propertiesCF as NSDictionary
                }
            }
            
            let metadata = NSMutableDictionary()
            let makerNote = NSMutableDictionary()
            makerNote.setObject(assetID, forKey: "17")
            metadata.setObject(makerNote, forKey: kCGImagePropertyMakerAppleDictionary as String)
            
            //metadata.setObject(4, forKey: kCGImagePropertyOrientation as String)
            return metadata
        }()
        let url = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString("\(assetID == "" ? NSUUID().UUIDString : assetID).JPG"))
        // delete any old files
        do { try fileManager.removeItemAtURL(url) }
        catch {}
        progressHandler(0.5)
        let imageDest = CGImageDestinationCreateWithURL(url, kUTTypeJPEG, 1, nil)!
        let imageRef = try { () -> CGImage in
            let originalCGImage = try generator.copyCGImageAtTime(time, actualTime: nil)
            if orientation == .Up {
                return originalCGImage
            }
            
            let imageSize = CGSize(width: CGImageGetWidth(originalCGImage), height: CGImageGetHeight(originalCGImage))
            var rotatedSize: CGSize
            if orientation == .Right || orientation == .Left {
                rotatedSize = CGSize(width: imageSize.height, height: imageSize.width)
            } else {
                rotatedSize = imageSize
            }
            
            let rotatedCenterX = rotatedSize.width / 2.0
            let rotatedCenterY = rotatedSize.height / 2.0
            
            UIGraphicsBeginImageContextWithOptions(rotatedSize, false, 1)
            let rotatedContext = UIGraphicsGetCurrentContext()
            if orientation == .Up || orientation == .Down { // 0 or 180 degrees
                CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY)
                if (orientation == .Up) {
                    CGContextScaleCTM(rotatedContext, 1, -1)
                } else {
                    CGContextScaleCTM(rotatedContext, -1, 1)
                }
                CGContextTranslateCTM(rotatedContext, -rotatedCenterX, -rotatedCenterY)
            } else if orientation == .Right || orientation == .Left { // +/- 90 degrees
                CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY)
                if orientation == .Right {
                    CGContextRotateCTM(rotatedContext, CGFloat(M_PI_2))
                } else {
                    CGContextRotateCTM(rotatedContext, CGFloat(-M_PI_2))
                }
                CGContextScaleCTM(rotatedContext, 1, -1)
                CGContextTranslateCTM(rotatedContext, -rotatedCenterY, -rotatedCenterX)
            }
            
            let drawingRect = CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height)
            CGContextDrawImage(rotatedContext, drawingRect, originalCGImage)
            let rotatedCGImage = CGBitmapContextCreateImage(rotatedContext)
            
            UIGraphicsEndImageContext()
            
            return rotatedCGImage!
        }()
        CGImageDestinationAddImage(imageDest, imageRef, properties)
        
        CGImageDestinationFinalize(imageDest)
        completionHandler(url, nil)
    } catch {
        progressHandler(1)
        return completionHandler(NSURL(), NSError(domain: "Failed to capture image frame", code: 1, userInfo: nil))
    }
}

internal func editMov(movAsset movAsset: AVAsset, movURL: NSURL, editInfo: EditInformation, progressHandler: (Double -> Void), completionHandler: ((NSURL, NSError?) -> Void)) {
    if editInfo.mutedDirty || editInfo.leftDirty || editInfo.rightDirty {
        // Need to generate new video file
        let newMovFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString("editmov_\(movURL.lastPathComponent!)"))
        // delete any old files
        do { try fileManager.removeItemAtURL(newMovFileUrl) }
        catch {}

        let numTracks = Double(movAsset.tracks.count)
        var count = Double(0)
        let movAssetEditable = AVMutableComposition()
        var mediaTypes = [AVMediaTypeVideo, AVMediaTypeMetadata, AVMediaTypeTimecode, AVMediaTypeMetadataObject]
        if !editInfo.mutedDirty {
            mediaTypes.append(AVMediaTypeAudio)
        }
        let seconds = movAsset.duration.seconds
        let startTime = editInfo.leftDirty ? CMTime(seconds: editInfo.leftBound * seconds, preferredTimescale: 6000) : kCMTimeZero
        let endTime = editInfo.rightDirty ? CMTime(seconds: editInfo.rightBound * seconds, preferredTimescale: 6000) : movAsset.duration
        let newDuration = { () -> CMTime in
            var d = endTime - startTime
            if d.seconds > 3 {
                d = CMTime(seconds: 3, preferredTimescale: 6000)
            } else if d.seconds < 2 {
                d = CMTime(seconds: 2, preferredTimescale: 6000)
            }
            return d
        }()
        for type in mediaTypes {
            let typeTrack = movAssetEditable.addMutableTrackWithMediaType(type, preferredTrackID: kCMPersistentTrackID_Invalid)
            for track in movAsset.tracksWithMediaType(type) {
                do {
                    try typeTrack.insertTimeRange(CMTimeRange(start: startTime, duration: newDuration), ofTrack: track, atTime: kCMTimeZero)
                    typeTrack.preferredTransform = track.preferredTransform
                } catch {
                    completionHandler(NSURL(), NSError(domain: "Something went wrong encoding the video", code: 1, userInfo: nil))
                }
                progressHandler((count++ / numTracks) + 0.5)
            }
        }

        let exportSession = AVAssetExportSession(asset: movAssetEditable, presetName: AVAssetExportPresetHighestQuality)!
        exportSession.outputURL = newMovFileUrl
        exportSession.outputFileType = kUTTypeQuickTimeMovie as String
        exportSession.metadata = movAsset.metadata
        exportSession.exportAsynchronouslyWithCompletionHandler({
            progressHandler(1)
            completionHandler(newMovFileUrl, nil)
        })
    } else {
        progressHandler(1)
        completionHandler(movURL, nil)
    }
}
