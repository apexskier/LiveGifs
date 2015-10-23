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

class CreateViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, VideoEditorControlsDelegate {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var livephotoView: PHLivePhotoView!
    @IBOutlet weak var saveButton: UIButton!
    var editingControlsController: VideoEditorControls?

    var selectingImage = false

    override func viewDidAppear(animated: Bool) {
        livephotoView.hidden = true
        saveButton.enabled = false
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        self.editingControlsController = segue.destinationViewController as? VideoEditorControls
        self.editingControlsController?.delegate = self
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
            editInformation = EditInformation()
            videoURL = info[UIImagePickerControllerReferenceURL] as? NSURL
            let videoAsset = AVAsset(URL: videoURL!)
            let videoTrack = videoAsset.tracksWithMediaType(AVMediaTypeVideo).first
            let size = videoTrack!.naturalSize
            let transform = videoTrack!.preferredTransform
            print(transform)
            orientation = UIImageOrientation.Up/* = { () -> UIImageOrientation in
                if size.width == transform.tx && size.height == transform.ty {
                    return UIImageOrientation.Right
                } else if (transform.tx == 0 && transform.ty == 0) {
                    return UIImageOrientation.Left
                } else if (transform.tx == 0 && transform.ty == size.width) {
                    return UIImageOrientation.Down
                } else {
                    return UIImageOrientation.Up
                }
            }()*/
            frameRatio = size.width / size.height
            editingControlsController?.tearDown()
            editingControlsController?.setUp({})
        }
    }
    
    @IBAction func saveButtonTap(sender: AnyObject) {
        let movAsset = AVAsset(URL: videoURL!)
        editMov(movAsset: movAsset, movURL: videoURL!, editInfo: editInformation, progressHandler: { progress in
            print("editMov: \(progress)")
        }) { (newMovURL, error) in
            if error != nil {
                print(error!.usefulDescription)
                dispatch_async(dispatch_get_main_queue(), {
                    let alert = UIAlertController(title: "Error", message: "Failed to edit movie.", preferredStyle: .Alert)
                    let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                    alert.addAction(okay)
                    self.presentViewController(alert, animated: true) {}
                })
            } else {
                generateImg(movAsset, referenceImgURL: nil, editInfo: self.editInformation, progressHandler: { progress in
                    print("generateImg: \(progress)")
                }) { (imgURL, error) in
                    if error != nil {
                        print(error!.usefulDescription)
                        dispatch_async(dispatch_get_main_queue(), {
                            let alert = UIAlertController(title: "Error", message: "Failed to generate image.", preferredStyle: .Alert)
                            let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                            alert.addAction(okay)
                            self.presentViewController(alert, animated: true) {}
                        })
                    } else {
                        saveLivePhoto(movURL: newMovURL, jpegURL: imgURL, progressHandler: { progress in
                            print("saveLivePhoto: \(progress)")
                        }) { error in
                            if error != nil {
                                print(error!.usefulDescription)
                                dispatch_async(dispatch_get_main_queue(), {
                                    let alert = UIAlertController(title: "Error", message: "Failed to save Live Photo.", preferredStyle: .Alert)
                                    let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                                    alert.addAction(okay)
                                    self.presentViewController(alert, animated: true) {}
                                })
                            } else {
                                dispatch_async(dispatch_get_main_queue(), {
                                    let alert = UIAlertController(title: "Success!", message: "Saved new Live Photo.", preferredStyle: .Alert)
                                    let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                                    alert.addAction(okay)
                                    self.presentViewController(alert, animated: true) {}
                                })
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: VideoEditorControls
    
    var editInformation = EditInformation()
    var videoURL: NSURL?
    var orientation: UIImageOrientation?
    var frameRatio: CGFloat?
    
    func imageUpdated(image: UIImage) {
        imageView.image = image
    }
    
    func scrubbingStarted(handle: VideoEditorHandle) {
        //livephotoView.hidden = true
        //imageView.hidden = false
    }
    
    func scrubbingEnded(handle: VideoEditorHandle) {
        //livephotoView.hidden = false
        //imageView.hidden = true
    }
    
    func becameSavable() {
        dispatch_async(dispatch_get_main_queue(), {
            self.saveButton.enabled = true
        })
    }
    
    func becameUnsavable() {
        dispatch_async(dispatch_get_main_queue(), {
            self.saveButton.enabled = false
        })
    }
}