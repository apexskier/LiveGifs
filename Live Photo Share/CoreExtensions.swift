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