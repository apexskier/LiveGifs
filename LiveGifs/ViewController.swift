//
//  ViewController.swift
//  LiveGifs
//
//  Created by Cameron Little on 9/25/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import AVFoundation
import Photos
import ImageIO
import MobileCoreServices
import UIKit
import Regift

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

class PhotoGridViewController: UICollectionViewController {
    private let reuseIdentifier = "PhotoGridCell"

    let fileManager = NSFileManager.defaultManager()
    let resourceManager = PHAssetResourceManager.defaultManager()
    let imageManager = PHImageManager.defaultManager()
    
    var selectedCell: NSIndexPath?
    
    var assets: PHFetchResult! {
        didSet {
            collectionView!.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
        
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.Authorized {
            createUserInterface()
        } else {
            PHPhotoLibrary.requestAuthorization(requestAuthorizationHandler)
        }
    }
    
    func requestAuthorizationHandler(status: PHAuthorizationStatus) {
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.Authorized {
            print("authorized")
        } else {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }

    func createUserInterface() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate =  NSPredicate(format: "mediaSubtype = %i", PHAssetMediaSubtype.PhotoLive.rawValue)
        assets = PHAsset.fetchAssetsWithOptions(options)
    }
    
    // MARK: UICollectionViewDataSource
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if assets == nil { return 0 }
        return assets.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! PhotoGridCell
        cell.progressBar.hidden = true
        cell.progressBar.progress = 0
        let photoRequestOptions = PHImageRequestOptions()
        photoRequestOptions.deliveryMode = PHImageRequestOptionsDeliveryMode.Opportunistic
        photoRequestOptions.resizeMode = PHImageRequestOptionsResizeMode.Exact
        imageManager.requestLivePhotoForAsset(assets[indexPath.item] as! PHAsset, targetSize: cell.frame.size, contentMode: PHImageContentMode.AspectFill, options: nil) { (photo: PHLivePhoto?, info: [NSObject : AnyObject]?) -> Void in
            cell.livePhotoView.livePhoto = photo
        }
        cell.backgroundColor = UIColor.grayColor()
        // cell.imageView.image = photo...
        // ...
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        if selectedCell == indexPath {
            selectedCell = nil
        } else {
            selectedCell = indexPath
            let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoGridCell
            cell.progressBar.hidden = false
            let asset = assets[indexPath.item]
            print("selected \(indexPath.row)")
            let screenBounds = UIScreen.mainScreen().bounds
            let optionsPH = PHLivePhotoRequestOptions()
            optionsPH.deliveryMode = .HighQualityFormat
            optionsPH.networkAccessAllowed = true
            optionsPH.progressHandler = { (progress: Double, error: NSError?, object: UnsafeMutablePointer<ObjCBool>, info: [NSObject : AnyObject]?) in
                cell.progressBar.progress = Float(progress)
            }
            imageManager.requestLivePhotoForAsset(asset as! PHAsset, targetSize: CGSize(width: screenBounds.size.width, height: screenBounds.size.height), contentMode: .AspectFit, options: optionsPH, resultHandler: { (livePhoto: PHLivePhoto?, info: [NSObject: AnyObject]?) -> Void in
                let resources = PHAssetResource.assetResourcesForLivePhoto(livePhoto!)
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
                    dispatch_async(dispatch_get_main_queue(), {
                        let alert = UIAlertController(title: "Error", message: "No movie file found for this photo.", preferredStyle: UIAlertControllerStyle.Alert)
                        UIApplication.sharedApplication().keyWindow?.rootViewController!.presentViewController(alert, animated: true, completion: nil)
                    })
                    return
                }

                // get the image
                let jpegResourceOptions = PHAssetResourceRequestOptions()
                jpegResourceOptions.networkAccessAllowed = true
                jpegResourceOptions.progressHandler = { (progress: Double) in
                    dispatch_async(dispatch_get_main_queue(), {
                        cell.progressBar.progress = Float(progress) / 2 + 0.5
                    })
                }
                let jpegFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(jpegFile!.originalFilename))
                // delete any old files
                do { try self.fileManager.removeItemAtURL(jpegFileUrl) }
                catch {}

                self.resourceManager.writeDataForAssetResource(jpegFile!, toFile: jpegFileUrl, options: jpegResourceOptions, completionHandler: { (error: NSError?) -> Void in
                    if error != nil {
                        let alert = UIAlertController(title: "Error", message: "Failed to get movie file.", preferredStyle: UIAlertControllerStyle.Alert)
                        UIApplication.sharedApplication().keyWindow?.rootViewController!.presentViewController(alert, animated: true, completion: nil)
                        print(error?.usefulDescription)
                        return
                    }
                    let liveImageJpeg = UIImage(contentsOfFile: jpegFileUrl.path!)!
                    let orientation = liveImageJpeg.imageOrientation
                    let targetHeight = liveImageJpeg.size.height
                    let targetWidth = liveImageJpeg.size.width

                    let movResourceOptions = PHAssetResourceRequestOptions()
                    movResourceOptions.networkAccessAllowed = true
                    movResourceOptions.progressHandler = { (progress: Double) in
                        dispatch_async(dispatch_get_main_queue(), {
                            cell.progressBar.progress = Float(progress) / 2
                        })
                    }
                    let movFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(movieFile!.originalFilename))
                    // delete any old files
                    do { try self.fileManager.removeItemAtURL(movFileUrl) }
                    catch {}
                    self.resourceManager.writeDataForAssetResource(movieFile!, toFile: movFileUrl, options: movResourceOptions, completionHandler: { (error: NSError?) -> Void in
                        if error != nil {
                            let alert = UIAlertController(title: "Error", message: "Failed to get movie file.", preferredStyle: UIAlertControllerStyle.Alert)
                            UIApplication.sharedApplication().keyWindow?.rootViewController!.presentViewController(alert, animated: true, completion: nil)
                            print(error?.usefulDescription)
                            return
                        }

                        let movAsset = AVAsset(URL: movFileUrl)
                        // let videoTrack = movAsset.tracks[0]
                        let frameRate = Float(2) // videoTrack.nominalFrameRate
                        let frameCount = frameRate * Float(movAsset.duration.seconds)
                        print("frameRate: \(frameRate), frameCount: \(frameCount), length: \(movAsset.duration.seconds)")

                        var times: [CMTime] = []
                        for i in 1...Int(frameCount) {
                            times.append(CMTime(seconds: Double(i) / Double(frameRate), preferredTimescale: 6000))
                        }
                        let lastTime = times[times.count - 1]

                        let movFilename: NSString = movieFile!.originalFilename
                        let gifFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString("\(movFilename.stringByDeletingPathExtension).gif"))
                        print(gifFileUrl)
                        do { try self.fileManager.removeItemAtURL(gifFileUrl) }
                        catch {}

                        let destination = CGImageDestinationCreateWithURL(gifFileUrl, kUTTypeGIF, Int(frameCount), nil)
                        let gifProperties: CFDictionaryRef = [
                            kCGImagePropertyGIFDictionary as String: [
                                kCGImagePropertyGIFLoopCount as String: 0, // loop forever
                            ]
                        ]
                        let frameProperties: CFDictionaryRef = [
                            kCGImagePropertyGIFDictionary as String: [
                                kCGImagePropertyGIFDelayTime as String: 1 / Float(frameRate)
                                // kCGImagePropertyGIFHasGlobalColorMap as String: false
                            ]
                        ]
                        CGImageDestinationSetProperties(destination!, gifProperties)

                        let generator = AVAssetImageGenerator(asset: movAsset)
                        var count = 0

                        for time in times {
                            do {
                                let imageFrame = try generator.copyCGImageAtTime(time, actualTime: nil) //.rotate(orientation, targetWidth: Int(targetWidth), targetHeight: Int(targetHeight))

                                // DEBUG
                                /*let imgPath = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString("\(movieFile!.originalFilename).\(count).gif"))
                                do { try self.fileManager.removeItemAtURL(imgPath) }
                                catch {}
                                let imgDest = CGImageDestinationCreateWithURL(imgPath, kUTTypeGIF, 1, nil)
                                CGImageDestinationAddImage(imgDest!, imageFrame, nil)
                                CGImageDestinationFinalize(imgDest!)*/

                                CGImageDestinationAddImage(destination!, imageFrame, frameProperties)

                                cell.progressBar.progress = Float(time.seconds / lastTime.seconds)

                                print("\(count) -- requestedTime: \(time.seconds)")
                                count++
                            } catch let error as NSError {
                                let alert = UIAlertController(title: "Error", message: "Failed to get movie file.", preferredStyle: UIAlertControllerStyle.Alert)
                                UIApplication.sharedApplication().keyWindow?.rootViewController!.presentViewController(alert, animated: true, completion: nil)
                                print(error.usefulDescription)
                                return
                            }
                        }
                        CGImageDestinationSetProperties(destination!, gifProperties)
                        CGImageDestinationFinalize(destination!)
                        
                        let sheet = UIActivityViewController(activityItems: [gifFileUrl], applicationActivities: nil)
                        sheet.excludedActivityTypes = [UIActivityTypePrint]
                        self.presentViewController(sheet, animated: true, completion: {
                            cell.progressBar.hidden = true
                        })
                    })
                })
            })
        }
        return false
    }
}

extension PhotoGridViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        let screenWidth = UIScreen.mainScreen().bounds.size.width
        let cols: CGFloat = 4
        let w = (screenWidth - (cols - 1)) / cols
        return CGSize(width: w, height: w)
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }
}

extension PhotoGridViewController: PHPhotoLibraryChangeObserver {
    func photoLibraryDidChange(changeInstance: PHChange) {
        guard let assets = assets else {
            return
        }
        
        if let changeDetails = changeInstance.changeDetailsForFetchResult(assets) {
            self.assets = changeDetails.fetchResultAfterChanges
        }
    }
}
