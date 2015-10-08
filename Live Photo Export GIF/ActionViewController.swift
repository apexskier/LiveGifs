//
//  ActionViewController.swift
//  Live Photo Export GIF
//
//  Created by Cameron Little on 10/6/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import UIKit
import Photos
import ImageIO
import MobileCoreServices

class ActionViewController: UIViewController {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!

    var error: NSError?
    var results: AnyObject?

    override func viewDidLoad() {
        super.viewDidLoad()

        progressBar.progress = 0
    }

    var textUIThread: String? {
        get {
            return self.label.text
        }
        set (value) {
            dispatch_async(dispatch_get_main_queue(), {
                self.label.text = value
            })
        }
    }

    override func viewDidAppear(animated: Bool) {
        loadLivePhotoURL { livePhotoURL in
            if let livePhotoAsset = self.loadLivePhotoAsset(livePhotoURL) {
                self.mainWork(livePhotoURL, livePhotoAsset: livePhotoAsset)
            } else {
                self.textUIThread = "Failed to load Live Photo."
                self.error = NSError(domain: "Failed to load asset.", code: 1, userInfo: nil)
            }
        }
    }

    func loadLivePhotoURL(completionHandler: (livePhotoURL: NSURL) -> Void) {
        // Do not call super in an Action extension with no user interface
        let context = self.extensionContext!

        // Find the item containing the results from the JavaScript preprocessing.
        for item: AnyObject in context.inputItems {
            if let extItem = item as? NSExtensionItem, attachments = extItem.attachments {
                for itemProvider: AnyObject in attachments {
                    /*if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeLivePhoto as String) {
                        itemProvider.loadItemForTypeIdentifier(kUTTypeLivePhoto as String, options: nil, completionHandler: { (item, error) in
                            print("live photo:")
                            print(item)
                            print(error.usefulDescription)
                        })
                    }*/
                    if !itemProvider.hasItemConformingToTypeIdentifier(kUTTypeLivePhoto as String) {
                        self.textUIThread = "No Live Photo associated with this image."
                        self.error = NSError(domain: "No Live Photo associated with this image.", code: 1, userInfo: nil)
                    } else if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                        itemProvider.loadItemForTypeIdentifier(kUTTypeImage as String, options: nil, completionHandler: { (item, error) in
                            if error != nil {
                                self.textUIThread = error.usefulDescription
                                self.error = error
                            } else if let livePhotoURL = item as? NSURL {
                                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                                    completionHandler(livePhotoURL: livePhotoURL)
                                })
                            }
                        })
                    }
                }
            }
        }
    }

    func loadLivePhotoAsset(livePhotoURL: NSURL) -> PHAsset? {
        if let imageSource = CGImageSourceCreateWithURL(livePhotoURL, nil), propertiesCF = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) {
            let properties = propertiesCF as NSDictionary
            if let exif = properties[kCGImagePropertyExifDictionary as NSString] as? NSDictionary, dateTaken = exif[kCGImagePropertyExifDateTimeOriginal as NSString] as? NSString, subsecTime = exif[kCGImagePropertyExifSubsecTimeOrginal as NSString] as? NSString {
                let dateFormatter = NSDateFormatter()
                let dateFormat = "yyyy:MM:dd HH:mm:ss.S"
                dateFormatter.dateFormat = dateFormat
                let dateStr = "\(dateTaken).\(subsecTime)"
                let date = dateFormatter.dateFromString(dateStr)!
                let datePlus = NSDate(timeInterval: 1, sinceDate: date)
                let dateMinus = NSDate(timeInterval: -1, sinceDate: date)

                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                options.predicate = NSPredicate(format: "mediaSubtype = %i && creationDate <= %@ && creationDate >= %@", PHAssetMediaSubtype.PhotoLive.rawValue, datePlus, dateMinus)
                // options.fetchLimit = 1
                let assets = PHAsset.fetchAssetsWithOptions(options)

                var minAsset: PHAsset?
                var minDiff: NSTimeInterval = 2
                for i in 0...(assets.count - 1) {
                    let asset = assets.objectAtIndex(i) as! PHAsset
                    let diff = abs(date.timeIntervalSinceDate(asset.creationDate!))
                    if diff < minDiff {
                        minDiff = diff
                        minAsset = asset
                    }
                }
                if let asset = minAsset {
                    return asset
                }
            }
        }
        textUIThread = "Something went wrong."
        error = NSError(domain: "Something went wrong.", code: 1, userInfo: nil)
        return nil
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func done() {
        // Return any edited content to the host app.
        // This template doesn't do anything, so we just echo the passed in items.
        if error != nil {
            self.extensionContext?.cancelRequestWithError(self.error!)
        } else {
            self.extensionContext?.completeRequestReturningItems(self.extensionContext!.inputItems, completionHandler: { (expired: Bool) -> Void in
                if expired {
                    print("FAILED")
                } else {
                    print("SUCCEEDED")
                }
            })
        }
    }

    func mainWork(livePhotoURL: NSURL, livePhotoAsset: PHAsset) {
        let resources = PHAssetResource.assetResourcesForAsset(livePhotoAsset)
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

        if let j = jpegFile, m = movieFile {
            print(NSBundle.mainBundle().bundleIdentifier!)
            switch NSBundle.mainBundle().bundleIdentifier! {
            case "com.camlittle.Live-Photo-Share.Live-Photo-Export-GIF":
                generateAndSaveGif(j, movieFile: m)
            case "com.camlittle.Live-Photo-Share.Live-Photo-Export-Video":
                generateAndSaveMovie(j, movieFile: m)
            case "com.camlittle.Live-Photo-Share.Live-Photo-Mute":
                generateAndSaveMuted(j, movieFile: m)
            default:
                self.textUIThread = "This extension's not vailid."
                self.error = NSError(domain: "Invalid bundle identifier.", code: 1, userInfo: nil)
            }
        } else {
            self.textUIThread = "A required file was not found."
            self.error = NSError(domain: "A required file was not found.", code: 1, userInfo: nil)
        }
    }

    func generateAndSaveGif(jpegFile: PHAssetResource, movieFile: PHAssetResource) {
        livePhotoToGif(movieFile: movieFile, jpegFile: jpegFile, progressHandler: { (progress: Double) -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                self.progressBar.setProgress(Float(progress), animated: true)
            })
        }, completionHandler: { (url: NSURL, error: NSError?) in
            if error != nil {
                self.textUIThread = "Failed to create GIF."
                self.error = error
            } else {
                PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                    let request = PHAssetCreationRequest.creationRequestForAsset()

                    // These types should be inferred from your files
                    let photoOptions = PHAssetResourceCreationOptions()
                    photoOptions.uniformTypeIdentifier = kUTTypeGIF as String
                    request.addResourceWithType(.Photo, fileURL: url, options: photoOptions)
                }, completionHandler: self.saveCompletion)
            }
        })
    }

    func generateAndSaveMovie(jpegFile: PHAssetResource, movieFile: PHAssetResource) {
        livePhotoToMovie(movieFile: movieFile, progressHandler: { (progress: Double) -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                self.progressBar.setProgress(Float(progress), animated: true)
            })
        }, completionHandler: { (url: NSURL, error: NSError?) in
            if error != nil {
                self.textUIThread = "Failed to create video file."
                self.error = error
            } else {
                PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
                    PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(url)
                }, completionHandler: self.saveCompletion)
            }
        })
    }

    func generateAndSaveMuted(jpegFile: PHAssetResource, movieFile: PHAssetResource) {
        let fileManager = NSFileManager.defaultManager()
        let assetResourceManager = PHAssetResourceManager.defaultManager()

        // delete any old files
        let jpegFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(jpegFile.originalFilename))
        do { try fileManager.removeItemAtURL(jpegFileUrl) }
        catch {}
        let movieFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(movieFile.originalFilename))
        do { try fileManager.removeItemAtURL(movieFileUrl) }
        catch {}

        livePhotoToSilentMovie(movieFile: movieFile, progressHandler: { progress in
            dispatch_async(dispatch_get_main_queue(), {
                print("progress --> \(progress)")
                self.progressBar.setProgress(Float(progress) / 4 + 0.5, animated: true)
            })
        }) { newMovieFileUrl, error in
            if error != nil {
                self.textUIThread = error?.usefulDescription
                self.error = error
            } else {
                let writeOptions = PHAssetResourceRequestOptions()
                writeOptions.networkAccessAllowed = true
                writeOptions.progressHandler = { progress in
                    dispatch_async(dispatch_get_main_queue(), {
                        print("progress --> \(progress)")
                        self.progressBar.setProgress(Float(progress) / 4 + 0.75, animated: true)
                    })
                }
                assetResourceManager.writeDataForAssetResource(jpegFile, toFile: jpegFileUrl, options: writeOptions) { error in
                    dispatch_async(dispatch_get_main_queue(), {
                        if error != nil {
                            self.textUIThread = error?.usefulDescription
                            self.error = error
                        } else {
                            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                                let request = PHAssetCreationRequest.creationRequestForAsset()

                                // These types should be inferred from your files
                                let photoOptions = PHAssetResourceCreationOptions()
                                photoOptions.uniformTypeIdentifier = jpegFile.uniformTypeIdentifier
                                request.addResourceWithType(.Photo, fileURL: jpegFileUrl, options: photoOptions)

                                let videoOptions = PHAssetResourceCreationOptions()
                                videoOptions.uniformTypeIdentifier = movieFile.uniformTypeIdentifier
                                request.addResourceWithType(.PairedVideo, fileURL: newMovieFileUrl, options: videoOptions)
                            }, completionHandler: self.saveCompletion)
                        }
                    })
                }
            }
        }
    }

    func saveCompletion(success: Bool, error: NSError?) {
        if error != nil {
            self.textUIThread = error?.usefulDescription
            self.error = error
        } else if success {
            self.textUIThread = "Done!"
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), {
                self.done()
            })
            self.error = nil
        } else {
            self.textUIThread = "Failed to save file."
            self.error = NSError(domain: "Failed to save file.", code: 1, userInfo: nil)
        }
    }

}
