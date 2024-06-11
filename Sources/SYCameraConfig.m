//
//  SYCameraConfig.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/5/26.
//

#import "SYCameraConfig.h"

@implementation SYCameraConfig

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.mode = SKModeUnspecified;
        self.sessionPreset = nil;
        self.devicePosition = AVCaptureDevicePositionUnspecified;
    }
    return self;
}

- (instancetype)initWithMode:(SYCameraMode)mode
           withSessionPreset:(AVCaptureSessionPreset)sessionPreset
                withPosition:(AVCaptureDevicePosition)devicePosition
{
    self = [super init];
    if (self) {
        self.mode = mode;
        self.sessionPreset = sessionPreset;
        self.devicePosition = devicePosition;
    }
    return self;
}


@end
