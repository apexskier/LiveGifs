//
//  ViewController.swift
//  LiveGifs
//
//  Created by Cameron Little on 9/25/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import AVFoundation
import Photos
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
        photoRequestOptions.deliveryMode = PHImageRequestOptionsDeliveryMode.Opportunistic
        photoRequestOptions.resizeMode = PHImageRequestOptionsResizeMode.Exact
        manager.requestImageForAsset(assets[indexPath.item] as! PHAsset,
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
            let asset = assets[indexPath.item]
            print("selected \(indexPath.row)")
            manager.requestLivePhotoForAsset(asset, CGSize(300, 300), PHImageContentMode.AspectFit, nil) { (livePhoto: PHLivePhoto?, info: [NSObject: AnyObject]?) in {
                let resources = PHAssetResource.AssetResourcesForLivePhoto(livePhoto)
                var movieFile: PHAssetResource?
                for item in resources {
                    print(item.type.rawValue)
                    if item.uniformTypeIdentifier == "com.apple.quicktime-movie" {
                        movieFile = item
                        break
                    }
                }
                let movResourceOptions = PHAssetResourceRequestOptions()
                movResourceOptions.networkAccessAllowed = true
                PHAssetResourceManager.defaultManager().requestDataForAssetResource(movieFile!, options: movResourceOptions, dataReceivedHandler: { (data: NSData) -> Void in
                    let tempFileName = "temp_\(movieFile!.assetLocalIdentifier)_\(movieFile!.originalFilename)"
                    let tempFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(tempFileName))
                    print(tempFileUrl)
                    data.writeToURL(tempFileUrl, atomically: true)
                    let movAsset = AVAsset(URL: tempFileUrl)
                    let metadata = movAsset.metadata
                    for data in metadata {
                        print(data)
                    }
                    print(metadata)
                    let generator = AVAssetImageGenerator(asset: movAsset)

                    }, completionHandler: { (error: NSError?) -> Void in
                        if error != nil {
                            // TODO: handle
                        }
                })
            }
            /*
            let resources = PHAssetResource.assetResourcesForAsset(asset as! PHAsset)
            var movieFile: PHAssetResource?
            for item in resources {
                print(item.type.rawValue)
                if item.uniformTypeIdentifier == "com.apple.quicktime-movie" {
                    movieFile = item
                    break
                }
            }
            let movResourceOptions = PHAssetResourceRequestOptions()
            movResourceOptions.networkAccessAllowed = true
            PHAssetResourceManager.defaultManager().requestDataForAssetResource(movieFile!, options: movResourceOptions, dataReceivedHandler: { (data: NSData) -> Void in
                let tempFileName = "temp_\(movieFile!.assetLocalIdentifier)_\(movieFile!.originalFilename)"
                let tempFileUrl = NSURL.fileURLWithPath(NSTemporaryDirectory().stringByAppendingString(tempFileName))
                print(tempFileUrl)
                data.writeToURL(tempFileUrl, atomically: true)
                let movAsset = AVAsset(URL: tempFileUrl)
                let metadata = movAsset.metadata
                for data in metadata {
                    print(data)
                }
                print(metadata)
                let generator = AVAssetImageGenerator(asset: movAsset)

            }, completionHandler: { (error: NSError?) -> Void in
                if error != nil {
                    // TODO: handle
                }
            })*/
            let sheet = UIActivityViewController(activityItems: [], applicationActivities: nil)
            sheet.excludedActivityTypes = [UIActivityTypePrint]
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
