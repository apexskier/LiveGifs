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

    var running = false

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

        title = NSBundle.mainBundle().infoDictionary?["CFBundleName"] as? String
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
        imageManager.requestImageForAsset(assets[indexPath.item] as! PHAsset, targetSize: cell.frame.size, contentMode: PHImageContentMode.AspectFill, options: photoRequestOptions) { (image: UIImage?, info: [NSObject : AnyObject]?) in
            cell.imageView.image = image
        }
        cell.backgroundColor = UIColor.grayColor()
        // cell.imageView.image = photo...
        // ...
        return cell
    }
    
    override func collectionView(collectionView: UICollectionView, shouldSelectItemAtIndexPath indexPath: NSIndexPath) -> Bool {
        if !running {
            self.running = true
            let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoGridCell
            cell.progressBar.hidden = false
            let asset = assets[indexPath.item]
            let screenBounds = UIScreen.mainScreen().bounds
            let optionsPH = PHLivePhotoRequestOptions()
            optionsPH.deliveryMode = .HighQualityFormat
            optionsPH.networkAccessAllowed = true
            optionsPH.progressHandler = { (progress: Double, error: NSError?, object: UnsafeMutablePointer<ObjCBool>, info: [NSObject : AnyObject]?) in
                print("lp download progress: \(progress)")
                cell.progressBar.setProgress(Float(progress), animated: true)
            }
            imageManager.requestLivePhotoForAsset(asset as! PHAsset, targetSize: CGSize(width: screenBounds.size.width * 2, height: screenBounds.size.height * 2), contentMode: .AspectFit, options: optionsPH, resultHandler: { (livePhoto: PHLivePhoto?, info: [NSObject: AnyObject]?) -> Void in
                let overlayNavController = UIStoryboard(name: "Main", bundle: nil).instantiateViewControllerWithIdentifier("OverlayViewNavigationController")
                self.presentViewController(overlayNavController, animated: true, completion: { () -> Void in
                    let overlayController = overlayNavController.childViewControllers.first as!OverlayViewController
                    overlayController.livephotoView.livePhoto = livePhoto
                    self.running = false
                    cell.progressBar.hidden = true
                    cell.progressBar.progress = 0
                })
            })
        }
        return false
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
