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

class PhotoGridViewController: UICollectionViewController, UIViewControllerPreviewingDelegate, UICollectionViewDelegateFlowLayout, PHPhotoLibraryChangeObserver {
    private let reuseIdentifier = "PhotoGridCell"
    @IBOutlet weak var noAccessView: UIView!
    @IBOutlet weak var emptyLabel: UILabel!

    var running = false
    var waitingForNew = false
    
    let notificationCenter = NSNotificationCenter.defaultCenter()

    var observers: [AnyObject] = []

    let fileManager = NSFileManager.defaultManager()
    let resourceManager = PHAssetResourceManager.defaultManager()
    let imageManager = PHImageManager.defaultManager()

    var selectedCell: NSIndexPath?

    var assets: PHFetchResult! {
        didSet {
            collectionView!.reloadData()
            checkErrors()
        }
    }
    
    func checkErrors() {
        let authStatus = PHPhotoLibrary.authorizationStatus()
        if authStatus == .Denied || authStatus == .Restricted || authStatus == .NotDetermined {
            noAccessView.hidden = false
            emptyLabel.hidden = true
        } else if assets.count == 0 {
            noAccessView.hidden = true
            emptyLabel.hidden = false
        } else {
            noAccessView.hidden = true
            emptyLabel.hidden = true
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.registerForPreviewingWithDelegate(self, sourceView: collectionView!)

        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self)
        
        loadAssets()

        if PHPhotoLibrary.authorizationStatus() != PHAuthorizationStatus.Authorized {
            PHPhotoLibrary.requestAuthorization(requestAuthorizationHandler)
        }
        
        observers.append(notificationCenter.addObserverForName("wakeUp", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification: NSNotification!) -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                self.loadAssets()
            })
        }))

        observers.append(notificationCenter.addObserverForName("trigger", object: nil, queue: nil, usingBlock: { (notification: NSNotification!) in
            let action = notification.object! as! Action
            if self.presentedViewController == nil {
                self.selectPhoto(action, progressHandler: {_ in }, completionHandler: {_ in })
            } else {
                self.dismissViewControllerAnimated(false, completion: {
                    self.selectPhoto(action, progressHandler: {_ in }, completionHandler: {_ in })
                })
            }
        }))
        
        observers.append(notificationCenter.addObserverForName("creating", object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { (notification: NSNotification!) -> Void in
            self.waitingForNew = true
        }))
        
        notificationCenter.addObserver(self, selector: "loadAssets", name: UIApplicationDidBecomeActiveNotification, object: nil)
        
        notificationCenter.postNotificationName("viewControllerListening", object: nil)
    }

    func requestAuthorizationHandler(status: PHAuthorizationStatus) {
        if PHPhotoLibrary.authorizationStatus() == PHAuthorizationStatus.Authorized {
            print("photos authorized")
            dispatch_async(dispatch_get_main_queue(), {
                self.loadAssets()
            })
        } else {
            self.dismissViewControllerAnimated(true, completion: nil)
        }
    }

    func loadAssets() {
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
        imageManager.requestImageForAsset(assets[indexPath.item] as! PHAsset, targetSize: cell.frame.size * uiScale, contentMode: PHImageContentMode.AspectFill, options: photoRequestOptions) { (image: UIImage?, info: [NSObject : AnyObject]?) in
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
        if let path = collectionView?.indexPathForItemAtPoint(location), cell = collectionView?.cellForItemAtIndexPath(path) {
            let viewController = PeekViewController()
            viewController.view.backgroundColor = UIColor.grayColor()

            previewingContext.sourceRect = cell.frame
            
            viewController.indexPath = path
            
            let asset = assets[path.item] as! PHAsset
            
            let targetSize = CGSize(width: viewController.view.bounds.width * uiScale, height: viewController.view.bounds.width * uiScale)
            
            // Fallback on earlier versions
            let options = PHVideoRequestOptions()
            options.deliveryMode = .Automatic
            options.networkAccessAllowed = true
            let optionsPH = PHLivePhotoRequestOptions()
            optionsPH.deliveryMode = .Opportunistic
            optionsPH.networkAccessAllowed = true
            imageManager.requestLivePhotoForAsset(asset, targetSize: targetSize, contentMode: .AspectFill, options: optionsPH, resultHandler: { (livePhoto: PHLivePhoto?, info: [NSObject: AnyObject]?) -> Void in
                if livePhoto == nil {
                    return
                }
                dispatch_async(dispatch_get_main_queue(), {
                    let livePhotoView = PHLivePhotoView(frame: viewController.view.bounds)
                    livePhotoView.livePhoto = livePhoto
                    viewController.view.addSubview(livePhotoView)
                    livePhotoView.startPlaybackWithStyle(.Full)
                })
            })
            
            return viewController
        }
        return nil
    }

    @IBAction func tapOpenSettings(sender: AnyObject) {
        if let to = NSURL(string: UIApplicationOpenSettingsURLString) {
            if UIApplication.sharedApplication().canOpenURL(to) {
                UIApplication.sharedApplication().openURL(to)
            }
        }
    }
    
    // MARK: custom stuff

    func selectPhoto(action: Action, progressHandler: (Double) -> Void, completionHandler: (NSError?) -> Void) {
        if !running {
            self.running = true
            let asset = assets[action.indexPath.item]
            let screenBounds = UIScreen.mainScreen().bounds
            let targetSize = CGSize(width: screenBounds.size.width * uiScale, height: screenBounds.size.height * uiScale)
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
                    overlayController.livephotoView.startPlaybackWithStyle(.Full)
                    if action.action != "" {
                        self.notificationCenter.postNotificationName(action.action, object: nil)
                    }
                    completionHandler(nil)
                })
            })
        } else {
            completionHandler(NSError(domain: "Already opening a live photo, try again in 5 seconds.", code: 1, userInfo: nil))
        }
    }
    
    // MARK: UICollectionViewDelegateFlowLayout
    
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

    // MARK: PHPhotoLibraryChangeObserver
    
    func photoLibraryDidChange(changeInfo: PHChange) {
        // Photos may call this method on a background queue;
        // switch to the main queue to update the UI.
        dispatch_async(dispatch_get_main_queue()) {
            // Check for changes to the list of assets (insertions, deletions, moves, or updates).
            if let collectionChanges = changeInfo.changeDetailsForFetchResult(self.assets) {
                
                if collectionChanges.hasIncrementalChanges {
                    // Get the changes as lists of index paths for updating the UI.
                    var removedPaths: [NSIndexPath]?
                    var insertedPaths: [NSIndexPath]?
                    var changedPaths: [NSIndexPath]?
                    if let removed = collectionChanges.removedIndexes {
                        removedPaths = self.indexPathsFromIndexSet(removed)
                    }
                    if let inserted = collectionChanges.insertedIndexes {
                        insertedPaths = self.indexPathsFromIndexSet(inserted)
                        // open added photo if it's the only one and we're not already showing something.
                    }
                    if let changed = collectionChanges.changedIndexes {
                        changedPaths = self.indexPathsFromIndexSet(changed)
                    }
                    
                    // Tell the collection view to animate insertions/deletions/moves
                    // and to refresh any cells that have changed content.
                    self.collectionView!.performBatchUpdates({
                        if removedPaths != nil {
                            self.collectionView?.deleteItemsAtIndexPaths(removedPaths!)
                        }
                        if insertedPaths != nil {
                            self.collectionView?.insertItemsAtIndexPaths(insertedPaths!)
                        }
                        if changedPaths != nil {
                            self.collectionView?.reloadItemsAtIndexPaths(changedPaths!)
                        }
                        if (collectionChanges.hasMoves) {
                            collectionChanges.enumerateMovesWithBlock() { fromIndex, toIndex in
                                let fromIndexPath = NSIndexPath(forItem: fromIndex, inSection: 0)
                                let toIndexPath = NSIndexPath(forItem: toIndex, inSection: 0)
                                self.collectionView?.moveItemAtIndexPath(fromIndexPath, toIndexPath: toIndexPath)
                            }
                        }
                        
                        // Get the new fetch result for future change tracking.
                        self.assets = collectionChanges.fetchResultAfterChanges
                    }, completion: { success in
                        if insertedPaths?.count >= 1 && self.waitingForNew {
                            let action = Action(indexPath: insertedPaths![0])
                            self.dismissViewControllerAnimated(true, completion: nil)
                            self.selectPhoto(action, progressHandler: {_ in }, completionHandler: {_ in })
                            self.waitingForNew = false
                        }
                    })
                } else {
                    // Detailed change information is not available;
                    // repopulate the UI from the current fetch result.
                    self.collectionView?.reloadData()
                    self.checkErrors()
                }
            }
        }
    }
    
    private func indexPathsFromIndexSet(indexSet: NSIndexSet) -> [NSIndexPath] {
        var indexPaths: [NSIndexPath] = []
        
        indexSet.enumerateIndexesUsingBlock { (index, _) -> Void in
            indexPaths.append(NSIndexPath(forItem: index, inSection: 0))
        }
        
        return indexPaths
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
        let notificationCenter = NSNotificationCenter.defaultCenter()
        let shareAsGif = UIPreviewAction(title: "Share as GIF", style: UIPreviewActionStyle.Default) { (action: UIPreviewAction, previewViewController: UIViewController) -> Void in
            print("share as gif preview action")
            let vc = previewViewController as! PeekViewController
            notificationCenter.postNotificationName("trigger", object: Action(indexPath: vc.indexPath!, action: "shareGif"))
        }
        let shareAsMov = UIPreviewAction(title: "Share as Movie", style: UIPreviewActionStyle.Default) { (action: UIPreviewAction, previewViewController: UIViewController) -> Void in
            print("share as mov preview action")
            let vc = previewViewController as! PeekViewController
            notificationCenter.postNotificationName("trigger", object: Action(indexPath: vc.indexPath!, action: "shareMov"))
        }
        let shareAsSilent = UIPreviewAction(title: "Share as Silent Movie", style: UIPreviewActionStyle.Default) { (action: UIPreviewAction, previewViewController: UIViewController) -> Void in
            print("share as silent mov preview action")
            let vc = previewViewController as! PeekViewController
            notificationCenter.postNotificationName("trigger", object: Action(indexPath: vc.indexPath!, action: "shareSilentMov"))
        }
        return [shareAsGif, shareAsMov, shareAsSilent]
    }
}
