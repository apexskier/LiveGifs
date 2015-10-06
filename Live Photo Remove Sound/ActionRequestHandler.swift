//
//  ActionRequestHandler.swift
//  Live Photo Remove Sound
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
                        context!.cancelRequestWithError(NSError(domain: "A required file wasn't found", code: 1, userInfo: nil))
                        return
                    }

                    livePhotoToSilentMovie(movieFile: movieFile!, progressHandler: {_ in }, completionHandler: { (url: NSURL, error: NSError?) -> Void in
                        print(url)
                        if error != nil {
                            print(error!.usefulDescription)
                            self.context!.cancelRequestWithError(error!)
                        } else {
                            let jpegFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(jpegFile!.originalFilename))
                            // delete any old files
                            do { try NSFileManager.defaultManager().removeItemAtURL(jpegFileUrl) }
                            catch {}
                            let jpegResourceOptions = PHAssetResourceRequestOptions()
                            jpegResourceOptions.networkAccessAllowed = true
                            PHAssetResourceManager.defaultManager().writeDataForAssetResource(jpegFile!, toFile: jpegFileUrl, options: jpegResourceOptions, completionHandler: { (error: NSError?) -> Void in
                                if error != nil {
                                    print(error?.usefulDescription)
                                    self.context!.cancelRequestWithError(NSError(domain: "Failed to get jpeg.", code: 1, userInfo: nil))
                                }

                                PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                                    let request = PHAssetCreationRequest.creationRequestForAsset()

                                    // These types should be inferred from your files
                                    // let photoOptions = PHAssetResourceCreationOptions()
                                    // photoOptions.uniformTypeIdentifier = kUTTypeJPEG as String
                                    // let videoOptions = PHAssetResourceCreationOptions()
                                    // videoOptions.uniformTypeIdentifier = kUTTypeQuickTimeMovie as String

                                    request.addResourceWithType(.Photo, fileURL: jpegFileUrl, options: nil)
                                    request.addResourceWithType(.PairedVideo, fileURL: url, options: nil)
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

                                /*let screenBounds = UIScreen.mainScreen().bounds
                                let targetSize = CGSize(width: screenBounds.size.width * uiScale, height: screenBounds.size.height * uiScale)
                                PHLivePhoto.requestLivePhotoWithResourceFileURLs([jpegFileUrl, url], placeholderImage: UIImage(contentsOfFile: jpegFileUrl.path!), targetSize: targetSize, contentMode: .AspectFill, resultHandler: { (livePhoto: PHLivePhoto?, info: [NSObject : AnyObject]) -> Void in
                                    print(info)

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
                                })*/
                            })
                        }
                    })
                }
            }
        }
    }
}
