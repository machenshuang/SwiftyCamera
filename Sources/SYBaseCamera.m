//
//  SYBaseCamera.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2023/4/6.
//

#import "SYBaseCamera.h"
#import "SYLog.h"
#import "SYSingleCamera.h"
#import "SYMultiCamera.h"

static NSString *TAG = @"SYBaseCamera";

@interface SYBaseCamera () 
{
    AVCaptureDeviceInput *_audioInput;
    AVCaptureAudioDataOutput *_audioOutput;
}

@property (nonatomic, assign, readwrite) AVCaptureDevicePosition cameraPosition;
@property (nonatomic, assign, readwrite) SYCameraMode mode;
@property (nonatomic, strong, readwrite) dispatch_queue_t sessionQueue;
@property (nonatomic, strong, readwrite) dispatch_queue_t cameraProcessQueue;
@property (nonatomic, strong, readwrite) dispatch_queue_t captureQueue;
@property (nonatomic, assign, readwrite) SYCameraDelegateMap delegateMap;

@end


@implementation SYBaseCamera

+ (SYBaseCamera *)createCameraWithConfig:(SYCameraConfig *)config withDelegate:(id<SYCameraDelegate>)delegate
{
    SYBaseCamera *camera;
    AVCaptureSessionPreset preset = config.sessionPreset;
    AVCaptureDevicePosition position = config.devicePosition;
    if (position == AVCaptureDevicePositionUnspecified) {
        position = AVCaptureDevicePositionBack;
    }
    
    SYCameraMode mode = config.mode;
    
    if (preset == nil) {
        if (mode == SYPhotoMode) {
            preset = AVCaptureSessionPresetPhoto;
        } else {
            preset = AVCaptureSessionPresetHigh;
        }
    }
    switch (config.type) {
        case SYSingleDevice: {
            camera = [[SYSingleCamera alloc] initWithSessionPreset:preset cameraPosition:position withMode:mode withDelegate:delegate];
            break;
        }
        case SYDualDevice: {
            if (@available(iOS 13.0, *)) {
                camera = [[SYMultiCamera alloc] initWithSessionPreset:preset cameraPosition:position withMode:mode withDelegate:delegate];
            }
            break;
        }
    }
    return camera;
}

- (instancetype)initWithSessionPreset:(AVCaptureSessionPreset)sessionPreset
                       cameraPosition:(AVCaptureDevicePosition)cameraPosition
                             withMode:(SYCameraMode)mode
                         withDelegate:(id<SYCameraDelegate>)delegate
{
    self = [super init];
    if (self) {
        _ev = 0.5;
        _sessionQueue = dispatch_queue_create("com.machenshuang.camera.AVCameraSessionQueue", DISPATCH_QUEUE_SERIAL);
        _cameraProcessQueue = dispatch_queue_create("com.machenshuang.camera.AVCameraCameraProcessingQueue", DISPATCH_QUEUE_SERIAL);
        _captureQueue = dispatch_queue_create("com.machenshuang.camera.AVCameraCaptureQueue", DISPATCH_QUEUE_SERIAL);

        _cameraPosition = cameraPosition;
        _mode = mode;
        self.delegate = delegate;
        [self setupCaptureSession];
        __weak typeof(self)weakSelf = self;
        dispatch_async(_sessionQueue, ^{
            __strong typeof(weakSelf)strongSelf = weakSelf;
           
            if (![strongSelf setupCameraDevice]) {
                SYLog(TAG, "initWithSessionPreset setupCameraDevice failure");
                return;
            }
            [strongSelf configureSesson: sessionPreset];
        });
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleCaptureSessionNotification:)
                                                     name:nil
                                                   object:_session];
    }
    return self;
}


- (void)setDelegate:(id<SYCameraDelegate>)delegate
{
    _delegate = delegate;
    _delegateMap.cameraDidStarted = [delegate respondsToSelector:@selector(cameraDidStarted)];
    _delegateMap.cameraDidStoped = [delegate respondsToSelector:@selector(cameraDidStoped)];
    _delegateMap.cameraCaptureVideoSampleBuffer = [delegate respondsToSelector:@selector(cameraCaptureVideoSampleBuffer:)];
    _delegateMap.cameraCaptureAudioSampleBuffer = [delegate respondsToSelector:@selector(cameraCaptureAudioSampleBuffer:)];
    _delegateMap.cameraDidFinishProcessingPhoto = [delegate respondsToSelector:@selector(cameraDidFinishProcessingPhoto:error:)];
    _delegateMap.changedPosition = [delegate respondsToSelector:@selector(cameraDidChangePosition:)];
    _delegateMap.changedFocus = [delegate respondsToSelector:@selector(cameraDidChangeFocus:mode:)];
    _delegateMap.changedZoom = [delegate respondsToSelector:@selector(cameraDidChangeZoom:)];
    _delegateMap.changedExposure = [delegate respondsToSelector:@selector(cameraDidChangeExposure:mode:)];
    _delegateMap.changedFlash = [delegate respondsToSelector:@selector(camerahDidChangeFlash:)];
    _delegateMap.changedEV = [delegate respondsToSelector:@selector(cameraDidChangeEV:)];
    _delegateMap.cameraWillProcessPhoto = [delegate respondsToSelector:@selector(cameraWillProcessPhoto)];
    _delegateMap.cameraDidChangeMode = [delegate respondsToSelector:@selector(cameraDidChangeMode:)];
    _delegateMap.getVideoPreviewForPosition = [delegate respondsToSelector:@selector(getVideoPreviewForPosition:)];
}

