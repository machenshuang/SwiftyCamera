//
//  SYMultiCamera.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/7/1.
//

#import "SYMultiCamera.h"
#import "SYLog.h"

static NSString *TAG = @"SYMultiCamera";

@interface SYMultiCamera ()
{
    AVCaptureDevice *_frontDevice;
    AVCaptureDevice *_backDevice;
    AVCaptureDeviceInput *_frontVideoInput;
    AVCaptureDeviceInput *_backVideoInput;
    AVCaptureVideoDataOutput *_frontVideoOutput;
    AVCaptureVideoDataOutput *_backVideoOutput;
    AVCapturePhotoOutput *_frontPhotoOutput;
    AVCapturePhotoOutput *_backPhotoOutput;
}

@end

@implementation SYMultiCamera

- (void)dealloc
{
    [_frontVideoOutput setSampleBufferDelegate:nil queue:nil];
    [_backVideoOutput setSampleBufferDelegate:nil queue:nil];
}

- (void)createCaptureSession
{
    self.session = [[AVCaptureMultiCamSession alloc] init];
    
}

- (BOOL)configureCameraDevice
{
    SYLog(TAG, "configureCameraDevice");
    _frontDevice = [self fetchCameraDeviceWithPosition:AVCaptureDevicePositionFront];
    _backDevice = [self fetchCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (_frontDevice && _backDevice) {
        return YES;
    } else {
        return NO;
    }
}

- (void)configureVideoDeviceInput
{
    SYLog(TAG, "configureVideoDeviceInput");
    
    NSError *error = nil;
    AVCaptureDeviceInput *frontVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_frontDevice error:&error];
    
    if (error) {
        SYLog(TAG, "configureVideoDeviceInput initWithDevice frontVideoInput failure，error = %@", error.description);
        return;
    }
    
    AVCaptureDeviceInput *backVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_backDevice error:&error];
    
    if (error) {
        SYLog(TAG, "configureVideoDeviceInput initWithDevice backVideoInput failure，error = %@", error.description);
        return;
    }
    
    if (_frontVideoInput) {
        [self.session removeInput:_frontVideoInput];
    }
    
    if ([self.session canAddInput:frontVideoInput]) {
        [self.session addInputWithNoConnections:frontVideoInput];
        _frontVideoInput = frontVideoInput;
    } else {
        if (frontVideoInput) {
            [self.session addInputWithNoConnections:_frontVideoInput];
        }
        SYLog(TAG, "configureVideoDeviceInput addFrontInput failure");
    }
    
    if (_backVideoInput) {
        [self.session removeInput:_backVideoInput];
    }
    
    if ([self.session canAddInput:backVideoInput]) {
        [self.session addInputWithNoConnections:backVideoInput];
        _backVideoInput = backVideoInput;
    } else {
        if (backVideoInput) {
            [self.session addInput:_backVideoInput];
        }
        SYLog(TAG, "configureVideoDeviceInput addBackInput failure");
    }
}

