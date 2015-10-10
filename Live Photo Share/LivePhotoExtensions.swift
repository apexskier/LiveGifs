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

func livePhotoToGif(movieFile movieFile: PHAssetResource, jpegFile: PHAssetResource, progressHandler: (Double) -> Void, completionHandler: (NSURL, NSError?) -> Void) {
    let fileManager = NSFileManager.defaultManager()
    let resourceManager = PHAssetResourceManager.defaultManager()

    let movFilename: NSString = movieFile.originalFilename
    let gifFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString("\(movFilename.stringByDeletingPathExtension).gif"))
    /*if fileManager.fileExistsAtPath(gifFileUrl.path!) {
        progressHandler(1)
        return completionHandler(gifFileUrl, nil)
    }*/
    do { try fileManager.removeItemAtURL(gifFileUrl) }
    catch {}

    // get the image
    let jpegResourceOptions = PHAssetResourceRequestOptions()
    jpegResourceOptions.networkAccessAllowed = true
    jpegResourceOptions.progressHandler = { (progress: Double) in
        progressHandler(progress / 4)
    }
    let jpegFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(jpegFile.originalFilename))
    // delete any old files
    do { try fileManager.removeItemAtURL(jpegFileUrl) }
    catch {}

    resourceManager.writeDataForAssetResource(jpegFile, toFile: jpegFileUrl, options: jpegResourceOptions, completionHandler: { (error: NSError?) -> Void in
        if error != nil {
            print(error?.usefulDescription)
            return completionHandler(NSURL(), error)
        }
        let liveImageJpeg = UIImage(contentsOfFile: jpegFileUrl.path!)!
        let orientation = liveImageJpeg.imageOrientation

        let movResourceOptions = PHAssetResourceRequestOptions()
        movResourceOptions.networkAccessAllowed = true
        movResourceOptions.progressHandler = { (progress: Double) in
            progressHandler(progress / 4 + 0.25)
        }
        let movFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(movieFile.originalFilename))
        // delete any old files
        do { try fileManager.removeItemAtURL(movFileUrl) }
        catch {}
        resourceManager.writeDataForAssetResource(movieFile, toFile: movFileUrl, options: movResourceOptions, completionHandler: { (error: NSError?) -> Void in
            if error != nil {
                print(error?.usefulDescription)
                return completionHandler(NSURL(), error)
            }

            let movAsset = AVAsset(URL: movFileUrl)
            let videoTrack = movAsset.tracks[0]
            let frameRate = videoTrack.nominalFrameRate
            let frameCount = frameRate * Float(movAsset.duration.seconds)
            let videoSize = videoTrack.naturalSize

            var times: [CMTime] = []
            for i in 1...Int(frameCount) {
                times.append(CMTime(seconds: Double(i) / Double(frameRate), preferredTimescale: 6000))
            }
            let lastTime = times[times.count - 1]

            var exif: NSDictionary?
            if let imageSource = CGImageSourceCreateWithURL(jpegFileUrl, nil), propertiesCF = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) {
                let properties = propertiesCF as NSDictionary
                exif = properties[kCGImagePropertyExifDictionary as NSString] as? NSDictionary
            }

            let destination = CGImageDestinationCreateWithURL(gifFileUrl, kUTTypeGIF, Int(frameCount), nil)
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
            CGImageDestinationSetProperties(destination!, gifProperties)

            let generator = AVAssetImageGenerator(asset: movAsset)
            generator.requestedTimeToleranceAfter = kCMTimeZero
            generator.requestedTimeToleranceBefore = kCMTimeZero

            // let scale = max(targetDimensions.height / videoSize.height, targetDimensions.width / videoSize.width)
            let scale: CGFloat = 0.3
            print("got scale \(scale)")
            let newSize = { (o: UIImageOrientation) -> CGSize in
                if o == .Right || o == .Left {
                    return CGSize(width: videoSize.height * scale, height: videoSize.width * scale)
                } else {
                    return CGSize(width: videoSize.width * scale, height: videoSize.height * scale)
                }
            }(orientation)
            let drawRect = CGRect(x: 0, y: 0, width: videoSize.width * scale, height: videoSize.height * scale)
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
                    progressHandler((time.seconds / lastTime.seconds) / 2 + 0.5)
                } catch let error as NSError {
                    print(error.usefulDescription)
                    return completionHandler(NSURL(), error)
                }
            }
            UIGraphicsEndImageContext()

            CGImageDestinationSetProperties(destination!, gifProperties)
            CGImageDestinationFinalize(destination!)
            progressHandler(1)
            completionHandler(gifFileUrl, nil)
        })
    })
}

