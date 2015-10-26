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

    var progressIsUp = false
    var saving = false
    
    override func viewDidLoad() {
        editingContainerView.hidden = true
        progressBarContainer.clipsToBounds = true
        progressBarContainer.frame = CGRect(origin: progressBarContainer.frame.origin, size: CGSize(width: progressBarContainer.frame.width, height: 0))
        progressBar.progress = 0
        
        editingControlsController?.rightHandle.hidden = true
        editingControlsController?.rightCropOverlay.hidden = true
        editingControlsController?.leftHandle.hidden = true
        editingControlsController?.leftCropOverlay.hidden = true
    }

    override func viewDidAppear(animated: Bool) {
        livephotoView.hidden = true
    }
    
    override func viewWillDisappear(animated: Bool) {
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        editingControlsController = segue.destinationViewController as? VideoEditorControls
        editingControlsController?.delegate = self
    }

    @IBAction func tapSelectSource(sender: AnyObject) {
        if !UIImagePickerController.isSourceTypeAvailable(.PhotoLibrary) {
            print("TODO error")
        }
        let availableTypes = UIImagePickerController.availableMediaTypesForSourceType(.PhotoLibrary)!
        var types: [String] = []
        if availableTypes.contains(kUTTypeMovie as String) {
            types.append(kUTTypeMovie as String)
        }
        if availableTypes.contains(kUTTypeImage as String) {
            types.append(kUTTypeImage as String)
        }
        if availableTypes.contains(kUTTypeGIF as String) {
            types.append(kUTTypeGIF as String)
        } else {
            print("filter by gif not available")
        }
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .PhotoLibrary
        picker.mediaTypes = types

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
        
        presentViewController(picker, animated: true) {}
    }

    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        let mediaType = (info[UIImagePickerControllerMediaType] as! CFString) as String
        var foundGIF = false
        if mediaType != kUTTypeMovie as String {
            // let image = (info[UIImagePickerControllerEditedImage] ?? info[UIImagePickerControllerOriginalImage])! as! UIImage
            // print(CGImageGetUTType(image.CGImage)! == kUTTypeGIF)
            if let imageURL = info[UIImagePickerControllerReferenceURL] as? NSURL, imageURLComponents = NSURLComponents(URL: imageURL, resolvingAgainstBaseURL: false) {
                for item in imageURLComponents.queryItems ?? [] {
                    if item.name == "ext" && (item.value == "GIF" || item.value == "gif") {
                        foundGIF = true
                        break
                    }
                }
            }
            if !foundGIF {
                print(info)
                let alert = UIAlertController(title: "Error", message: "Please select a movie or GIF.", preferredStyle: .Alert)
                let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                alert.addAction(okay)
                picker.presentViewController(alert, animated: true) {}
                selectSourceButton.hidden = false
                centralActivityIndicator.stopAnimating()
                return
            }
        }
        
        dismissViewControllerAnimated(true) {}
        
        selectSourceButton.hidden = true
        centralActivityIndicator.startAnimating()
        
        editInformation = EditInformation()
        editInformation.centerDirty = true
        if foundGIF {
            let options = PHFetchOptions()
            options.fetchLimit = 1
            let fetchResults = PHAsset.fetchAssetsWithALAssetURLs([info[UIImagePickerControllerReferenceURL] as! NSURL], options: options)
            let managerOptions = PHImageRequestOptions()
            managerOptions.networkAccessAllowed = true
            // managerOptions.progressHandler
            PHImageManager.defaultManager().requestImageDataForAsset(fetchResults.firstObject! as! PHAsset, options: managerOptions, resultHandler: { data, uti, orientation, info in
                if data != nil {
                    if let source = CGImageSourceCreateWithData(data!, nil) {
                        gifToMov(source, progressHandler: { progress in
                            print("gifToLivephotoMov progress: \(progress)")
                        }, completionHandler: { url, error in
                            if error != nil {
                                let alert = UIAlertController(title: "Error", message: "Failed to convert GIF to movie.", preferredStyle: .Alert)
                                let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                                alert.addAction(okay)
                                self.presentViewController(alert, animated: true) {}
                                dispatch_async(dispatch_get_main_queue(), {
                                    self.selectSourceButton.hidden = false
                                    self.centralActivityIndicator.stopAnimating()
                                })
                            } else {
                                self.videoURL = url
                                dispatch_async(dispatch_get_main_queue(), self.setupVideoForEditing)
                            }
                        })
                    } else {
                        let alert = UIAlertController(title: "Error", message: "Failed to fetch GIF data.", preferredStyle: .Alert)
                        let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                        alert.addAction(okay)
                        self.presentViewController(alert, animated: true) {}
                        dispatch_async(dispatch_get_main_queue(), {
                            self.selectSourceButton.hidden = false
                            self.centralActivityIndicator.stopAnimating()
                        })
                    }
                } else {
                    let alert = UIAlertController(title: "Error", message: "Failed to fetch GIF data.", preferredStyle: .Alert)
                    let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                    alert.addAction(okay)
                    self.presentViewController(alert, animated: true) {}
                    dispatch_async(dispatch_get_main_queue(), {
                        self.selectSourceButton.hidden = false
                        self.centralActivityIndicator.stopAnimating()
                    })
                }
            })
        } else {
            videoURL = info[UIImagePickerControllerMediaURL] as? NSURL
            return setupVideoForEditing()
        }
    }
    
    func setupVideoForEditing() {
        let videoAsset = AVAsset(URL: videoURL!)
        if let videoTrack = videoAsset.tracksWithMediaType(AVMediaTypeVideo).first {
            let size = videoTrack.naturalSize
            orientation = orientationFromTransform(videoTrack.preferredTransform).orientation
            frameRatio = { () -> CGFloat in
                switch orientation! {
                case .Right, .Left:
                    return size.height / size.width
                case .Up, .Down:
                    fallthrough
                default:
                    return size.width / size.height
                }
                }()
            editingControlsController?.tearDown()
            editingControlsController?.setUp {
                self.centralActivityIndicator.stopAnimating()
                self.saveButton.enabled = true
                self.editingContainerView.hidden = false
            }
        } else {
            let alert = UIAlertController(title: "Error", message: "Did not find video track.", preferredStyle: .Alert)
            let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
            alert.addAction(okay)
            self.presentViewController(alert, animated: true) {}
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
                dispatch_async(dispatch_get_main_queue(), {
                    self.progressDown()
                    self.saveButton.enabled = true
                })
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
                        dispatch_async(dispatch_get_main_queue(), {
                            self.progressDown()
                            self.saveButton.enabled = true
                        })
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
                        
                        self.saving = true
                        
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
                                    let alert = UIAlertController(title: "Success", message: "The Live Photo has been saved to your library.", preferredStyle: .Alert)
                                    let okay = UIAlertAction(title: "Done", style: UIAlertActionStyle.Cancel, handler: nil)
                                    let share = UIAlertAction(title: "Share", style: .Default, handler: { actionUIAlertAction in
                                        let options = PHFetchOptions()
                                        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                                        options.fetchLimit = 1
                                        options.predicate =  NSPredicate(format: "mediaSubtype = %i", PHAssetMediaSubtype.PhotoLive.rawValue)
                                        let assets = PHAsset.fetchAssetsWithOptions(options)
                                        if let asset = assets.firstObject as? PHAsset {
                                            PHImageManager.defaultManager().requestLivePhotoForAsset(asset, targetSize: CGSizeZero, contentMode: .Default, options: nil, resultHandler: { livePhoto, info in
                                                let sheet = UIActivityViewController(activityItems: [livePhoto!], applicationActivities: nil)
                                                sheet.excludedActivityTypes = [UIActivityTypePrint, UIActivityTypeSaveToCameraRoll]
                                                self.presentViewController(sheet, animated: true) {}
                                            })
                                        }
                                    })
                                    alert.addAction(share)
                                    alert.addAction(okay)
                                    self.presentViewController(alert, animated: true) {}
                                })
                                // SUCCESS -- should be caught by PHPhotoLibraryChangeObserver
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