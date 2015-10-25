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
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var selectSourceButton: UIButton!
    @IBOutlet weak var editingContainerView: UIView!
    @IBOutlet weak var centralActivityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var progressBarContainer: UIView!
    @IBOutlet weak var progressBar: UIProgressView!

    var editingControlsController: VideoEditorControls?

    var selectingImage = false
    var progressIsUp = false
    
    override func viewDidLoad() {
        editingContainerView.hidden = true
        progressBarContainer.clipsToBounds = true
        progressBarContainer.frame = CGRect(origin: progressBarContainer.frame.origin, size: CGSize(width: progressBarContainer.frame.width, height: 0))
        progressBar.progress = 0
    }

    override func viewDidAppear(animated: Bool) {
        livephotoView.hidden = true
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        self.editingControlsController = segue.destinationViewController as? VideoEditorControls
        self.editingControlsController?.delegate = self
    }

    @IBAction func tapSelectSource(sender: AnyObject) {
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
        dismissViewControllerAnimated(true) {}
        
        selectSourceButton.hidden = true
        centralActivityIndicator.startAnimating()
        
        if selectingImage {
            imageView.image = (info[UIImagePickerControllerEditedImage] as? UIImage ?? info[UIImagePickerControllerOriginalImage] as? UIImage)!
        } else {
            editInformation = EditInformation()
            editInformation.centerDirty = true
            videoURL = info[UIImagePickerControllerReferenceURL] as? NSURL
            let videoAsset = AVAsset(URL: videoURL!)
            let videoTrack = videoAsset.tracksWithMediaType(AVMediaTypeVideo).first
            let size = videoTrack!.naturalSize
            // let transform = videoTrack!.preferredTransform
            orientation = .Up
            frameRatio = size.width / size.height
            editingControlsController?.tearDown()
            editingControlsController?.setUp {
                self.centralActivityIndicator.stopAnimating()
                self.saveButton.enabled = true
                self.editingContainerView.hidden = false
            }
        }
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        self.centralActivityIndicator.stopAnimating()
        dismissViewControllerAnimated(true, completion: {})
    }
    
    @IBAction func saveButtonTap(sender: AnyObject) {
        let movAsset = AVAsset(URL: videoURL!)
        let assetId = NSUUID().UUIDString
        saveButton.enabled = false
        progressUp()
        stdMovToLivephotoMov(assetId, movAsset: movAsset, editInfo: editInformation, progressHandler: { progress in
            dispatch_async(dispatch_get_main_queue(), {
                self.progressBar.setProgress(Float(progress) / 3.0, animated: true)
            })
        }){ (newMovURL, error) in
            if error != nil {
                print(error!.usefulDescription)
                dispatch_async(dispatch_get_main_queue(), {
                    let alert = UIAlertController(title: "Error", message: "Failed to edit movie.", preferredStyle: .Alert)
                    let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                    alert.addAction(okay)
                    self.presentViewController(alert, animated: true) {}
                })
            } else {
                generateImg(assetId, movAsset: movAsset, referenceImgURL: nil, editInfo: self.editInformation, progressHandler: { progress in
                    dispatch_async(dispatch_get_main_queue(), {
                        self.progressBar.setProgress(Float(progress) / 3.0 + 1/3, animated: true)
                    })
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
                        let movSavePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("SAVE_\(assetId).MOV")
                        //let imgSavePath = (NSTemporaryDirectory() as NSString).stringByAppendingPathComponent("SAVE_\(assetId).JPG")
                        
                        QuickTimeMov(path: newMovURL.path!).write(movSavePath, assetIdentifier: assetId)
                        
                        let newMovURL2 = NSURL(fileURLWithPath: movSavePath)
                        
                        saveLivePhoto(movURL: newMovURL2, jpegURL: imgURL, progressHandler: { progress in
                            dispatch_async(dispatch_get_main_queue(), {
                                self.progressBar.setProgress(Float(progress) / 3.0 + 2/3, animated: true)
                            })
                        }) { error in
                            self.progressBar.setProgress(1, animated: true)
                            dispatch_async(dispatch_get_main_queue(), {
                                self.progressDown()
                                self.saveButton.enabled = true
                            })
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
    
    @IBAction func tapClear(sender: AnyObject) {
        editingContainerView.hidden = true
        selectSourceButton.hidden = false
        editingControlsController?.tearDown()
    }
    
    func progressUp() {
        UIView.animateWithDuration(0.2, delay: 0, options: .CurveEaseInOut, animations: {
            self.progressBarContainer.frame.size.height = 10
        }) { finished in
            if finished {
                self.progressIsUp = true
            }
        }
    }
    
    func progressDown() {
        UIView.animateWithDuration(0.4, delay: 0.2, options: .CurveEaseInOut, animations: {
            self.progressBarContainer.frame.size.height = 0
        }) { finished in
            self.progressBar.progress = 0
            if finished {
                self.progressIsUp = false
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
        // never actually unsavable
    }
}