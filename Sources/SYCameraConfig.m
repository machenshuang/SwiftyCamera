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
    self = [self initWithMode:SYPhotoMode withPosition:AVCaptureDevicePositionBack];
    return self;
}

- (instancetype)initWithMode:(SYCameraMode)mode
                withPosition:(AVCaptureDevicePosition)devicePosition
{
    self = [self initWithMode:mode withType:SYSingleDevice withPosition:devicePosition];
    return self;
}

- (instancetype)initWithMode:(SYCameraMode)mode
                    withType:(SYDeviceType)type
                withPosition:(AVCaptureDevicePosition)devicePosition
{
    self = [super init];
    if (self) {
        self.mode = mode;
        self.type = type;
        self.devicePosition = devicePosition;
    }
    return self;
}



@end
