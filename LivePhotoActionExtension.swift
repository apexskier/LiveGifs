//
//  LivePhotoActionExtension.swift
//  Live Photo Share
//
//  Created by Cameron Little on 10/4/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import UIKit
import Photos
import ImageIO
import MobileCoreServices

class LivePhotoActionRequestHandler: NSObject, NSExtensionRequestHandling {

    var context: NSExtensionContext?

    func action(livePhotoURL: NSURL) {
        // Must be overridden
    }

    func beginRequestWithExtensionContext(context: NSExtensionContext) {
        // Do not call super in an Action extension with no user interface
        self.context = context

        // Find the item containing the results from the JavaScript preprocessing.
        for item: AnyObject in context.inputItems {
            if let extItem = item as? NSExtensionItem, attachments = extItem.attachments {
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
                                    self.action(livePhotoURL)
                                })
                            }
                        })
                    }
                }
            }
        }
    }

}