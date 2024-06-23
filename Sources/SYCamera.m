//
//  SYCamera.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2023/4/6.
//

#import "SYCamera.h"

typedef struct SYCameraDelegateCache {
    unsigned int cameraDidStarted : 1;
    unsigned int cameraDidStoped : 1;
    unsigned int cameraDidOutputSampleBuffer : 1;
    unsigned int cameraDidFinishProcessingPhoto : 1;
    unsigned int changedPosition : 1;
    unsigned int changedFocus : 1;
    unsigned int changedZoom : 1;
    unsigned int changedExposure : 1;
    unsigned int changedFlash : 1;
    unsigned int changedEV : 1;
    unsigned int cameraWillCacpturePhoto : 1;
    unsigned int cameraDidChangeMode: 1;
} SYCameraDelegateCache;

@interface SYCamera () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate>
{
    AVCaptureDevice *_inputCamera;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureDeviceInput *_audioInput;
    AVCaptureVideoDataOutput *_videoOutput;
    AVCapturePhotoOutput *_photoOutput;
    
    dispatch_queue_t _sessionQueue;
    dispatch_queue_t _cameraProcessQueue;
    dispatch_queue_t _captureQueue;
    
    SYCameraDelegateCache _delegateCache;
}

@end


@implementation SYCamera

@synthesize session = _session;
@synthesize cameraPosition = _cameraPosition;
@synthesize mode = _mode;

- (instancetype)initWithSessionPreset:(AVCaptureSessionPreset)sessionPreset
                       cameraPosition:(AVCaptureDevicePosition)cameraPosition
                             withMode:(SYCameraMode)mode;
{
    self = [super init];
    if (self) {
        _ev = 0.5;
        _sessionQueue = dispatch_queue_create("com.machenshuang.camera.AVCameraSessionQueue", DISPATCH_QUEUE_SERIAL);
        _cameraProcessQueue = dispatch_queue_create("com.machenshuang.camera.AVCameraCameraProcessingQueue", DISPATCH_QUEUE_SERIAL);
        _captureQueue = dispatch_queue_create("com.machenshuang.camera.AVCameraCaptureQueue", DISPATCH_QUEUE_SERIAL);
        
        _inputCamera = [self fetchCameraDeviceWithPosition:cameraPosition];

        if (!_inputCamera) {
            return nil;
        }
        _cameraPosition = cameraPosition;
        _mode = mode;
        _session = [[AVCaptureSession alloc] init];
        __weak typeof(self)weakSelf = self;
        dispatch_async(_sessionQueue, ^{
            __strong typeof(weakSelf)strongSelf = weakSelf;
            [strongSelf configureSesson: sessionPreset];
        });
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCaptureSessionNotification:)
                                                     name:nil
                                                   object:_session];
    }
    return self;
}

- (void)dealloc
{
    [_videoOutput setSampleBufferDelegate:nil queue:nil];
}

- (AVCaptureDevice *)fetchCameraDeviceWithPosition:(AVCaptureDevicePosition)position
{
    AVCaptureDevice *device;
    if (position == AVCaptureDevicePositionBack) {
        NSArray *deviceType;
        if (_mode == SKElectronicScreen) {
            deviceType = @[AVCaptureDeviceTypeBuiltInWideAngleCamera];
        } else {
            if (@available(iOS 13.0, *)) {
                deviceType = @[AVCaptureDeviceTypeBuiltInTripleCamera, AVCaptureDeviceTypeBuiltInDualWideCamera, AVCaptureDeviceTypeBuiltInWideAngleCamera];
            } else {
                deviceType = @[AVCaptureDeviceTypeBuiltInDualCamera, AVCaptureDeviceTypeBuiltInWideAngleCamera];
            }
        }
        
        AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceType mediaType:AVMediaTypeVideo position:position];
        device = deviceSession.devices.firstObject;
    } else  {
        AVCaptureDevice *frontDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:position];
        device = frontDevice;
    }
    return device;
}


