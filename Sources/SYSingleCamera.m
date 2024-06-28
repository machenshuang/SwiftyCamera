//
//  SYSingleCamera.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/28.
//

#import "SYSingleCamera.h"
#import "SYLog.h"

static NSString *TAG = @"SYSingleCamera";

@interface SYSingleCamera ()
{
    AVCaptureDevice *_inputCamera;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoDataOutput *_videoOutput;
    AVCapturePhotoOutput *_photoOutput;
}

@end

@implementation SYSingleCamera

- (void)dealloc
{
    [_videoOutput setSampleBufferDelegate:nil queue:nil];
}

- (void)createCaptureSession
{
    self.session = [[AVCaptureSession alloc] init];
}

- (BOOL)configureCameraDevice
{
    SYLog(TAG, "configureCameraDevice");
    _inputCamera = [self fetchCameraDeviceWithPosition:self.cameraPosition];
    return _inputCamera != nil;
}

- (void)configureVideoDeviceInput
{
    SYLog(TAG, "configureVideoDeviceInput");
    if (_videoInput != nil &&_inputCamera != nil && _videoInput.device == _inputCamera) {
        SYLog(TAG, "configureVideoDeviceInput _videoInput.device == _inputCamera");
        return;
    }
    
    NSError *error = nil;
    // 添加 input
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_inputCamera error:&error];
    
    if (error) {
        SYLog(TAG, "configureVideoDeviceInput initWithDevice failure，error = %@", error.description);
        return;
    }
    
    if (_videoInput) {
        [self.session removeInput:_videoInput];
    }
    if ([self.session canAddInput:videoInput]) {
        [self.session addInput:videoInput];
        _videoInput = videoInput;
    } else {
        if (_videoInput) {
            [self.session addInput:_videoInput];
        }
        SYLog(TAG, "configureVideoDeviceInput addInput failure");
    }
}

- (void)configureVideoOutput
{
    SYLog(TAG, "configureVideoOutput");
    if (_videoOutput == nil) {
        _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_videoOutput setAlwaysDiscardsLateVideoFrames:NO];
        [_videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        [_videoOutput setSampleBufferDelegate:self queue:self.cameraProcessQueue];
        if ([self.session canAddOutput:_videoOutput]) {
            [self.session addOutput:_videoOutput];
        } else {
            SYLog(TAG, "configureVideoOutput addOutput failure");
        }
    }
    
    for (AVCaptureConnection *connect in _videoOutput.connections) {
        if ([connect isVideoMirroringSupported]) {
            [connect setVideoMirrored: self.cameraPosition == AVCaptureDevicePositionFront ? YES : NO];
        }
        if ([connect isVideoOrientationSupported]) {
            [connect setVideoOrientation: AVCaptureVideoOrientationPortrait];
        }
    }
}

- (void)configurePhotoOutput
{
    SYLog(TAG, "configurePhotoOutput");
    if (_photoOutput == nil) {
        _photoOutput = [AVCapturePhotoOutput new];
        [_photoOutput setHighResolutionCaptureEnabled:YES];
        if ([self.session canAddOutput:_photoOutput]) {
            [self.session addOutput:_photoOutput];
        } else {
            SYLog(TAG, "configurePhotoOutput addOutput failure");
        }
    }
}

- (void)focusWithPoint:(CGPoint)point mode:(AVCaptureFocusMode)mode
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        NSError *error;
        [strongSelf->_inputCamera lockForConfiguration:&error];
        if (error != nil) {
            [strongSelf->_inputCamera unlockForConfiguration];
            SYLog(TAG, "focusWithPoint failure error = %@", error.description);
            return;
        }
        if ([strongSelf->_inputCamera isFocusModeSupported:mode]) {
            [strongSelf->_inputCamera setFocusPointOfInterest:point];
            [strongSelf->_inputCamera setFocusMode:mode];
        }
        [strongSelf->_inputCamera unlockForConfiguration];
        if (strongSelf.delegateMap.changedFocus) {
            [strongSelf.delegate cameraDidChangeFocus:point mode:mode];
        }
    });
}

- (void)exposureWithPoint:(CGPoint)point mode:(AVCaptureExposureMode)mode
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        NSError *error;
        [strongSelf->_inputCamera lockForConfiguration:&error];
        if (error != nil) {
            [strongSelf->_inputCamera unlockForConfiguration];
            SYLog(TAG, "exposureWithPoint failure error = %@", error.description);
            return;
        }
        [strongSelf->_inputCamera setExposurePointOfInterest:point];
        [strongSelf->_inputCamera setExposureMode:mode];
        [strongSelf->_inputCamera unlockForConfiguration];
        if (strongSelf.delegateMap.changedExposure) {
            [strongSelf.delegate cameraDidChangeExposure:point mode:mode];
        }
    });
}

