//
//  ViewController.swift
//  LiveGifs
//
//  Created by Cameron Little on 9/25/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import AVFoundation
import Photos
import PhotosUI
import ImageIO
import MobileCoreServices
import UIKit

class PhotoGridViewController: UICollectionViewController, UIViewControllerPreviewingDelegate {
    private let reuseIdentifier = "PhotoGridCell"

    var running = false

    var observers: [AnyObject] = []

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

        self.registerForPreviewingWithDelegate(self, sourceView: collectionView!)

        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
        
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.Authorized {
            reloadAssets()
        } else {
            PHPhotoLibrary.requestAuthorization(requestAuthorizationHandler)
        }

        title = NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? String

        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("wakeUp", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification: NSNotification!) -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                self.reloadAssets()
                self.collectionView!.reloadData()
            })
        }))

        observers.append(NSNotificationCenter.defaultCenter().addObserverForName("trigger", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            self.reloadAssets()
            let action = notification.object! as! Action
            self.selectPhoto(action, progressHandler: {_ in }, completionHandler: {_ in })
        }))
    }
    
    func requestAuthorizationHandler(status: PHAuthorizationStatus) {
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.Authorized {
            print("photos authorized")
            dispatch_async(dispatch_get_main_queue(), {
                self.reloadAssets()
                self.collectionView!.reloadData()
            })
        } else {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }

    func reloadAssets() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        if #available(iOS 9.1, *) {
            options.predicate =  NSPredicate(format: "mediaSubtype = %i", PHAssetMediaSubtype.PhotoLive.rawValue)
        } else if (!DEBUG) {
            // Fallback on earlier versions
            let alert = UIAlertController(title: "Error", message: "This app requires iOS 9.1 or higher.", preferredStyle: .Alert)
            self.presentViewController(alert, animated: true) {}
        }
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
        imageManager.requestImageForAsset(assets[indexPath.item] as! PHAsset, targetSize: cell.frame.size, contentMode: PHImageContentMode.AspectFill, options: photoRequestOptions) { (image: UIImage?, info: [NSObject : AnyObject]?) in
            cell.imageView.image = image
        }
        cell.backgroundColor = UIColor.grayColor()
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoGridCell
        cell.progressBar.hidden = false
        selectPhoto(Action(indexPath: indexPath), progressHandler: { (progress: Double) -> Void in
            cell.progressBar.setProgress(Float(progress), animated: true)
        }) { (error: NSError?) -> Void in
            if error != nil {
                let alert = UIAlertController(title: "Error", message: error?.domain, preferredStyle: .Alert)
                let okay = UIAlertAction(title: "OK", style: .Default, handler: nil)
                alert.addAction(okay)
                self.presentViewController(alert, animated: true) {}
            }
            cell.progressBar.hidden = true
            cell.progressBar.progress = 0
        }
        return false
    }

    // MARK: 3D touch

    func previewingContext(previewingContext: UIViewControllerPreviewing, commitViewController viewControllerToCommit: UIViewController) {
        print("previewingContext(previewingContext: UIViewControllerPreviewing, commitViewController viewControllerToCommit: UIViewController)")
        // self.presentViewController(viewControllerToCommit, animated: false, completion: nil)
        let vc = viewControllerToCommit as? PeekViewController
        if let path = vc?.indexPath {
            selectPhoto(Action(indexPath: path), progressHandler: {_ in }, completionHandler: {_ in })
        }
    }

    func previewingContext(previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        let viewController = PeekViewController()
        viewController.view.backgroundColor = UIColor.grayColor()

        let path = collectionView!.indexPathForItemAtPoint(location)
        let cell = collectionView!.cellForItemAtIndexPath(path!)
        if let frame = cell?.frame {
            previewingContext.sourceRect = frame
        }

        viewController.indexPath = path

        let asset = assets[path!.item]

        let targetSize = CGSize(width: viewController.view.bounds.width * uiScale, height: viewController.view.bounds.width * uiScale)

        if #available(iOS 9.1, *) {
            let optionsPH = PHLivePhotoRequestOptions()
            optionsPH.deliveryMode = .Opportunistic
            optionsPH.networkAccessAllowed = true
            imageManager.requestLivePhotoForAsset(asset as! PHAsset, targetSize: targetSize, contentMode: .AspectFill, options: optionsPH, resultHandler: { (livePhoto: PHLivePhoto?, info: [NSObject: AnyObject]?) -> Void in
                dispatch_async(dispatch_get_main_queue(), {
                    let livePhotoView = PHLivePhotoView(frame: viewController.view.bounds)
                    livePhotoView.livePhoto = livePhoto
                    viewController.view.addSubview(livePhotoView)
                })
            })
        } else {
            // Fallback on earlier versions
            let options = PHVideoRequestOptions()
            options.deliveryMode = .Automatic
            options.networkAccessAllowed = true
            imageManager.requestPlayerItemForVideo(asset as! PHAsset, options: options, resultHandler: { (playerItem: AVPlayerItem?, info: [NSObject : AnyObject]?) -> Void in
                if playerItem == nil {
                    let optionsPH = PHImageRequestOptions()
                    optionsPH.deliveryMode = .Opportunistic
                    optionsPH.networkAccessAllowed = true
                    self.imageManager.requestImageForAsset(asset as! PHAsset, targetSize: targetSize, contentMode: .AspectFill, options: optionsPH, resultHandler: { (image: UIImage?, info: [NSObject : AnyObject]?) -> Void in
                        dispatch_async(dispatch_get_main_queue(), {
                            let imageView = UIImageView(image: image)
                            imageView.contentMode = UIViewContentMode.ScaleAspectFill
                            imageView.frame = viewController.view.bounds
                            viewController.view.addSubview(imageView)
                        })
                    })
                    return
                }
                dispatch_async(dispatch_get_main_queue(), {
                    let player = AVPlayer(playerItem: playerItem!)
                    let videoLayer = AVPlayerLayer()
                    videoLayer.frame = viewController.view.bounds
                    videoLayer.bounds = viewController.view.bounds
                    videoLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
                    viewController.view.layer.addSublayer(videoLayer)
                    playerItem?.seekToTime(kCMTimeZero)
                    player.play()
                })
            })
        }
        return viewController
    }

    // MARK: custom stuff

    func selectPhoto(action: Action, progressHandler: (Double) -> Void, completionHandler: (NSError?) -> Void) {
        if !running {
            self.running = true
            let asset = assets[action.indexPath.item]
            let screenBounds = UIScreen.mainScreen().bounds
            let targetSize = CGSize(width: screenBounds.size.width * uiScale, height: screenBounds.size.height * uiScale)
            if #available(iOS 9.1, *) {
                let optionsPH = PHLivePhotoRequestOptions()
                optionsPH.deliveryMode = .HighQualityFormat
                optionsPH.networkAccessAllowed = true
                optionsPH.progressHandler = { (progress: Double, error: NSError?, object: UnsafeMutablePointer<ObjCBool>, info: [NSObject : AnyObject]?) in
                    print("lp download progress: \(progress)")
                }
                imageManager.requestLivePhotoForAsset(asset as! PHAsset, targetSize: targetSize, contentMode: .AspectFit, options: optionsPH, resultHandler: { (livePhoto: PHLivePhoto?, info: [NSObject: AnyObject]?) -> Void in
                    self.running = false
                    if livePhoto == nil {
                        return completionHandler(NSError(domain: "The live photo was not found.", code: -1, userInfo: nil))
                    }
                    let overlayNavController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("OverlayViewNavigationController")
                    self.presentViewController(overlayNavController, animated: true, completion: { () -> Void in
                        let overlayController = overlayNavController.childViewControllers.first as!OverlayViewController
                        overlayController.livephotoView.livePhoto = livePhoto
                        if action.action != "" {
                            NSNotificationCenter.defaultCenter().postNotificationName(action.action, object: nil)
                        }
                        completionHandler(nil)
                    })
                })
            } else if (!DEBUG) {
                // Fallback on earlier versions
                let alert = UIAlertController(title: "Error", message: "This app requires iOS 9.1 or higher.", preferredStyle: .Alert)
                self.presentViewController(alert, animated: true) {}
                completionHandler(NSError(domain: "This app requires iOS 9.1 or higher.", code: 1, userInfo: nil))
                self.running = false
            } else {
                let overlayNavController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("OverlayViewNavigationController")
                self.presentViewController(overlayNavController, animated: true, completion: { () -> Void in
                    completionHandler(nil)
                    if action.action != "" {
                        NSNotificationCenter.defaultCenter().postNotificationName(action.action, object: nil)
                    }
                })
                completionHandler(nil)
                self.running = false
            }
        } else {
            completionHandler(NSError(domain: "Already opening a live photo, try again in 5 seconds.", code: 1, userInfo: nil))
        }
    }

    @IBAction func getInfo(sender: UIBarButtonItem) {
        let overlayNavController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("InfoNavigationController")
        self.presentViewController(overlayNavController, animated: true, completion: nil)
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

class Action: AnyObject {
    let indexPath: NSIndexPath
    let action: String

    init(indexPath: NSIndexPath, action: String) {
        self.indexPath = indexPath
        self.action = action
    }

    init(indexPath: NSIndexPath) {
        self.indexPath = indexPath
        self.action = ""
    }
}

class PeekViewController: UIViewController {
    var indexPath: NSIndexPath?

    override func previewActionItems() -> [UIPreviewActionItem] {
        let shareAsGif = UIPreviewAction(title: "Share as GIF", style: UIPreviewActionStyle.Selected) { (action: UIPreviewAction, previewViewController: UIViewController) -> Void in
            print("share as gif preview action")
            let vc = previewViewController as! PeekViewController
            NSNotificationCenter.defaultCenter().postNotificationName("trigger", object: Action(indexPath: vc.indexPath!, action: "shareGif"))
        }
        let shareAsMov = UIPreviewAction(title: "Share as Movie", style: UIPreviewActionStyle.Default) { (action: UIPreviewAction, previewViewController: UIViewController) -> Void in
            print("share as mov preview action")
            let vc = previewViewController as! PeekViewController
            NSNotificationCenter.defaultCenter().postNotificationName("trigger", object: Action(indexPath: vc.indexPath!, action: "shareMov"))
        }
        let shareAsSilent = UIPreviewAction(title: "Share as Silent Movie", style: UIPreviewActionStyle.Default) { (action: UIPreviewAction, previewViewController: UIViewController) -> Void in
            print("share as silent mov preview action")
            let vc = previewViewController as! PeekViewController
            NSNotificationCenter.defaultCenter().postNotificationName("trigger", object: Action(indexPath: vc.indexPath!, action: "shareSilentMov"))
        }
        return [shareAsGif, shareAsMov, shareAsSilent]
    }
}