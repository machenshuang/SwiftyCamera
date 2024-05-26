//
//  SYPreviewView.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/5/25.
//

#import "SYPreviewView.h"

@interface SYPreviewView ()

@property (nonnull, nonatomic, copy, readwrite) AVCaptureVideoPreviewLayer *previewLayer;

@end

@implementation SYPreviewView

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    }
    return self;
}

+ (Class)layerClass
{
    return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer *)previewLayer
{
    return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (void)setSession:(AVCaptureSession *)session
{
    self.previewLayer.session = session;
}

- (AVCaptureSession *)session
{
    return self.previewLayer.session;
}




@end
