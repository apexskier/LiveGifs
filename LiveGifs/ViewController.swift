//
//  ViewController.swift
//  LiveGifs
//
//  Created by Cameron Little on 9/25/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import UIKit
import Photos

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
    
    var selectedCell: NSIndexPath?
    
    let manager = PHImageManager.defaultManager()
    
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
        options.predicate =  NSPredicate(format: "mediaSubtype = %i", 8)// PHAssetMediaSubtype.PhotoLive.rawValue
        assets = PHAsset.fetchAssetsWithOptions(options)
        
        for var i = 0; i < assets.count; i++ {
            let asset = assets[i] as? PHAsset
            
            print(asset?.creationDate)
            print(asset?.mediaSubtypes)
            print(asset?.mediaType)
        }
    }
    
    // MARK: UICollectionViewDataSource
    override func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int {
        return 1
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return assets.count
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(reuseIdentifier, forIndexPath: indexPath) as! PhotoGridCell
        let photoRequestOptions = PHImageRequestOptions()
        print(indexPath.row)
        photoRequestOptions.deliveryMode = PHImageRequestOptionsDeliveryMode.Opportunistic
        photoRequestOptions.resizeMode = PHImageRequestOptionsResizeMode.Exact
        self.manager.requestImageForAsset(assets[indexPath.item] as! PHAsset,
            targetSize: cell.frame.size,
            contentMode: PHImageContentMode.AspectFill,
            options: photoRequestOptions) { (image: UIImage?, info: [NSObject : AnyObject]?) in
            cell.imageView.image = image
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
            print("selected \(indexPath.row)")
            let sheet = UIActivityViewController(activityItems: [], applicationActivities: nil)
            sheet.excludedActivityTypes =
                [UIActivityTypePrint,
                UIActivityTypeSaveToCameraRoll,
                UIActivityTypePostToFlickr]
            self.presentViewController(sheet, animated: true, completion: nil)
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
