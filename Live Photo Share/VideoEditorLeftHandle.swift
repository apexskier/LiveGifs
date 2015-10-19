//
//  VideoEditorLeftHandle.swift
//  Live Photo Share
//
//  Created by Cameron Little on 10/18/15.
//  Copyright © 2015 Cameron Little. All rights reserved.
//

import Foundation
import UIKit

typealias ListenerID = Int32

class HandleView: UIView {
    private var _leftBound: CGFloat = 0
    var leftBound: CGFloat {
        get {
            return _leftBound
        }
        set (value) {
            self._leftBound = max(value, 0)
        }
    }
    private var _rightBound: CGFloat = -1
    var rightBound: CGFloat {
        get {
            if _rightBound == -1 {
                _rightBound = self.superview!.frame.width
            }
            return _rightBound
        }
        set (value) {
            self._rightBound = min(value, self.superview!.frame.width)
        }
    }
    
    var boundsWidth: CGFloat {
        get {
            return (rightBound - leftBound) - self.frame.width
        }
    }

    var width: CGFloat {
        get {
            return self.frame.width
        }
    }

    private var moveListeners: [ListenerID:((CGFloat) -> Void)] = [:]
    private var touchDownListeners: [ListenerID:(() -> Void)] = [:]
    private var touchUpListeners: [ListenerID:(() -> Void)] = [:]

    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let theTouch = touches.filter({ (touch: UITouch) -> Bool in
            return touch.view == self || touch.view?.isDescendantOfView(self) ?? false
        }).first {
            let loc = theTouch.locationInView(self.superview)
            let p = min(max(loc.x, leftBound + self.frame.width / 2), rightBound - self.frame.width / 2)
            for (_, val) in moveListeners {
                val(CGFloat(p))
            }
            self.center.x = p
        }
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let _ = touches.filter({ (touch: UITouch) -> Bool in
            return touch.view == self || touch.view?.isDescendantOfView(self) ?? false
        }).first {
            touchDownListeners.forEach({ $1() })
        }
    }

    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let _ = touches.filter({ (touch: UITouch) -> Bool in
            return touch.view == self || touch.view?.isDescendantOfView(self) ?? false
        }).first {
            touchUpListeners.forEach({ $1() })
        }
    }

    internal func onMove(handler: CGFloat -> Void) -> ListenerID {
        let id = ListenerID(rand())
        moveListeners[id] = handler
        return id
    }

    internal func onTouchDown(handler: () -> Void) -> ListenerID {
        let id = ListenerID(rand())
        touchDownListeners[id] = handler
        return id
    }

    internal func onTouchUp(handler: () -> Void) -> ListenerID {
        let id = ListenerID(rand())
        touchUpListeners[id] = handler
        return id
    }

    internal func clearHandlers() {
        moveListeners = [:]
        touchDownListeners = [:]
        touchUpListeners = [:]
    }
}


class VideoEditorLeftHandle: HandleView {

}

class VideoEditorRightHandle: HandleView {

}

class VideoEditorCenterHandle: HandleView {
    
}