- (void)setDelegate:(id<SYCameraDelegate>)delegate
{
    _delegate = delegate;
    _delegateCache.cameraDidStarted = [delegate respondsToSelector:@selector(cameraDidStarted:)];
    _delegateCache.cameraDidStoped = [delegate respondsToSelector:@selector(cameraDidStoped:)];
    _delegateCache.cameraDidOutputSampleBuffer = [delegate respondsToSelector:@selector(cameraDidOutputSampleBuffer:)];
    _delegateCache.cameraDidFinishProcessingPhoto = [delegate respondsToSelector:@selector(cameraDidFinishProcessingPhoto:error:)];
    _delegateCache.changedPosition = [delegate respondsToSelector:@selector(cameraDidChangePosition:error:)];
    _delegateCache.changedFocus = [delegate respondsToSelector:@selector(cameraDidChangeFocus:mode:error:)];
    _delegateCache.changedZoom = [delegate respondsToSelector:@selector(cameraDidChangeZoom:error:)];
    _delegateCache.changedExposure = [delegate respondsToSelector:@selector(cameraDidChangeExposure:mode:error:)];
    _delegateCache.changedFlash = [delegate respondsToSelector:@selector(camerahDidChangeFlash:error:)];
    _delegateCache.changedEV = [delegate respondsToSelector:@selector(cameraDidChangeEV:error:)];
    _delegateCache.cameraWillCacpturePhoto = [delegate respondsToSelector:@selector(cameraWillCapturePhoto)];
    _delegateCache.cameraDidChangeMode = [delegate respondsToSelector:@selector(cameraDidChangeMode:error:)];
}

- (void)changeCameraMode:(SYCameraMode)mode
       withSessionPreset:(AVCaptureSessionPreset)sessionPreset
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf->_mode == mode) {
            if (strongSelf->_delegateCache.cameraDidChangeMode) {
                [strongSelf.delegate cameraDidChangeMode:mode error:nil];
            }
            return;
        }
        strongSelf->_mode = mode;
        [strongSelf configureSesson:sessionPreset];
        if (strongSelf->_delegateCache.cameraDidChangeMode) {
            [strongSelf.delegate cameraDidChangeMode:mode error:nil];
        }
    });
}

- (void)configureSesson:(AVCaptureSessionPreset)sessionPreset
{
    [_session beginConfiguration];
    [self configureVideoDeviceInput];
    [self configureAudioDeviceInput];
    [self configureVideoOutput];
    [self configurePhotoOutput];
    
    [_session setSessionPreset:sessionPreset];
    [_session commitConfiguration];
    [self exposureWithPoint:CGPointMake(0.5, 0.5) mode:AVCaptureExposureModeAutoExpose];
    [self setZoom:1.0];
}

- (void)configureVideoDeviceInput
{
    if (_videoInput != nil &&_inputCamera != nil && _videoInput.device == _inputCamera) {
        return;
    }
    
    NSError *error = nil;
    // 添加 input
    AVCaptureDeviceInput *videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_inputCamera error:&error];
    if (_videoInput) {
        [_session removeInput:_videoInput];
    }
    if ([_session canAddInput:videoInput]) {
        [_session addInput:videoInput];
        _videoInput = videoInput;
    } else {
        if (_videoInput) {
            [_session addInput:_videoInput];
        }
    }
}

- (void)configureAudioDeviceInput
{
    NSError *error = nil;
    if (_mode == SKPhotoMode) {
        if (_audioInput) {
            [_session removeInput:_audioInput];
            _audioInput = nil;
        }
    } else {
        if (_audioInput == nil) {
            AVCaptureDevice* audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            AVCaptureDeviceInput* audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
            if ([_session canAddInput:audioDeviceInput]) {
                [_session addInput:audioDeviceInput];
                _audioInput = audioDeviceInput;
            }
        }
    }
}

- (void)configureVideoOutput
{
    if (_videoOutput == nil) {
        _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_videoOutput setAlwaysDiscardsLateVideoFrames:NO];
        [_videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
        [_videoOutput setSampleBufferDelegate:self queue:_cameraProcessQueue];
        if ([_session canAddOutput:_videoOutput]) {
            [_session addOutput:_videoOutput];
        }
    }
    
    for (AVCaptureConnection *connect in _videoOutput.connections) {
        if ([connect isVideoMirroringSupported]) {
            [connect setVideoMirrored: _cameraPosition == AVCaptureDevicePositionFront ? YES : NO];
        }
        if ([connect isVideoOrientationSupported]) {
            [connect setVideoOrientation: AVCaptureVideoOrientationPortrait];
        }
    }
}

