//
//  CoreExtensions.swift
//  LiveGifs
//
//  Created by Cameron Little on 9/27/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Foundation
import UIKit

extension NSError {
    var usefulDescription: String {
        if let m = self.localizedFailureReason {
            return m
        } else if self.localizedDescription != "" {
            return self.localizedDescription
        }
        return self.domain
    }
}

func radians(v: CGFloat) -> CGFloat {
    return CGFloat(M_PI) / CGFloat(180)
}

extension CGImage {
    func rotate(rotation: UIImageOrientation, targetWidth: Int, targetHeight: Int) -> CGImage {
        let colorSpaceInfo = CGImageGetColorSpace(self)
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue).rawValue
        let bitsPerComp = CGImageGetBitsPerComponent(self)
        let bytesPerRow = 0 // CGImageGetBytesPerRow(self)

        var bitmap: CGContextRef

        if (rotation == .Up || rotation == .Down) {
            bitmap = CGBitmapContextCreate(nil, targetWidth, targetHeight, bitsPerComp, bytesPerRow, colorSpaceInfo, bitmapInfo)!
        } else {
            bitmap = CGBitmapContextCreate(nil, targetHeight, targetWidth, bitsPerComp, bytesPerRow, colorSpaceInfo, bitmapInfo)!
        }

        if (rotation == .Left) {
            CGContextRotateCTM(bitmap, radians(90))
            CGContextTranslateCTM (bitmap, 0, CGFloat(-targetHeight))
        } else if (rotation == .Right) {
            CGContextRotateCTM(bitmap, radians(-90))
            CGContextTranslateCTM (bitmap, CGFloat(-targetWidth), 0)
        } else if (rotation == .Up) {
            // NOTHING
        } else if (rotation == .Down) {
            CGContextTranslateCTM(bitmap, CGFloat(targetWidth), CGFloat(targetHeight))
            CGContextRotateCTM(bitmap, radians(-180))
        }
        
        CGContextDrawImage(bitmap, CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight), self)
        let ret = CGBitmapContextCreateImage(bitmap)!

        return ret
    }
}