func livePhotoToMovie(movieFile movieFile: PHAssetResource, progressHandler: (Double) -> Void, completionHandler: (NSURL, NSError?) -> Void) {
    let fileManager = NSFileManager.defaultManager()
    let resourceManager = PHAssetResourceManager.defaultManager()

    let movFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(movieFile.originalFilename))
    /*if fileManager.fileExistsAtPath(movFileUrl.path!) {
        progressHandler(1)
        return completionHandler(movFileUrl, nil)
    }*/
    // delete any old files
    do { try fileManager.removeItemAtURL(movFileUrl) }
    catch {}

    let movResourceOptions = PHAssetResourceRequestOptions()
    movResourceOptions.networkAccessAllowed = true
    movResourceOptions.progressHandler = { (progress: Double) in
        progressHandler(progress / 2)
    }
    resourceManager.writeDataForAssetResource(movieFile, toFile: movFileUrl, options: movResourceOptions, completionHandler: { (error: NSError?) -> Void in
        if error != nil {
            print(error?.usefulDescription)
            return completionHandler(NSURL(), error)
        }
        progressHandler(1)
        completionHandler(movFileUrl, nil)
    })
}

func livePhotoToSilentMovie(movieFile movieFile: PHAssetResource, progressHandler: (Double) -> Void, completionHandler: (NSURL, NSError?) -> Void) {
    let fileManager = NSFileManager.defaultManager()
    let resourceManager = PHAssetResourceManager.defaultManager()

    let silentMovFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString("silent_\(movieFile.originalFilename)"))
    // delete any old files
    do { try fileManager.removeItemAtURL(silentMovFileUrl) }
    catch {}

    let movFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(movieFile.originalFilename))
    // delete any old files
    do { try fileManager.removeItemAtURL(movFileUrl) }
    catch {}

    let movResourceOptions = PHAssetResourceRequestOptions()
    movResourceOptions.networkAccessAllowed = true
    movResourceOptions.progressHandler = { (progress: Double) in
        progressHandler(progress / 2)
    }
    resourceManager.writeDataForAssetResource(movieFile, toFile: movFileUrl, options: movResourceOptions, completionHandler: { (error: NSError?) -> Void in
        if error != nil {
            print(error?.usefulDescription)
            return completionHandler(NSURL(), error)
        }

        let movAsset = AVAsset(URL: movFileUrl)
        let numTracks = Double(movAsset.tracks.count)
        var count = Double(0)
        let movAssetEditable = AVMutableComposition()
        let movAssetEditableVideoTrack = movAssetEditable.addMutableTrackWithMediaType(AVMediaTypeVideo, preferredTrackID: kCMPersistentTrackID_Invalid)
        for track in movAsset.tracksWithMediaType(AVMediaTypeVideo) {
            do {
                try movAssetEditableVideoTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: track.timeRange.duration), ofTrack: track, atTime: kCMTimeZero)
                movAssetEditableVideoTrack.preferredTransform = track.preferredTransform
            } catch {
                print("something went wrong")
            }
            progressHandler((count / numTracks) + 0.5)
            count++
        }
        let movAssetEditableMetadataTrack = movAssetEditable.addMutableTrackWithMediaType(AVMediaTypeMetadata, preferredTrackID: kCMPersistentTrackID_Invalid)
        for track in movAsset.tracksWithMediaType(AVMediaTypeMetadata) {
            do {
                try movAssetEditableMetadataTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: track.timeRange.duration), ofTrack: track, atTime: kCMTimeZero)
            } catch {
                print("something went wrong")
            }
            progressHandler((count / numTracks) + 0.5)
            count++
        }
        let movAssetEditableTimecodeTrack = movAssetEditable.addMutableTrackWithMediaType(AVMediaTypeTimecode, preferredTrackID: kCMPersistentTrackID_Invalid)
        for track in movAsset.tracksWithMediaType(AVMediaTypeTimecode) {
            do {
                try movAssetEditableTimecodeTrack.insertTimeRange(CMTimeRange(start: kCMTimeZero, duration: track.timeRange.duration), ofTrack: track, atTime: kCMTimeZero)
            } catch {
                print("something went wrong")
            }
            progressHandler((count / numTracks) + 0.5)
            count++
        }

        let exportSession = AVAssetExportSession(asset: movAssetEditable, presetName: AVAssetExportPresetHighestQuality)!
        exportSession.outputURL = silentMovFileUrl
        exportSession.outputFileType = movieFile.uniformTypeIdentifier
        exportSession.metadata = movAsset.metadata
        exportSession.exportAsynchronouslyWithCompletionHandler({
            progressHandler(1)
            completionHandler(silentMovFileUrl, nil)
        })
    })
}