- (void)configurePhotoOutput
{
    if (_mode == SKVideoMode) {
        if (_photoOutput) {
            [_session removeOutput:_photoOutput];
            _photoOutput = nil;
        }
    } else {
        if (_photoOutput == nil) {
            _photoOutput = [AVCapturePhotoOutput new];
            [_photoOutput setHighResolutionCaptureEnabled:YES];
            if ([_session canAddOutput:_photoOutput]) {
                [_session addOutput:_photoOutput];
            }
        }
    }
    
}


- (void)startCapture
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        if (![strongSelf->_session isRunning]) {
            [strongSelf->_session startRunning];
        }
        if (strongSelf->_delegate) {
            [strongSelf->_delegate cameraDidStarted:nil];
        }
    });
}

- (void)stopCapture
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        if ([strongSelf->_session isRunning]) {
            [strongSelf->_session stopRunning];
        }
        if (strongSelf->_delegate) {
            [strongSelf->_delegate cameraDidStoped:nil];
        }
    });
}

- (void)handleCaptureSessionNotification:(NSNotification *)noti
{
    if ([noti.name isEqualToString:AVCaptureSessionRuntimeErrorNotification]) {
        
    } else if ([noti.name isEqualToString:AVCaptureSessionDidStartRunningNotification]) {
        if (self.delegate) {
            [self.delegate cameraDidStarted:nil];
        }
    } else if ([noti.name isEqualToString:AVCaptureSessionDidStopRunningNotification]) {
        if (self.delegate) {
            [self.delegate cameraDidStoped:nil];
        }
    }
}

- (void)changeCameraPosition:(AVCaptureDevicePosition)position
{
    if (position == _cameraPosition) {
        if (self->_delegateCache.changedPosition) {
            [self->_delegate cameraDidChangePosition:self->_cameraPosition == AVCaptureDevicePositionBack ? YES : NO error:nil];
        }
        return;
    }
    
    self->_cameraPosition = position;
    _inputCamera = [self fetchCameraDeviceWithPosition:position];
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        NSError *error;
        [self configureVideoDeviceInput];
        [strongSelf->_session commitConfiguration];
        if (strongSelf->_delegateCache.changedPosition) {
            [strongSelf->_delegate cameraDidChangePosition:strongSelf->_cameraPosition == AVCaptureDevicePositionBack ? YES : NO error:error];
        }
    });
}

- (void)focusWithPoint:(CGPoint)point mode:(AVCaptureFocusMode)mode
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        NSError *error;
        [strongSelf->_inputCamera lockForConfiguration:&error];
        if (error != nil) {
            [strongSelf->_inputCamera unlockForConfiguration];
            return;
        }
        if ([strongSelf->_inputCamera isFocusModeSupported:mode]) {
            [strongSelf->_inputCamera setFocusPointOfInterest:point];
            [strongSelf->_inputCamera setFocusMode:mode];
        }
        [strongSelf->_inputCamera unlockForConfiguration];
        if (strongSelf->_delegateCache.changedFocus) {
            [strongSelf->_delegate cameraDidChangeFocus:point mode:mode error:error];
        }
    });
}

- (void)exposureWithPoint:(CGPoint)point mode:(AVCaptureExposureMode)mode
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        NSError *error;
        [strongSelf->_inputCamera lockForConfiguration:&error];
        if (error != nil) {
            [strongSelf->_inputCamera unlockForConfiguration];
            return;
        }
        [strongSelf->_inputCamera setExposurePointOfInterest:point];
        [strongSelf setExposureMode:mode];
        [strongSelf->_inputCamera unlockForConfiguration];
        if (strongSelf->_delegateCache.changedExposure) {
            [strongSelf->_delegate cameraDidChangeExposure:point mode:mode error:error];
        }
    });
}

- (void)setExposureMode:(AVCaptureExposureMode)mode
{
    if (_mode == SKElectronicScreen) {
        if ([_inputCamera isExposureModeSupported:AVCaptureExposureModeCustom]) {
            _inputCamera.exposureMode = AVCaptureExposureModeCustom;
            CMTime min = _inputCamera.activeFormat.minExposureDuration;
            CMTime max = _inputCamera.activeFormat.maxExposureDuration;
            CMTime time = CMTimeMakeWithSeconds(0.06, 1000);
            if (CMTimeCompare(time, min) == NSOrderedAscending) {
                time = min;
            }
            if (CMTimeCompare(time, max) == NSOrderedDescending) {
                time = max;
            }
            [_inputCamera setExposureModeCustomWithDuration:time ISO:_inputCamera.activeFormat.minISO completionHandler:^(CMTime syncTime) {
            }];
        }
    } else {
        if ([_inputCamera isExposureModeSupported:mode]) {
            [_inputCamera setExposureMode:mode];
        }
    }
}

