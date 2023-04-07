//
//  SYCamera.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2023/4/6.
//

#import "SYCamera.h"

typedef struct SYCameraDelegateCache {
    unsigned int diplayOutputSampleBuffer : 1;
    unsigned int captureOutputPixelBuffer : 1;
    unsigned int changedPosition : 1;
    unsigned int changedFocus : 1;
    unsigned int changedZoom : 1;
    unsigned int changedExposure : 1;
    unsigned int changedFlash : 1;
    unsigned int changedEV : 1;
    unsigned int captureWillOutput : 1;
} SYCameraDelegateCache;

@interface SYCamera () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate>
{
    AVCaptureSession *_session;
    AVCaptureDevice *_inputCamera;
    AVCaptureDeviceInput *_videoInput;
    AVCaptureVideoDataOutput *_videoOutput;
    AVCapturePhotoOutput *_photoOutput;
    
    dispatch_queue_t _sessionQueue;
    dispatch_queue_t _cameraProcessQueue;
    dispatch_queue_t _captureQueue;
    
    SYCameraDelegateCache _delegateCache;
}

@end



@implementation SYCamera

@synthesize cameraPosition = _cameraPosition;

- (instancetype)init
{
    self = [self initWithSessionPreset:AVCaptureSessionPreset640x480 cameraPosition:AVCaptureDevicePositionBack];
    return self;
}

- (instancetype)initWithSessionPreset:(AVCaptureSessionPreset)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition
{
    self = [super init];
    if (self) {
        _ev = 0.5;
        _sessionQueue = dispatch_queue_create("com.RGBA.GPUCameraRender.AVCameraSessionQueue", DISPATCH_QUEUE_SERIAL);
        _cameraProcessQueue = dispatch_queue_create("com.RGBA.GPUCameraRender.AVCameraCameraProcessingQueue", DISPATCH_QUEUE_SERIAL);
        _captureQueue = dispatch_queue_create("com.RGBA.GPUCameraRender.AVCameraCaptureQueue", DISPATCH_QUEUE_SERIAL);
        
        _inputCamera = nil;
        NSArray *deviceType;
        if (@available(iOS 13.0, *)) {
            deviceType = @[AVCaptureDeviceTypeBuiltInTripleCamera, AVCaptureDeviceTypeBuiltInDualWideCamera, AVCaptureDeviceTypeBuiltInWideAngleCamera];
        } else {
            deviceType = @[AVCaptureDeviceTypeBuiltInDualCamera, AVCaptureDeviceTypeBuiltInWideAngleCamera];;
        }
        AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceType mediaType:AVMediaTypeVideo position:cameraPosition];
        _inputCamera = deviceSession.devices.firstObject;
        
        if (!_inputCamera) {
            return nil;
        }
        _cameraPosition = cameraPosition;
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
        [self setZoom:1.0];
    }
    return self;
}

- (void)dealloc
{
    [_videoOutput setSampleBufferDelegate:nil queue:nil];
}

- (void)setDelegate:(id<SYCameraDelegate>)delegate
{
    _delegate = delegate;
    _delegateCache.diplayOutputSampleBuffer = [delegate respondsToSelector:@selector(cameraDisplaySampleBuffer:)];
    _delegateCache.captureOutputPixelBuffer = [delegate respondsToSelector:@selector(cameraCapturePixelBuffer:withMetaData:error:)];
    _delegateCache.changedPosition = [delegate respondsToSelector:@selector(cameraDidChangedPosition:error:)];
    _delegateCache.changedFocus = [delegate respondsToSelector:@selector(cameraDidChangedFocus:mode:error:)];
    _delegateCache.changedZoom = [delegate respondsToSelector:@selector(cameraDidChangedZoom:error:)];
    _delegateCache.changedExposure = [delegate respondsToSelector:@selector(cameraDidChangedExposure:mode:error:)];
    _delegateCache.changedFlash = [delegate respondsToSelector:@selector(camerahDidChangedFlash:error:)];
    _delegateCache.changedEV = [delegate respondsToSelector:@selector(cameraDidChangedEV:error:)];
    _delegateCache.captureWillOutput = [delegate respondsToSelector:@selector(cameraCaptureWillOutput)];
}