- (void)changeCameraMode:(SYCameraMode)mode
       withSessionPreset:(AVCaptureSessionPreset)sessionPreset
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf->_mode == mode) {
            if (strongSelf->_delegateMap.cameraDidChangeMode) {
                [strongSelf.delegate cameraDidChangeMode:mode];
            }
            return;
        }
        strongSelf->_mode = mode;
        [strongSelf configureSesson:sessionPreset];
        if (strongSelf->_delegateMap.cameraDidChangeMode) {
            [strongSelf.delegate cameraDidChangeMode:mode];
        }
    });
}

- (void)configureSesson:(AVCaptureSessionPreset)sessionPreset
{
    SYLog(TAG, "configureSesson beginConfiguration");
    [_session beginConfiguration];
    [self setupVideoDeviceInput];
    [self setupVideoOutput];
    [self setupPhotoOutput];
    if (@available(iOS 13.0, *)) {
        if (![_session isKindOfClass:[AVCaptureMultiCamSession class]]) {
            [_session setSessionPreset:sessionPreset];
        }
    } else {
        [_session setSessionPreset:sessionPreset];
    }
    [_session commitConfiguration];
    [self exposureWithPoint:CGPointMake(0.5, 0.5) mode:AVCaptureExposureModeAutoExpose];
    [self setZoom:1.0 withAnimated:NO];
    SYLog(TAG, "configureSesson commitConfiguration");
}

- (void)setupVideoDeviceInput
{

}

- (void)setupVideoOutput
{
    
}

- (void)setupPhotoOutput
{
    
}

- (BOOL)setupCameraDevice 
{
    return NO;
}

- (void)setupCaptureSession 
{
    
}

- (void)addMicrophoneWith:(void (^)(void))completion
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf->_audioInput == nil) {
            AVCaptureDevice* audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
            NSError *error = nil;
            AVCaptureDeviceInput* audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
            if (error) {
                SYLog(TAG, "addMicrophoneWith deviceInputWithDevice error = %@", error.description);
            }
            if ([strongSelf->_session canAddInput:audioDeviceInput]) {
                [strongSelf->_session addInput:audioDeviceInput];
                strongSelf->_audioInput = audioDeviceInput;
                SYLog(TAG, "configureAudioDeviceInput addAudioInput");
            } else {
                SYLog(TAG, "addMicrophoneWith can not addAudioInput");
            }
        }
        
        if (strongSelf->_audioOutput == nil) {
            strongSelf->_audioOutput = [[AVCaptureAudioDataOutput alloc] init];
            [strongSelf->_audioOutput setSampleBufferDelegate:self queue:strongSelf->_cameraProcessQueue];
            if ([strongSelf->_session canAddOutput:strongSelf->_audioOutput]) {
                [strongSelf->_session addOutput:strongSelf->_audioOutput];
            } else {
                SYLog(TAG, "addMicrophoneWith addAudioOutput");
            }
        }
        completion();
    });
}

- (void)removeMicrophoneWith:(void (^)(void))completion
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        if (strongSelf->_audioInput) {
            [strongSelf->_session removeInput:strongSelf->_audioInput];
            strongSelf->_audioInput = nil;
            SYLog(TAG, "removeMicrophoneWith removeAudioDevice");
        }
        
        if (strongSelf->_audioOutput) {
            [strongSelf->_session removeOutput:strongSelf->_audioOutput];
            strongSelf->_audioOutput = nil;
            SYLog(TAG, "removeMicrophoneWith removeAudioOutput");
        }
        completion();
    });
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
            [strongSelf->_delegate cameraDidStarted];
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
            [strongSelf->_delegate cameraDidStoped];
        }
    });
}

- (void)handleCaptureSessionNotification:(NSNotification *)noti
{
    if ([noti.name isEqualToString:AVCaptureSessionRuntimeErrorNotification]) {
        
    } else if ([noti.name isEqualToString:AVCaptureSessionDidStartRunningNotification]) {
        if (self.delegate) {
            [self.delegate cameraDidStarted];
        }
    } else if ([noti.name isEqualToString:AVCaptureSessionDidStopRunningNotification]) {
        if (self.delegate) {
            [self.delegate cameraDidStoped];
        }
    }
}