- (void)setEv:(CGFloat)value
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        NSError *error;
        [strongSelf->_inputCamera lockForConfiguration:&error];
        if (error != nil) {
            [strongSelf->_inputCamera unlockForConfiguration];
            SYLog(TAG, "setEv failure error = %@", error.description);
            return;
        }
        CGFloat maxEV = 3.0;
        CGFloat minEV = -3.0;
        CGFloat current = (maxEV - minEV) * value + minEV;
        [super setEv:value];
        [strongSelf->_inputCamera setExposureTargetBias:(float)current completionHandler:nil];
        [strongSelf->_inputCamera unlockForConfiguration];
        if (strongSelf.delegateMap.changedEV) {
            [strongSelf.delegate cameraDidChangeEV:value];
        }
    });
}

- (void)setZoom:(CGFloat)zoom withAnimated:(BOOL)animated
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(self.sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        CGFloat value = zoom;
        if (@available(iOS 13.0, *)) {
            if (strongSelf->_inputCamera.deviceType == AVCaptureDeviceTypeBuiltInTripleCamera || strongSelf->_inputCamera.deviceType == AVCaptureDeviceTypeBuiltInDualWideCamera) {
                value *= 2;
            }
        }
        if (value < 1.0 || value > [strongSelf maxZoom]) {
            SYLog(TAG, "setZoom failure value = %f，maxZoom = %f", value, [strongSelf maxZoom]);
            return;
        }
        if (value == [strongSelf zoom]) {
            SYLog(TAG, "setZoom value equal to current");
            return;
        }
        
        NSError *error;
        [strongSelf->_inputCamera lockForConfiguration:&error];
        if (error != nil) {
            [strongSelf->_inputCamera unlockForConfiguration];
            SYLog(TAG, "setZoom failure error = %@", error.description);
            return;
        }
        if (animated) {
            [strongSelf->_inputCamera rampToVideoZoomFactor:value withRate:50];
        } else {
            [strongSelf->_inputCamera setVideoZoomFactor:value];
        }
        [strongSelf->_inputCamera unlockForConfiguration];
        if (strongSelf.delegateMap.changedZoom) {
            [strongSelf.delegate cameraDidChangeZoom:value];
        }
    });
}

- (CGFloat)zoom
{
    if (@available(iOS 13.0, *)) {
        if (_inputCamera.deviceType == AVCaptureDeviceTypeBuiltInTripleCamera || _inputCamera.deviceType == AVCaptureDeviceTypeBuiltInDualWideCamera) {
            return _inputCamera.videoZoomFactor / 2.0;
        }
    }
    return _inputCamera.videoZoomFactor;
}

- (CGFloat)maxZoom
{
    if (@available(iOS 13.0, *)) {
        if (_inputCamera.deviceType == AVCaptureDeviceTypeBuiltInTripleCamera || _inputCamera.deviceType == AVCaptureDeviceTypeBuiltInDualWideCamera) {
            return _inputCamera.maxAvailableVideoZoomFactor / 2.0;
        }
    }
    return _inputCamera.maxAvailableVideoZoomFactor;
}

- (CGFloat)minZoom {
    if (@available(iOS 13.0, *)) {
        if (_inputCamera.deviceType == AVCaptureDeviceTypeBuiltInTripleCamera || _inputCamera.deviceType == AVCaptureDeviceTypeBuiltInDualWideCamera) {
            return _inputCamera.minAvailableVideoZoomFactor / 2.0;
        }
    }
    return _inputCamera.minAvailableVideoZoomFactor;
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
        
        AVCaptureConnection *photoOutputConnection = [self->_photoOutput connectionWithMediaType:AVMediaTypeVideo];
        if (photoOutputConnection) {
            photoOutputConnection.videoMirrored = self.cameraPosition == AVCaptureDevicePositionFront;
        }
        
        if ([strongSelf->_inputCamera hasFlash]) {
            [setting setFlashMode:strongSelf.flashMode];
        }
        
        if (@available(iOS 13.0, *)) {
            [setting setPhotoQualityPrioritization:AVCapturePhotoQualityPrioritizationBalanced];
        }
        
        [strongSelf->_photoOutput capturePhotoWithSettings:setting delegate:self];
    });
}


@end