- (void)configureVideoOutput
{
    SYLog(TAG, "configureVideoOutput");
    
    AVCaptureInputPort *frontDeviceVideoPort = [[_frontVideoInput portsWithMediaType:AVMediaTypeVideo sourceDeviceType:_frontDevice.deviceType sourceDevicePosition:_frontDevice.position] firstObject];
    AVCaptureInputPort *backDeviceVideoPort = [[_backVideoInput portsWithMediaType:AVMediaTypeVideo sourceDeviceType:_backDevice.deviceType sourceDevicePosition:_backDevice.position] firstObject];
    
    if (frontDeviceVideoPort == nil || backDeviceVideoPort == nil) {
        SYLog(TAG, "configureVideoOutput input port is nil");
    }
    
    if (_frontVideoOutput == nil) {
        _frontVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_frontVideoOutput setAlwaysDiscardsLateVideoFrames:NO];
        [_frontVideoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        [_frontVideoOutput setSampleBufferDelegate:self queue:self.cameraProcessQueue];
        if ([self.session canAddOutput:_frontVideoOutput]) {
            [self.session addOutputWithNoConnections:_frontVideoOutput];
        } else {
            SYLog(TAG, "configureVideoOutput addFrontOutput failure");
        }
        
        AVCaptureConnection *frontInputConnection = [[AVCaptureConnection alloc] initWithInputPorts:@[frontDeviceVideoPort] output:_frontVideoOutput];
        if ([self.session canAddConnection:frontInputConnection]) {
            [self.session addConnection:frontInputConnection];
            [frontInputConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            [frontInputConnection setAutomaticallyAdjustsVideoMirroring:NO];
            [frontInputConnection setVideoMirrored:YES];
        } else {
            SYLog(TAG, "configureVideoOutput addFrontConnection failure");
        }
        
        if (self.delegateMap.getVideoPreviewLayerForPosition) {
            AVCaptureVideoPreviewLayer *layer = [self.delegate getVideoPreviewLayerForPosition:AVCaptureDevicePositionFront];
            AVCaptureConnection *frontVideoPreviewLayerConnection = [[AVCaptureConnection alloc] initWithInputPort:frontDeviceVideoPort videoPreviewLayer:layer];
            if ([self.session canAddConnection:frontVideoPreviewLayerConnection]) {
                [self.session addConnection:frontVideoPreviewLayerConnection];
            } else {
                SYLog(TAG, "configureVideoOutput addFrontPreviewConnection failure");
            }
        }
        
    }
    
    if (_backVideoOutput == nil) {
        _backVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_backVideoOutput setAlwaysDiscardsLateVideoFrames:NO];
        [_backVideoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        [_backVideoOutput setSampleBufferDelegate:self queue:self.cameraProcessQueue];
        if ([self.session canAddOutput:_backVideoOutput]) {
            [self.session addOutputWithNoConnections:_backVideoOutput];
        } else {
            SYLog(TAG, "configureVideoOutput addFrontOutput failure");
        }
        
        AVCaptureConnection *backInputConnection = [[AVCaptureConnection alloc] initWithInputPorts:@[backDeviceVideoPort] output:_backVideoOutput];
        if ([self.session canAddConnection:backInputConnection]) {
            [self.session addConnection:backInputConnection];
            [backInputConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
        } else {
            SYLog(TAG, "configureVideoOutput addBackConnection failure");
        }
        
        if (self.delegateMap.getVideoPreviewLayerForPosition) {
            AVCaptureVideoPreviewLayer *layer = [self.delegate getVideoPreviewLayerForPosition:AVCaptureDevicePositionBack];
            AVCaptureConnection *backVideoPreviewLayerConnection = [[AVCaptureConnection alloc] initWithInputPort:backDeviceVideoPort videoPreviewLayer:layer];
            if ([self.session canAddConnection:backVideoPreviewLayerConnection]) {
                [self.session addConnection:backVideoPreviewLayerConnection];
            } else {
                SYLog(TAG, "configureVideoOutput addBackPreviewConnection failure");
            }
        }
    }
}

- (void)configurePhotoOutput
{
    SYLog(TAG, "configurePhotoOutput");
    if (_frontPhotoOutput == nil) {
        _frontPhotoOutput = [AVCapturePhotoOutput new];
        [_frontPhotoOutput setHighResolutionCaptureEnabled:YES];
        if ([self.session canAddOutput:_frontPhotoOutput]) {
            [self.session addOutput:_frontPhotoOutput];
        } else {
            SYLog(TAG, "configurePhotoOutput addFrontOutput failure");
        }
    }
    
    if (_backPhotoOutput == nil) {
        _backPhotoOutput = [AVCapturePhotoOutput new];
        [_backPhotoOutput setHighResolutionCaptureEnabled:YES];
        if ([self.session canAddOutput:_backPhotoOutput]) {
            [self.session addOutput:_backPhotoOutput];
        } else {
            SYLog(TAG, "configurePhotoOutput addBackOutput failure");
        }
    }
}

- (void)takePhoto
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(self.captureQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (strongSelf.mode != SYPhotoMode) {
            SYLog(TAG, "takePhoto 非拍照模式");
            return;
        }
        
        NSDictionary *dict = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
        AVCapturePhotoSettings *setting = [AVCapturePhotoSettings photoSettingsWithFormat:dict];
        
        // 设置高清晰
        [setting setHighResolutionPhotoEnabled:YES];
        // 防抖
        [setting setAutoStillImageStabilizationEnabled:YES];
        
        if ([strongSelf->_frontDevice hasFlash]) {
            [setting setFlashMode:strongSelf.flashMode];
        }
        
        if (@available(iOS 13.0, *)) {
            [setting setPhotoQualityPrioritization:AVCapturePhotoQualityPrioritizationBalanced];
        }
        
        AVCaptureConnection *frontPhotoOutputConnection = [self->_frontPhotoOutput connectionWithMediaType:AVMediaTypeVideo];
        if (frontPhotoOutputConnection) {
            frontPhotoOutputConnection.videoMirrored = YES;
        }
        [strongSelf->_frontPhotoOutput capturePhotoWithSettings:setting delegate:self];
        
        AVCaptureConnection *backPhotoOutputConnection = [self->_backPhotoOutput connectionWithMediaType:AVMediaTypeVideo];
        [strongSelf->_backPhotoOutput capturePhotoWithSettings:setting delegate:self];
    });
}

@end
