//
//  ExampleCode.swift
//  Live Photo Share
//
//  Created by Cameron Little on 10/5/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Foundation

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
            context.cancelRequestWithError(error!)
        } else if success {
            let resultsItem = NSExtensionItem()
            resultsItem.attachments = [NSItemProvider(contentsOfURL: url)!]
            context.completeRequestReturningItems([resultsItem], completionHandler: { (expired: Bool) -> Void in
                if expired {
                    print("FAILED")
                } else {
                    print("SUCCEEDED")
                }
            })
        } else {
            context.cancelRequestWithError(NSError(domain: "Failed to save file.", code: 1, userInfo: nil))
        }
})