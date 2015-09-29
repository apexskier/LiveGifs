//
//  ActionRequestHandler.swift
//  LivePhotoToGif
//
//  Created by Cameron Little on 9/28/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import UIKit
import Photos
import MobileCoreServices

class ActionRequestHandler: NSObject, NSExtensionRequestHandling {

    var extensionContext: NSExtensionContext?
    
    func beginRequestWithExtensionContext(context: NSExtensionContext) {
        // Do not call super in an Action extension with no user interface
        self.extensionContext = context
        var found = false
        // Find the item containing the results from the JavaScript preprocessing.
        outer: for item: AnyObject in context.inputItems {
            let extItem = item as! NSExtensionItem
            print("\(extItem.attributedTitle) -- \(extItem.attributedContentText)")
            if let attachments = extItem.attachments {
                for itemProvider: AnyObject in attachments {
                    //if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeLivePhoto as String) {
                        //let loadOptions = [NSItemProviderPreferredImageSizeKey: NSValue(CGSize: CGSize(width: 200, height: 200))]
                    if !itemProvider.hasItemConformingToTypeIdentifier(kUTTypeLivePhoto as String) {
                        print("No liveimage found")
                        self.doneWithResults(nil)
                        return
                    }
                    if itemProvider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                        itemProvider.loadItemForTypeIdentifier(kUTTypeImage as String, options: nil, completionHandler: { (item, error) in
                            if error != nil {
                                print(error.usefulDescription)
                                self.doneWithResults(nil)
                            }
                            print(item.debugDescription)
                            /*if let livePhoto = item as? PHLivePhoto {
                                print("found livephoto")
                                print(livePhoto)
                            }*/
                            if let livePhotoURL = item as? NSURL {
                                let pathComponents = livePhotoURL.pathComponents!
                                let filename = pathComponents[pathComponents.count - 1] as NSString
                                let localID = filename.stringByDeletingPathExtension
                                print(localID)
                                let assets = PHAsset.fetchAssetsWithLocalIdentifiers([localID], options: nil)
                                print(assets.count)
                                let livephotoAsset = assets.firstObject! as! PHAssetResource
                                print(livephotoAsset.description)
                                found = true
                            }
                            NSOperationQueue.mainQueue().addOperationWithBlock({
                                print("--->")
                            })
                        })
                        if found {
                            return
                        }
                    } else {
                        self.doneWithResults(nil)
                        return
                    }
                }
            }
        }
    }
    
    func doneWithResults(itemsArg: [NSObject: AnyObject]?) {
        if let items = itemsArg {
            // Construct an NSExtensionItem of the appropriate type to return our
            // results dictionary in.
            
            let resultsDictionary = [NSExtensionJavaScriptFinalizeArgumentKey: items]

            let resultsProvider = NSItemProvider(item: resultsDictionary, typeIdentifier: String(kUTTypePropertyList))
            
            let resultsItem = NSExtensionItem()
            resultsItem.attachments = [resultsProvider]
            
            // Signal that we're complete, returning our results.
            self.extensionContext!.completeRequestReturningItems([resultsItem], completionHandler: nil)
        } else {
            // We still need to signal that we're done even if we have nothing to
            // pass back.
            self.extensionContext!.completeRequestReturningItems([], completionHandler: nil)
        }
        
        // Don't hold on to this after we finished with it.
        self.extensionContext = nil
    }

}
