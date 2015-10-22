//
//  CreateViewController.swift
//  Live Photo Share
//
//  Created by Cameron Little on 10/21/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import AVFoundation
import Photos
import PhotosUI
import ImageIO
import MobileCoreServices
import UIKit

class CreateViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var livePhotoView: PHLivePhotoView!

    var selectingImage = false

    override func viewDidAppear(animated: Bool) {
        livePhotoView.hidden = true
    }

    @IBAction func tapSelectMotion(sender: AnyObject) {
        if !UIImagePickerController.isSourceTypeAvailable(.PhotoLibrary) {
            print("TODO error")
        }
        let availableTypes = UIImagePickerController.availableMediaTypesForSourceType(.PhotoLibrary)!
        if !availableTypes.contains(kUTTypeMovie as String) {
            print("TODO error")
        }
        if !availableTypes.contains(kUTTypeGIF as String) {
              print("TODO error")
        }
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .PhotoLibrary
        picker.mediaTypes = [kUTTypeMovie as String, kUTTypeGIF as String]
        selectingImage = false
        presentViewController(picker, animated: true) {}
    }

    @IBAction func tapSelectPhoto(sender: AnyObject) {
        if !UIImagePickerController.isSourceTypeAvailable(.PhotoLibrary) {
            print("TODO error")
        }
        let availableTypes = UIImagePickerController.availableMediaTypesForSourceType(.PhotoLibrary)!
        if !availableTypes.contains(kUTTypeImage as String) {
            print("TODO error")
        }
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .PhotoLibrary
        picker.mediaTypes = [kUTTypeImage as String]
        selectingImage = true
        presentViewController(picker, animated: true) {}
    }

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let mediaType = info[UIImagePickerControllerMediaType]!
        print(mediaType)
        self.dismissViewControllerAnimated(true) {}

        if selectingImage {
            imageView.image = (info[UIImagePickerControllerEditedImage] as? UIImage ?? info[UIImagePickerControllerOriginalImage] as? UIImage)!
        } else {

        }
    }
}