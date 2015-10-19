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

/*
func getResources() {
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
        })
    })
}
*/

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
            let frameRate = videoTrack.nominalFrameRate
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
            CGImageDestinationSetProperties(destination!, gifProperties)

            let generator = AVAssetImageGenerator(asset: movAsset)
            generator.requestedTimeToleranceAfter = kCMTimeZero
            generator.requestedTimeToleranceBefore = kCMTimeZero

            // variables for saving frames
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
                    print("something went wrong")
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
