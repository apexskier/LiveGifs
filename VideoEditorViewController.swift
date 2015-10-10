//
//  VideoEditorViewController.swift
//  Live Photo Share
//
//  Created by Cameron Little on 10/9/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Foundation
import Photos
import UIKit

class VideoEditorViewController: UIViewController {
    let videoAsset: AVAsset

    init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?, video: AVAsset) {
        self.videoAsset = video
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    override func viewDidLoad() {
        let totalWidth = view.bounds.size.width
        let generator = AVAssetImageGenerator(asset: videoAsset)
        generator.requestedTimeToleranceAfter = kCMTimeZero
        generator.requestedTimeToleranceBefore = kCMTimeZero
        let timeLength = videoAsset.duration.seconds
        let height: CGFloat = 40
        let numImages = height / totalWidth
        do {
            for w in 0...Int(numImages - 1) {
                let imageView = UIImageView(frame: CGRect(x: CGFloat(w) * height, y: 4, width: height, height: height))
                let seconds = Double(w) * (timeLength / Double(numImages))
                let time = CMTime(seconds: seconds, preferredTimescale: 6000)
                imageView.image = UIImage(CGImage: try generator.copyCGImageAtTime(time, actualTime: nil))
            }
        } catch let error as NSError {
            print(error.usefulDescription)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}