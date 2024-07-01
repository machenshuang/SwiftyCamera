//
//  SYCameraConfig.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/5/26.
//

#import "SYCameraConfig.h"
#import <AVFoundation/AVFoundation.h>

@implementation SYCameraConfig

- (instancetype)init
{
    self = [self initWithMode:SYPhotoMode withSessionPreset:AVCaptureSessionPresetPhoto withPosition:AVCaptureDevicePositionBack];
    return self;
}

- (instancetype)initWithMode:(SYCameraMode)mode
           withSessionPreset:(AVCaptureSessionPreset)sessionPreset
                withPosition:(AVCaptureDevicePosition)devicePosition
{
    self = [self initWithMode:mode withType:SYSingleDevice withSessionPreset:sessionPreset withPosition:devicePosition];
    return self;
}

- (instancetype)initWithMode:(SYCameraMode)mode
                    withType:(SYDeviceType)type
           withSessionPreset:(AVCaptureSessionPreset)sessionPreset
                withPosition:(AVCaptureDevicePosition)devicePosition
{
    self = [super init];
    if (self) {
        self.mode = mode;
        self.type = type;
        self.sessionPreset = sessionPreset;
        self.devicePosition = devicePosition;
    }
    return self;
}



@end