- (void)setEv:(CGFloat)value
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        NSError *error;
        [strongSelf->_inputCamera lockForConfiguration:&error];
        if (error != nil) {
            [strongSelf->_inputCamera unlockForConfiguration];
            return;
        }
        CGFloat maxEV = 3.0;
        CGFloat minEV = -3.0;
        CGFloat current = (maxEV - minEV) * value + minEV;
        strongSelf->_ev = value;
        [strongSelf->_inputCamera setExposureTargetBias:(float)current completionHandler:nil];
        [strongSelf->_inputCamera unlockForConfiguration];
        if (strongSelf->_delegateCache.changedEV) {
            [strongSelf->_delegate cameraDidChangeEV:value error:error];
        }
    });
}

- (void)setZoom:(CGFloat)zoom
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        CGFloat value = zoom;
        if (@available(iOS 13.0, *)) {
            if (strongSelf->_inputCamera.deviceType == AVCaptureDeviceTypeBuiltInTripleCamera || strongSelf->_inputCamera.deviceType == AVCaptureDeviceTypeBuiltInDualWideCamera) {
                value *= 2;
            }
        }
        if (value < 1.0 || value > [strongSelf maxZoom]) {
            return;
        }
        if (value == [strongSelf zoom]) {
            return;
        }
        
        NSError *error;
        [strongSelf->_inputCamera lockForConfiguration:&error];
        if (error != nil) {
            [strongSelf->_inputCamera unlockForConfiguration];
            return;
        }
        if (strongSelf->_enableOfZoomAnimation) {
            [strongSelf->_inputCamera rampToVideoZoomFactor:value withRate:50];
        } else {
            [strongSelf->_inputCamera setVideoZoomFactor:value];
        }
        [strongSelf->_inputCamera unlockForConfiguration];
        if (strongSelf->_delegateCache.changedZoom) {
            [strongSelf->_delegate cameraDidChangeZoom:value error:error];
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
    dispatch_async(_captureQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (strongSelf->_mode != SKPhotoMode) {
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
            photoOutputConnection.videoOrientation = self.orientation;
            photoOutputConnection.videoMirrored = self.cameraPosition == AVCaptureDevicePositionFront;
        }
        
        if ([strongSelf->_inputCamera hasFlash]) {
            [setting setFlashMode:strongSelf->_flashMode];
        }
        
        if (@available(iOS 13.0, *)) {
            [setting setPhotoQualityPrioritization:AVCapturePhotoQualityPrioritizationBalanced];
        }
        
        [strongSelf->_photoOutput capturePhotoWithSettings:setting delegate:self];
    });
}

- (void)extractInfoFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CFDictionaryRef dictRef = CMCopyDictionaryOfAttachments(NULL, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    NSDictionary *dict = [[NSDictionary alloc] initWithDictionary:(__bridge NSDictionary *)dictRef];
    CFRelease(dictRef);
    NSDictionary *exifDict = dict[(NSString *)kCGImagePropertyExifDictionary];
    if (exifDict != nil) {
        CGFloat brightness = [exifDict[(NSString *)kCGImagePropertyExifBrightnessValue] floatValue];
    }
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CFRetain(sampleBuffer);
    
    [self extractInfoFromSampleBuffer:sampleBuffer];
    
    if (_delegateCache.cameraDidOutputSampleBuffer) {
        [_delegate cameraDidOutputSampleBuffer:sampleBuffer];
    }
    CFRelease(sampleBuffer);
}

#pragma mark - AVCapturePhotoCaptureDelegate
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error
{
    if (_delegateCache.cameraDidFinishProcessingPhoto) {
        [_delegate cameraDidFinishProcessingPhoto:photo error:error];
    }
}

- (void)captureOutput:(AVCapturePhotoOutput *)output willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
    if (_delegateCache.cameraWillCacpturePhoto) {
        [self->_delegate cameraWillCapturePhoto];
    }
}

@end
