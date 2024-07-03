//
//  SYMultiCamera.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/7/1.
//

#import "SYMultiCamera.h"
#import "SYLog.h"

static NSString *TAG = @"SYMultiCamera";

@interface SYMultiCamera () {
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

- (void)dealloc {
    [_frontVideoOutput setSampleBufferDelegate:nil queue:nil];
    [_backVideoOutput setSampleBufferDelegate:nil queue:nil];
}

- (void)setupCaptureSession {
    self.session = [[AVCaptureMultiCamSession alloc] init];
    if (self.delegateMap.getVideoPreviewForPosition) {
        SYPreviewView *backView = [self.delegate getVideoPreviewForPosition:AVCaptureDevicePositionBack];
        SYPreviewView *frontView = [self.delegate getVideoPreviewForPosition:AVCaptureDevicePositionFront];
        
        [backView.previewLayer setSessionWithNoConnection:self.session];
        [frontView.previewLayer setSessionWithNoConnection:self.session];
    }
    
}

- (BOOL)setupCameraDevice {
    SYLog(TAG, "setupCameraDevice");
    _frontDevice = [self fetchCameraDeviceWithPosition:AVCaptureDevicePositionFront];
    _backDevice = [self fetchCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    if (_frontDevice && _backDevice) {
        return YES;
    } else {
        return NO;
    }
}

- (void)setupVideoDeviceInput {
    SYLog(TAG, "setupVideoDeviceInput");
    
    NSError *error = nil;
    AVCaptureDeviceInput *frontVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_frontDevice error:&error];
    
    if (error) {
        SYLog(TAG, "setupVideoDeviceInput initWithDevice frontVideoInput failure，error = %@", error.description);
        if (self.delegateMap.cameraSessionSetupResult) {
            [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
        }
        return;
    }
    
    AVCaptureDeviceInput *backVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_backDevice error:&error];
    
    if (error) {
        SYLog(TAG, "setupVideoDeviceInput initWithDevice backVideoInput failure，error = %@", error.description);
        if (self.delegateMap.cameraSessionSetupResult) {
            [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
        }
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
        } else {
            if (self.delegateMap.cameraSessionSetupResult) {
                [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
            }
        }
        SYLog(TAG, "setupVideoDeviceInput addFrontInput failure");
    }
    
    if (_backVideoInput) {
        [self.session removeInput:_backVideoInput];
    }
    
    if ([self.session canAddInput:backVideoInput]) {
        [self.session addInputWithNoConnections:backVideoInput];
        _backVideoInput = backVideoInput;
    } else {
        if (_backVideoInput) {
            [self.session addInput:_backVideoInput];
        } else {
            if (self.delegateMap.cameraSessionSetupResult) {
                [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
            }
        }
        SYLog(TAG, "setupVideoDeviceInput addBackInput failure");
    }
}

- (void)setupVideoOutput {
    SYLog(TAG, "setupVideoOutput");
    
    AVCaptureInputPort *frontDeviceVideoPort = [[_frontVideoInput portsWithMediaType:AVMediaTypeVideo sourceDeviceType:_frontDevice.deviceType sourceDevicePosition:_frontDevice.position] firstObject];
    AVCaptureInputPort *backDeviceVideoPort = [[_backVideoInput portsWithMediaType:AVMediaTypeVideo sourceDeviceType:_backDevice.deviceType sourceDevicePosition:_backDevice.position] firstObject];
    
    if (frontDeviceVideoPort == nil || backDeviceVideoPort == nil) {
        SYLog(TAG, "setupVideoOutput input port is nil");
        if (self.delegateMap.cameraSessionSetupResult) {
            [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
        }
    }
    
    if (_frontVideoOutput == nil) {
        _frontVideoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_frontVideoOutput setAlwaysDiscardsLateVideoFrames:NO];
        [_frontVideoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        [_frontVideoOutput setSampleBufferDelegate:self queue:self.cameraProcessQueue];
        if ([self.session canAddOutput:_frontVideoOutput]) {
            [self.session addOutputWithNoConnections:_frontVideoOutput];
        } else {
            SYLog(TAG, "setupVideoOutput addFrontOutput failure");
            if (self.delegateMap.cameraSessionSetupResult) {
                [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
            }
        }
        
        AVCaptureConnection *frontInputConnection = [[AVCaptureConnection alloc] initWithInputPorts:@[frontDeviceVideoPort] output:_frontVideoOutput];
        if ([self.session canAddConnection:frontInputConnection]) {
            [self.session addConnection:frontInputConnection];
            [frontInputConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
            [frontInputConnection setAutomaticallyAdjustsVideoMirroring:NO];
            [frontInputConnection setVideoMirrored:YES];
        } else {
            SYLog(TAG, "setupVideoOutput addFrontConnection failure");
            if (self.delegateMap.cameraSessionSetupResult) {
                [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
            }
        }
        
        if (self.delegateMap.getVideoPreviewForPosition) {
            __block AVCaptureConnection *frontVideoPreviewLayerConnection;
            __weak typeof(self) weakSelf = self;
            dispatch_sync(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                AVCaptureVideoPreviewLayer *layer = [strongSelf.delegate getVideoPreviewForPosition:AVCaptureDevicePositionFront].previewLayer;
                frontVideoPreviewLayerConnection = [[AVCaptureConnection alloc] initWithInputPort:frontDeviceVideoPort videoPreviewLayer:layer];
            });
            if ([self.session canAddConnection:frontVideoPreviewLayerConnection]) {
                [self.session addConnection:frontVideoPreviewLayerConnection];
            } else {
                SYLog(TAG, "setupVideoOutput addFrontPreviewConnection failure");
                if (self.delegateMap.cameraSessionSetupResult) {
                    [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
                }
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
            SYLog(TAG, "setupVideoOutput addFrontOutput failure");
            if (self.delegateMap.cameraSessionSetupResult) {
                [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
            }
        }
        
        AVCaptureConnection *backInputConnection = [[AVCaptureConnection alloc] initWithInputPorts:@[backDeviceVideoPort] output:_backVideoOutput];
        if ([self.session canAddConnection:backInputConnection]) {
            [self.session addConnection:backInputConnection];
            [backInputConnection setVideoOrientation:AVCaptureVideoOrientationPortrait];
        } else {
            SYLog(TAG, "setupVideoOutput addBackConnection failure");
            if (self.delegateMap.cameraSessionSetupResult) {
                [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
            }
        }
        
        if (self.delegateMap.getVideoPreviewForPosition) {
            __block AVCaptureConnection *backVideoPreviewLayerConnection;
            __weak typeof(self) weakSelf = self;
            dispatch_sync(dispatch_get_main_queue(), ^{
                __strong typeof(weakSelf) strongSelf = weakSelf;
                AVCaptureVideoPreviewLayer *layer = [strongSelf.delegate getVideoPreviewForPosition:AVCaptureDevicePositionBack].previewLayer;
                backVideoPreviewLayerConnection = [[AVCaptureConnection alloc] initWithInputPort:backDeviceVideoPort videoPreviewLayer:layer];
            });
            if ([self.session canAddConnection:backVideoPreviewLayerConnection]) {
                [self.session addConnection:backVideoPreviewLayerConnection];
            } else {
                SYLog(TAG, "setupVideoOutput addBackPreviewConnection failure");
                if (self.delegateMap.cameraSessionSetupResult) {
                    [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
                }
            }
        }
    }
}

- (void)setupPhotoOutput {
    SYLog(TAG, "setupPhotoOutput");
    if (_frontPhotoOutput == nil) {
        _frontPhotoOutput = [AVCapturePhotoOutput new];
        [_frontPhotoOutput setHighResolutionCaptureEnabled:YES];
        if ([self.session canAddOutput:_frontPhotoOutput]) {
            [self.session addOutput:_frontPhotoOutput];
        } else {
            SYLog(TAG, "setupPhotoOutput addFrontOutput failure");
            if (self.delegateMap.cameraSessionSetupResult) {
                [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
            }
        }
    }
    
    if (_backPhotoOutput == nil) {
        _backPhotoOutput = [AVCapturePhotoOutput new];
        [_backPhotoOutput setHighResolutionCaptureEnabled:YES];
        if ([self.session canAddOutput:_backPhotoOutput]) {
            [self.session addOutput:_backPhotoOutput];
        } else {
            SYLog(TAG, "setupPhotoOutput addBackOutput failure");
            if (self.delegateMap.cameraSessionSetupResult) {
                [self.delegate cameraSessionSetupResult:SYSessionSetupConfigurationFailed];
            }
        }
    }
}

- (void)takePhoto {
    __weak typeof(self)weakSelf = self;
    dispatch_async(self.captureQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (strongSelf.mode != SYPhotoMode) {
            SYLog(TAG, "takePhoto 非拍照模式");
            return;
        }
        
        if (strongSelf.cameraPosition == AVCaptureDevicePositionBack) {
            [strongSelf takeBackCameraPhoto];
        } else if (strongSelf.cameraPosition == AVCaptureDevicePositionFront) {
            [strongSelf takeFrontCameraPhoto];
        }
    });
}

- (void)takeFrontCameraPhoto {
    NSDictionary *dict = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    AVCapturePhotoSettings *setting = [AVCapturePhotoSettings photoSettingsWithFormat:dict];
    
    // 设置高清晰
    [setting setHighResolutionPhotoEnabled:YES];
    
    if ([self->_frontDevice hasFlash]) {
        [setting setFlashMode:self.flashMode];
    }
    
    AVCaptureConnection *frontPhotoOutputConnection = [self->_frontPhotoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (frontPhotoOutputConnection) {
        frontPhotoOutputConnection.videoMirrored = YES;
    }
    [self->_frontPhotoOutput capturePhotoWithSettings:setting delegate:self];
}

- (void)takeBackCameraPhoto {
    NSDictionary *dict = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    AVCapturePhotoSettings *setting = [AVCapturePhotoSettings photoSettingsWithFormat:dict];
    
    // 设置高清晰
    [setting setHighResolutionPhotoEnabled:YES];
    
    if ([self->_backDevice hasFlash]) {
        [setting setFlashMode:self.flashMode];
    }
    
    [self->_backPhotoOutput capturePhotoWithSettings:setting delegate:self];
}


- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error {
    if (!self.delegateMap.cameraDidFinishProcessingPhoto) {
        return;
    }
    
    if (output == _frontPhotoOutput) {
        [self.delegate cameraDidFinishProcessingPhoto:photo withPosition:AVCaptureDevicePositionFront error:error];
        if (self.cameraPosition == AVCaptureDevicePositionFront) {
            [self takeBackCameraPhoto];
        }
    } else if (output == _backPhotoOutput) {
        [self.delegate cameraDidFinishProcessingPhoto:photo withPosition:AVCaptureDevicePositionBack error:error];
        if (self.cameraPosition == AVCaptureDevicePositionBack) {
            [self takeFrontCameraPhoto];
        }
    }
}



@end