- (void)configureSesson:(AVCaptureSessionPreset)sessionPreset
{
    [_session beginConfiguration];
    NSError *error = nil;
    // 添加 input
    _videoInput = [[AVCaptureDeviceInput alloc] initWithDevice:_inputCamera error:&error];
    if ([_session canAddInput:_videoInput]) {
        [_session addInput:_videoInput];
    }
    
    // 添加 frame output
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setAlwaysDiscardsLateVideoFrames:NO];
    [_videoOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [_videoOutput setSampleBufferDelegate:self queue:_cameraProcessQueue];
    if ([_session canAddOutput:_videoOutput]) {
        [_session addOutput:_videoOutput];
    }
    
    for (AVCaptureConnection *connect in _videoOutput.connections) {
        if ([connect isVideoMirroringSupported]) {
            [connect setVideoMirrored: _cameraPosition == AVCaptureDevicePositionFront ? YES : NO];
        }
        if ([connect isVideoOrientationSupported]) {
            [connect setVideoOrientation: AVCaptureVideoOrientationPortrait];
        }
    }
    
    // 添加 photo output
    
    _photoOutput = [AVCapturePhotoOutput new];
    [_photoOutput setHighResolutionCaptureEnabled:YES];
    if ([_session canAddOutput:_photoOutput]) {
        [_session addOutput:_photoOutput];
    }
    
    [_session setSessionPreset:sessionPreset];
    [_session commitConfiguration];
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
            [self->_delegate cameraDidChangedPosition:self->_cameraPosition == AVCaptureDevicePositionBack ? YES : NO error:nil];
        }
        return;
    }
    AVCaptureDevice *newInputCamera = nil;
    AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:@[AVCaptureDeviceTypeBuiltInWideAngleCamera] mediaType:AVMediaTypeVideo position:position];
    for (AVCaptureDevice *device in deviceSession.devices)
    {
        if ([device position] == position)
        {
            newInputCamera = device;
        }
    }
   
    self->_cameraPosition = position;
    _inputCamera = newInputCamera;
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        AVCaptureDeviceInput *newVideoInput;
        NSError *error;
        newVideoInput = [[AVCaptureDeviceInput alloc] initWithDevice:newInputCamera error:&error];
        [strongSelf->_session beginConfiguration];
        [strongSelf->_session removeInput:strongSelf->_videoInput];
        if ([strongSelf->_session canAddInput:newVideoInput]) {
            [strongSelf->_session addInput:newVideoInput];
            strongSelf->_videoInput = newVideoInput;
        } else {
            [strongSelf->_session addInput:strongSelf->_videoInput];
        }
        
        for (AVCaptureConnection *connect in strongSelf->_videoOutput.connections) {
            if ([connect isVideoMirroringSupported]) {
                [connect setVideoMirrored: strongSelf->_cameraPosition == AVCaptureDevicePositionFront ? YES : NO];
            }
            if ([connect isVideoOrientationSupported]) {
                [connect setVideoOrientation: AVCaptureVideoOrientationPortrait];
            }
        }
        
        [strongSelf->_session commitConfiguration];
        if (strongSelf->_delegateCache.changedPosition) {
            [strongSelf->_delegate cameraDidChangedPosition:strongSelf->_cameraPosition == AVCaptureDevicePositionBack ? YES : NO error:error];
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
            [strongSelf->_delegate cameraDidChangedFocus:point mode:mode error:error];
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
        if ([strongSelf->_inputCamera isExposureModeSupported:mode]) {
            [strongSelf->_inputCamera setExposurePointOfInterest:point];
            [strongSelf->_inputCamera setExposureMode:mode];
        }
        [strongSelf->_inputCamera unlockForConfiguration];
        if (strongSelf->_delegateCache.changedExposure) {
            [strongSelf->_delegate cameraDidChangedExposure:point mode:mode error:error];
        }
    });
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
            [strongSelf->_delegate cameraDidChangedEV:value error:error];
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
            [strongSelf->_delegate cameraDidChangedZoom:value error:error];
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
        NSDictionary *dict = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
        AVCapturePhotoSettings *setting = [AVCapturePhotoSettings photoSettingsWithFormat:dict];
        [setting setHighResolutionPhotoEnabled:YES];
        [setting setAutoStillImageStabilizationEnabled:YES];
        if ([strongSelf->_inputCamera hasFlash]) {
            [setting setFlashMode:strongSelf->_flashMode];
        }
        [strongSelf->_photoOutput capturePhotoWithSettings:setting delegate:self];
    });
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    CFRetain(sampleBuffer);
    if (_delegateCache.diplayOutputSampleBuffer) {
        [_delegate cameraDisplaySampleBuffer:sampleBuffer];
    }
    CFRelease(sampleBuffer);
}

#pragma mark - AVCapturePhotoCaptureDelegate
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error
{
    if (error != nil) {
        if (_delegateCache.captureOutputPixelBuffer) {
            [_delegate cameraCapturePixelBuffer:NULL withMetaData:NULL error:error];
        }
        return;
    }
    [_delegate cameraCapturePixelBuffer:photo.pixelBuffer withMetaData:photo.metadata error:nil];
    CVPixelBufferRef pixelBuffer = photo.pixelBuffer;
}

- (void)captureOutput:(AVCapturePhotoOutput *)output willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
    if (_delegateCache.captureWillOutput) {
        [self->_delegate cameraCaptureWillOutput];
    }
}

@end
