//
//  ActionRequestHandler.swift
//  Live Photo Export Video
//
//  Created by Cameron Little on 10/4/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import UIKit
import Photos
import ImageIO
import MobileCoreServices

class ActionRequestHandler: LivePhotoActionRequestHandler {
    override func action(livePhotoURL: NSURL) {
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
                        context!.cancelRequestWithError(NSError(domain: "A required file wasn't found", code: 1, userInfo: nil))
                        return
                    }

                    livePhotoToMovie(movieFile: movieFile!, progressHandler: {_ in }, completionHandler: { (url: NSURL, error: NSError?) -> Void in
                        print(url)
                        print(error)
                        if error != nil {
                            self.context!.cancelRequestWithError(error!)
                        } else {
                            PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> Void in
                                PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(url)
                            }, completionHandler: { (success: Bool, error: NSError?) -> Void in
                                if error != nil {
                                    print(error!.usefulDescription)
                                    self.context!.cancelRequestWithError(error!)
                                } else if success {
                                    let resultsItem = NSExtensionItem()
                                    resultsItem.attachments = [NSItemProvider(contentsOfURL: url)!]
                                        self.context!.completeRequestReturningItems([resultsItem], completionHandler: { (expired: Bool) -> Void in
                                        if expired {
                                            print("FAILED")
                                        } else {
                                            print("SUCCEEDED")
                                        }
                                    })
                                } else {
                                    self.context!.cancelRequestWithError(NSError(domain: "Failed to save file.", code: 1, userInfo: nil))
                                }
                            })
                        }
                    })
                }
            }
        }
    }
}
