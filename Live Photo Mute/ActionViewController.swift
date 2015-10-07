//
//  ActionViewController.swift
//  Live Photo Mute
//
//  Created by Cameron Little on 10/5/15.
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

    func loadLivePhotoAsset(livePhotoURL: NSURL) -> PHAsset? {
        if let imageSource = CGImageSourceCreateWithURL(livePhotoURL, nil), propertiesCF = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) {
            let properties = propertiesCF as NSDictionary
            if let exif = properties[kCGImagePropertyExifDictionary as NSString] as? NSDictionary, dateTaken = exif[kCGImagePropertyExifDateTimeOriginal as NSString] as? NSString {
                print(dateTaken)

                let dateFormatter = NSDateFormatter()
                dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                let date = dateFormatter.dateFromString(dateTaken as String)!

                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                options.predicate = NSPredicate(format: "mediaSubtype = %i && creationDate >= %@ && creationDate <= %@", PHAssetMediaSubtype.PhotoLive.rawValue, date, date)
                options.fetchLimit = 1
                if let asset = PHAsset.fetchAssetsWithOptions(options).firstObject as? PHAsset {
                    print(asset.creationDate!)
                    return asset
                }
            }
        }
        textUIThread = "Something went wrong."
        error = NSError(domain: "Something went wrong.", code: 1, userInfo: nil)
        return nil
    }

    func loadLivePhotoURL(completionHandler: (livePhotoURL: NSURL) -> Void) {
        // Do not call super in an Action extension with no user interface
        let context = self.extensionContext!

        // Find the item containing the results from the JavaScript preprocessing.
        for item: AnyObject in context.inputItems {
            if let extItem = item as? NSExtensionItem, attachments = extItem.attachments {
                for itemProvider: AnyObject in attachments {
                    //if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeLivePhoto as String) {
                    //let loadOptions = [NSItemProviderPreferredImageSizeKey: NSValue(CGSize: CGSize(width: 200, height: 200))]
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

        let fileManager = NSFileManager.defaultManager()
        let assetResourceManager = PHAssetResourceManager.defaultManager()

        let jpegFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(jpegFile!.originalFilename))
        // delete any old files
        do { try fileManager.removeItemAtURL(jpegFileUrl) }
        catch {}

        let movieFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(movieFile!.originalFilename))
        // delete any old files
        do { try fileManager.removeItemAtURL(movieFileUrl) }
        catch {}

        let writeOptions = PHAssetResourceRequestOptions()
        writeOptions.networkAccessAllowed = true

        livePhotoToSilentMovie(movieFile: movieFile!, progressHandler: { progress in
            dispatch_async(dispatch_get_main_queue(), {
                print("progress --> \(progress)")
                self.progressBar.setProgress(Float(progress), animated: true)
            })
        }) { newMovieFileUrl, error in
            if error != nil {
                self.textUIThread = error?.usefulDescription
                self.error = error
            } else {
                assetResourceManager.writeDataForAssetResource(jpegFile!, toFile: jpegFileUrl, options: writeOptions) { error in
                    if error != nil {
                        self.textUIThread = error?.usefulDescription
                        self.error = error
                    } else {
                        PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                            let request = PHAssetCreationRequest.creationRequestForAsset()

                            // These types should be inferred from your files
                            let photoOptions = PHAssetResourceCreationOptions()
                            photoOptions.uniformTypeIdentifier = jpegFile?.uniformTypeIdentifier
                            request.addResourceWithType(.Photo, fileURL: jpegFileUrl, options: photoOptions)

                            let videoOptions = PHAssetResourceCreationOptions()
                            videoOptions.uniformTypeIdentifier = movieFile?.uniformTypeIdentifier
                            request.addResourceWithType(.PairedVideo, fileURL: newMovieFileUrl, options: videoOptions)
                        }, completionHandler: { (success: Bool, error: NSError?) -> Void in
                            if error != nil {
                                self.textUIThread = error?.usefulDescription
                                self.error = error
                            } else if success {
                                self.textUIThread = "Done!"
                                self.error = nil
                            } else {
                                self.textUIThread = "Failed to save file."
                                self.error = NSError(domain: "Failed to save file.", code: 1, userInfo: nil)
                            }
                        })
                    }
                }
            }
        }
    }
    
}