- (void)changeCameraPosition:(AVCaptureDevicePosition)position
{
    if (position == _cameraPosition) {
        if (self.delegateMap.changedPosition) {
            [self->_delegate cameraDidChangePosition:self->_cameraPosition == AVCaptureDevicePositionBack ? YES : NO];
        }
        return;
    }
    
    self->_cameraPosition = position;
    BOOL ret = [self setupCameraDevice];
    __weak typeof(self)weakSelf = self;
    dispatch_async(_sessionQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        [self setupVideoDeviceInput];
        [strongSelf->_session commitConfiguration];
        if (strongSelf->_delegateMap.changedPosition) {
            [strongSelf->_delegate cameraDidChangePosition:strongSelf->_cameraPosition == AVCaptureDevicePositionBack ? YES : NO];
        }
    });
}

- (void)focusWithPoint:(CGPoint)point mode:(AVCaptureFocusMode)mode
{
}

- (void)exposureWithPoint:(CGPoint)point mode:(AVCaptureExposureMode)mode
{
}

- (void)setExposureMode:(AVCaptureExposureMode)mode
{
//    AVCaptureDevice *inputCamera = [self getEnableCameraDeviceWithPosition:_cameraPosition];
//    if (!inputCamera) {
//        return;
//    }
//    if (_mode == SYElectronicScreen) {
//        if ([inputCamera isExposureModeSupported:AVCaptureExposureModeCustom]) {
//            inputCamera.exposureMode = AVCaptureExposureModeCustom;
//            CMTime min = inputCamera.activeFormat.minExposureDuration;
//            CMTime max = inputCamera.activeFormat.maxExposureDuration;
//            CMTime time = CMTimeMakeWithSeconds(0.06, 1000);
//            if (CMTimeCompare(time, min) == NSOrderedAscending) {
//                time = min;
//            }
//            if (CMTimeCompare(time, max) == NSOrderedDescending) {
//                time = max;
//            }
//            [inputCamera setExposureModeCustomWithDuration:time ISO:inputCamera.activeFormat.minISO completionHandler:^(CMTime syncTime) {
//            }];
//        }
//    } else {
//        if ([inputCamera isExposureModeSupported:mode]) {
//            [inputCamera setExposureMode:mode];
//        }
//    }
}

- (void)setEv:(CGFloat)value
{
    _ev = value;
}

- (void)setZoom:(CGFloat)zoom withAnimated:(BOOL)animated
{
}

- (CGFloat)zoom
{
    return 1;
}

- (CGFloat)maxZoom
{
    return 1;
}

- (CGFloat)minZoom {
    return 1;
}

- (void)takePhoto
{
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

- (AVCaptureDevice *)fetchCameraDeviceWithPosition:(AVCaptureDevicePosition)position
{
    AVCaptureDevice *device;
    if (position == AVCaptureDevicePositionBack) {
        NSArray *deviceType;
        if (@available(iOS 13.0, *)) {
            if ([self isKindOfClass:[SYMultiCamera class]]) {
                AVCaptureDevice *backDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:position];
                device = backDevice;
            } else {
                deviceType = @[AVCaptureDeviceTypeBuiltInTripleCamera, AVCaptureDeviceTypeBuiltInDualWideCamera, AVCaptureDeviceTypeBuiltInWideAngleCamera];
                AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceType mediaType:AVMediaTypeVideo position:position];
                device = deviceSession.devices.firstObject;
            }
        } else {
            deviceType = @[AVCaptureDeviceTypeBuiltInDualCamera, AVCaptureDeviceTypeBuiltInWideAngleCamera];
            AVCaptureDeviceDiscoverySession *deviceSession = [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceType mediaType:AVMediaTypeVideo position:position];
            device = deviceSession.devices.firstObject;
        }
    } else  {
        AVCaptureDevice *frontDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:position];
        device = frontDevice;
    }
    return device;
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
    if ([output isKindOfClass: [AVCaptureVideoDataOutput class]] && _delegateMap.cameraCaptureVideoSampleBuffer){
        //[self extractInfoFromSampleBuffer:sampleBuffer];
        [_delegate cameraCaptureVideoSampleBuffer:sampleBuffer];
    } else if ([output isKindOfClass: [AVCaptureAudioDataOutput class]] && _delegateMap.cameraCaptureAudioSampleBuffer) {
        [_delegate cameraCaptureAudioSampleBuffer:sampleBuffer];
    }
}

#pragma mark - AVCapturePhotoCaptureDelegate
- (void)captureOutput:(AVCapturePhotoOutput *)output didFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error
{
    if (_delegateMap.cameraDidFinishProcessingPhoto) {
        [_delegate cameraDidFinishProcessingPhoto:photo error:error];
    }
}

- (void)captureOutput:(AVCapturePhotoOutput *)output willCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
    if (_delegateMap.cameraWillProcessPhoto) {
        [self->_delegate cameraWillProcessPhoto];
    }
}

@end
