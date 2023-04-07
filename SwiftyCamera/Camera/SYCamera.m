//
//  SYCamera.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2023/4/6.
//

#import "SYCamera.h"

typedef struct SYCameraDelegateCache {
    unsigned int diplayOutputSampleBuffer : 1;
    unsigned int captureOutputSampleBuffer : 1;
    unsigned int changedPosition : 1;
    unsigned int changedFocus : 1;
    unsigned int changedZoom : 1;
    unsigned int changedExposure : 1;
    unsigned int changedFlash : 1;
    unsigned int changedEV : 1;
    unsigned int willCapture : 1;
} SYCameraDelegateCache;

@interface SYCamera () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate>

@end

@implementation SYCamera

@end
