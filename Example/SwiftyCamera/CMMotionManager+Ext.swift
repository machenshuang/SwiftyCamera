//
//  CMMotionManager+Ext.swift
//  SwiftyCamera_Example
//
//  Created by 马陈爽 on 2024/6/19.
//  Copyright © 2024 CocoaPods. All rights reserved.
//

import Foundation
import CoreMotion
import UIKit

extension CMMotionManager {
    func motionStart(update:((_ orientation: UIDeviceOrientation) -> Void)?) {
        if !self.isAccelerometerAvailable {
            return
        }
        self.accelerometerUpdateInterval = 0.3
        self.startAccelerometerUpdates(to: OperationQueue.main) { (accelerometerData, error) in
            if let error = error {
                return
            }
            guard let acceleration = accelerometerData?.acceleration else { return }
            guard let completion = update else { return }
            var orientation: UIDeviceOrientation = .portrait
            if acceleration.y <= -0.75 {
                orientation = .portrait
            } else if acceleration.y >= 0.75 {
                orientation = .portraitUpsideDown
            } else if acceleration.x <= -0.75 {
                orientation = .landscapeLeft
            } else if acceleration.x >= 0.75 {
                orientation = .landscapeRight
            } else {
                orientation = .portrait
            }
            completion(orientation)
        }
    }
    
    func motionStop() {
        if self.isAccelerometerAvailable && self.isAccelerometerActive {
            self.stopAccelerometerUpdates()
        }
    }
}
