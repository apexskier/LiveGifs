//
//  ActionRequestHandler.swift
//  Live Photo GIF Action
//
//  Created by Cameron Little on 10/4/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import UIKit
import Photos
import ImageIO
import MobileCoreServices

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {

    func beginRequestWithExtensionContext(context: NSExtensionContext) {
        // Do not call super in an Action extension with no user interface

        // Find the item containing the results from the JavaScript preprocessing.
        outer: for item: AnyObject in context.inputItems {
            let extItem = item as! NSExtensionItem
            if let attachments = extItem.attachments {
                for itemProvider: AnyObject in attachments {
                    //if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeLivePhoto as String) {
                    //let loadOptions = [NSItemProviderPreferredImageSizeKey: NSValue(CGSize: CGSize(width: 200, height: 200))]
                    if !itemProvider.hasItemConformingToTypeIdentifier(kUTTypeLivePhoto as String) {
                        print("No livephoto found")
                        context.cancelRequestWithError(NSError(domain: "No Live Photo associated with this image.", code: 1, userInfo: nil))
                        return
                    } else {
                        /*itemProvider.loadItemForTypeIdentifier(kUTTypeLivePhoto as String, options: nil, completionHandler: { (item, error) in
                            print(item)
                            print(error)
                            print((error as NSError).usefulDescription)
                        })*/
                    }
                    if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                        itemProvider.loadItemForTypeIdentifier(kUTTypeImage as String, options: nil, completionHandler: { (item, error) in
                            if error != nil {
                                print(error.usefulDescription)
                                context.cancelRequestWithError(error)
                                return
                            }
                            if let livePhotoURL = item as? NSURL {
                                NSOperationQueue.mainQueue().addOperationWithBlock({
                                    if let imageSource = CGImageSourceCreateWithURL(livePhotoURL, nil), propertiesCF = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) {
                                        let properties = propertiesCF as NSDictionary
                                        if let exif = properties[kCGImagePropertyExifDictionary as NSString] as? NSDictionary, dateTaken = exif[kCGImagePropertyExifDateTimeOriginal as NSString] as? NSString {
                                            print(dateTaken)

                                            let dateFormatter = NSDateFormatter()
                                            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                                            let date = dateFormatter.dateFromString(dateTaken as String)!

                                            let options = PHFetchOptions()
                                            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                                            options.predicate = NSPredicate(format: "creationDate >= %@", date)
                                            options.fetchLimit = 1
                                            if let asset = PHAsset.fetchAssetsWithOptions(options).firstObject as? PHAsset {
                                                print(asset.creationDate!)
                                                let resources = PHAssetResource.assetResourcesForAsset(asset)
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
                                                    context.cancelRequestWithError(NSError(domain: "A required file wasn't found", code: 1, userInfo: nil))
                                                    return
                                                }

                                                livePhotoToGif(movieFile: movieFile!, jpegFile: jpegFile!, progressHandler: {_ in }, completionHandler: { (url: NSURL, error: NSError?) -> Void in
                                                    print(url)
                                                    print(error)
                                                    if error != nil {
                                                        context.cancelRequestWithError(error!)
                                                    } else {
                                                        let resultsItem = NSExtensionItem()
                                                        resultsItem.attachments = [NSItemProvider(contentsOfURL: url)!]
                                                        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
                                                            PHAssetChangeRequest.creationRequestForAssetFromImageAtFileURL(url)
                                                            return
                                                        }, completionHandler: { (success: Bool, error: NSError?) -> Void in
                                                            if error != nil {
                                                                context.cancelRequestWithError(error!)
                                                            }
                                                            if success {
                                                                context.completeRequestReturningItems([resultsItem], completionHandler: { (expired: Bool) -> Void in
                                                                    if expired {
                                                                        print("FAILED")
                                                                    } else {
                                                                        print("SUCCEEDED")
                                                                    }
                                                                })
                                                            } else {
                                                                context.cancelRequestWithError(NSError(domain: "Failed to save file", code: 1, userInfo: nil))
                                                            }
                                                        })
                                                    }
                                                })
                                            }
                                        }
                                    }
                                })
                            }
                        })
                    } else {
                        context.cancelRequestWithError(NSError(domain: "URL wasn't found", code: 1, userInfo: nil))
                        return
                    }
                }
            }
        }
    }

}
