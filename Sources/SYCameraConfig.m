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
    self = [self initWithSessionPreset:AVCaptureSessionPresetPhoto withPosition:AVCaptureDevicePositionBack];
    return self;
}

- (instancetype)initWithSessionPreset:(AVCaptureSessionPreset)sessionPreset
                         withPosition:(AVCaptureDevicePosition)devicePosition;
{
    self = [super init];
    if (self) {
        self.sessionPreset = sessionPreset;
        self.devicePosition = devicePosition;
    }
    return self;
}


@end
