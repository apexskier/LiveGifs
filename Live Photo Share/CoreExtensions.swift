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

infix operator * { associativity left precedence 140 }
func *(left: CGSize, right: Double) -> CGSize {
    let r = CGFloat(right)
    return CGSize(width: left.width * r, height: left.width * r)
}
func *(left: CGSize, right: CGFloat) -> CGSize {
    return left * Double(right)
}
func *(left: CGSize, right: Int) -> CGSize {
    return left * Double(right)
}