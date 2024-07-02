//
//  SYCameraManager.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/5/25.
//

#import "SYCameraManager.h"
#import "SYSingleCamera.h"
#import "SYPreviewView.h"
#import "SYRecorder.h"
#import "UIImage+SYImage.h"
#import "SYLog.h"

typedef struct SYCameraManagerDelegateMap {
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
    unsigned int cameraWillCapturePhoto : 1;
    unsigned int cameraDidChangeMode: 1;
    unsigned int cameraDidFinishProcessingVideo: 1;
    unsigned int cameraRecordStatusDidChange: 1;
} SYCameraManagerDelegateMap;

static NSString * TAG = @"SYCameraManager";

@interface SYCameraManager () <SYCameraDelegate>
{
    SYBaseCamera *_camera;
    NSDictionary<NSNumber *, SYPreviewView *> *_previewViews;
    SYCameraManagerDelegateMap _delegateCache;
    SYDeviceType _deviceType;
    SYRecorder *_recorder;
    CGSize _sampleBufferSize;
    BOOL _audioProcessing;
    NSDictionary<NSNumber *, NSValue *> *_previewViewRects;
}

@property (nonatomic, assign, readwrite) BOOL isAuthority;
@property (nonatomic, assign, readwrite) SYRecordStatus recordStatus;

@property (nonatomic, assign, readwrite) CGFloat zoom;
@property (nonatomic, assign, readwrite) CGFloat minZoom;
@property (nonatomic, assign, readwrite) CGFloat maxZoom;

@end

@implementation SYCameraManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _sampleBufferSize = CGSizeMake(1080, 1920);
        _deviceType = SYSingleDevice;
        _deviceOrientation = UIDeviceOrientationPortrait;
        _recordStatus = SYRecordNormal;
    }
    return self;
}

- (void)requestCameraWithConfig:(SYCameraConfig *)config 
                 withCompletion:(void (^)(BOOL))completion
{
    self.isAuthority = YES;
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status != AVAuthorizationStatusAuthorized) {
        self.isAuthority = NO;
        completion(self.isAuthority);
        return;
    }
    
    if (config.mode == SYVideoMode) {
        status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
        if (status != AVAuthorizationStatusAuthorized) {
            self.isAuthority = NO;
            completion(self.isAuthority);
            return;
        }
    }
    _deviceType = config.type;
    _previewViewRects = config.previewViewRects;
    [self configurePreviewView];
    _camera = [SYBaseCamera createCameraWithConfig:config withDelegate:self];
    _camera.delegate = self;
    _camera.orientation = [self convertOrientation:self.deviceOrientation];
    completion(self.isAuthority);
}

- (void)configurePreviewView
{
    switch (_deviceType) {
        case SYSingleDevice: {
            SYPreviewView *previewView = [SYPreviewView new];
            _previewViews = @{
                @(AVCaptureDevicePositionFront): previewView,
                @(AVCaptureDevicePositionBack): previewView,
            };
            break;
        }
        case SYDualDevice: {
            SYPreviewView *frontPreviewView = [SYPreviewView new];
            SYPreviewView *backPreviewView = [SYPreviewView new];
            _previewViews = @{
                @(AVCaptureDevicePositionFront): frontPreviewView,
                @(AVCaptureDevicePositionBack): backPreviewView,
            };
            break;
        }
            
    }
}

- (void)changeCameraMode:(SYCameraMode)mode withSessionPreset:(AVCaptureSessionPreset)preset
{
    if (!_camera) {
        SYLog(TAG, "changeCameraMode camera is nil");
        return;
    }
    
    AVCaptureSessionPreset sessionPreset; ;
    if (preset == nil) {
        if (mode == SYPhotoMode) {
            sessionPreset = AVCaptureSessionPresetPhoto;
        } else {
            sessionPreset = AVCaptureSessionPresetHigh;
        }
    } else {
        sessionPreset = preset;
    }
    
    [_camera changeCameraMode:mode withSessionPreset:sessionPreset];
}

- (void)addPreviewToView:(UIView *)view
{
    if (!_camera) {
        SYLog(TAG, "addPreviewToView camera is nil");
        return;
    }
    switch (_deviceType) {
        case SYSingleDevice: {
            [self addSinglePreviewViewToView:view];
            break;
        }
        case SYDualDevice: {
            [self addDualPreviewViewToView:view];
            break;
        }
    }
}

- (void)addSinglePreviewViewToView:(UIView *)view
{
    SYPreviewView *previewView = _previewViews[@(_camera.cameraPosition)];
    if (previewView.superview) {
        [previewView removeFromSuperview];
    }
    [view addSubview:previewView];
    
    // 有性能优化，精准控制布局
    previewView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addConstraints:@[
        [NSLayoutConstraint constraintWithItem:previewView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeLeading multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:previewView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:previewView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeBottom multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:previewView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTop multiplier:1 constant:0],
    ]];
}

- (void)addDualPreviewViewToView:(UIView *)view
{
    SYPreviewView *backPreviewView = _previewViews[@(AVCaptureDevicePositionBack)];
    SYPreviewView *frontPreviewView = _previewViews[@(AVCaptureDevicePositionFront)];
    if (backPreviewView.superview) {
        [backPreviewView removeFromSuperview];
    }
    if (frontPreviewView.superview) {
        [frontPreviewView removeFromSuperview];
    }
    
    switch (_camera.cameraPosition) {
        case AVCaptureDevicePositionFront: {
            [view addSubview:frontPreviewView];
            [view addSubview:backPreviewView];
            break;
        }
        default: {
            [view addSubview:backPreviewView];
            [view addSubview:frontPreviewView];
            break;
        }
    }
    
    CGRect backRect;
    CGRect frontRect;
    
    if (_previewViewRects[@(AVCaptureDevicePositionBack)]) {
        backRect = [_previewViewRects[@(AVCaptureDevicePositionBack)] CGRectValue];
    } else {
        backRect = CGRectMake(0, 0, 1, 0.5);
    }
    
    if (_previewViewRects[@(AVCaptureDevicePositionFront)]) {
        frontRect = [_previewViewRects[@(AVCaptureDevicePositionFront)] CGRectValue];
    } else {
        frontRect = CGRectMake(0, 0.5, 1, 0.5);
    }
    
    backPreviewView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addConstraints:@[
        [NSLayoutConstraint constraintWithItem:backPreviewView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeLeading multiplier:1+backRect.origin.x constant:0],
        [NSLayoutConstraint constraintWithItem:backPreviewView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTop multiplier:1+backRect.origin.y constant:0],
        [NSLayoutConstraint constraintWithItem:backPreviewView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeWidth multiplier:backRect.size.width constant:0],
        [NSLayoutConstraint constraintWithItem:backPreviewView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeHeight multiplier:backRect.size.height constant:0],
    ]];
    
    frontPreviewView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addConstraints:@[
        [NSLayoutConstraint constraintWithItem:frontPreviewView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeLeading multiplier:1+frontRect.origin.x constant:0],
        [NSLayoutConstraint constraintWithItem:frontPreviewView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTop multiplier:1+frontRect.origin.y constant:0],
        [NSLayoutConstraint constraintWithItem:frontPreviewView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeWidth multiplier:frontRect.size.width constant:0],
        [NSLayoutConstraint constraintWithItem:frontPreviewView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeHeight multiplier:frontRect.size.height constant:0],
    ]];
    
}

- (void)setDelegate:(id<SYCameraManagerDelegate>)delegate
{
    _delegate = delegate;
    _delegateCache.cameraDidStarted = [delegate respondsToSelector:@selector(cameraDidStarted:)];
    _delegateCache.cameraDidStoped = [delegate respondsToSelector:@selector(cameraDidStoped:)];
    _delegateCache.cameraDidOutputSampleBuffer = [delegate respondsToSelector:@selector(cameraDidOutputSampleBuffer:)];
    _delegateCache.cameraDidFinishProcessingPhoto = [delegate respondsToSelector:@selector(cameraDidFinishProcessingPhoto:withMetaData:withManager:withError:)];
    _delegateCache.changedPosition = [delegate respondsToSelector:@selector(cameraDidChangedPosition:withManager:)];
    _delegateCache.changedFocus = [delegate respondsToSelector:@selector(cameraDidChangedFocus:mode:withManager:)];
    _delegateCache.changedZoom = [delegate respondsToSelector:@selector(cameraDidChangedZoom:withManager:)];
    _delegateCache.changedExposure = [delegate respondsToSelector:@selector(cameraDidChangedExposure:mode:withManager:)];
    _delegateCache.changedFlash = [delegate respondsToSelector:@selector(camerahDidChangedFlash:withManager:)];
    _delegateCache.changedEV = [delegate respondsToSelector:@selector(cameraDidChangedEV:withManager:)];
    _delegateCache.cameraWillCapturePhoto = [delegate respondsToSelector:@selector(cameraWillCapturePhoto:)];
    _delegateCache.cameraDidChangeMode = [delegate respondsToSelector:@selector(cameraDidChangeMode:withManager:)];
    _delegateCache.cameraDidFinishProcessingVideo = [delegate respondsToSelector:@selector(cameraDidFinishProcessingVideo:withManager:withError:)];
    _delegateCache.cameraRecordStatusDidChange = [delegate respondsToSelector:@selector(cameraRecordStatusDidChange:withManager:)];
}

- (void)changeCameraPosition:(AVCaptureDevicePosition)position 
{
    if (_camera == nil) {
        return;
    }
    [_camera changeCameraPosition:position];
}

- (void)exposureWithPoint:(CGPoint)point mode:(AVCaptureExposureMode)mode
{
    if (_camera == nil) {
        return;
    }
    [_camera exposureWithPoint:point mode:mode];
}

- (void)focusWithPoint:(CGPoint)point mode:(AVCaptureFocusMode)mode 
{
    if (_camera == nil) {
        return;
    }
    [_camera focusWithPoint:point mode:mode];
}


- (void)startCapture 
{
    if (_camera == nil) {
        return;
    }
    [_camera startCapture];
}

- (void)stopCapture 
{
    if (_camera == nil) {
        return;
    }
    [_camera stopCapture];
}

- (void)takePhoto 
{
    if (_camera == nil) {
        return;
    }
    [_camera takePhoto];
}

- (void)startRecord
{
    if (_camera == nil) {
        if (_delegateCache.cameraRecordStatusDidChange) {
            [_delegate cameraRecordStatusDidChange:_recordStatus withManager:self];
        }
        return;
    }
    if (_audioProcessing) {
        return;
    }
    _audioProcessing = YES;
    __weak typeof(self)weakSelf = self;
    [_camera addMicrophoneWith:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf)strongSelf = weakSelf;
            strongSelf->_recordStatus = SYRecording;
            [strongSelf realStartRecord];
            strongSelf->_audioProcessing = NO;
            if (strongSelf->_delegateCache.cameraRecordStatusDidChange) {
                [strongSelf->_delegate cameraRecordStatusDidChange:strongSelf->_recordStatus withManager:strongSelf];
            }
        });
    }];
}

- (void)realStartRecord
{
    SYRecordConfig *config = [[SYRecordConfig alloc] initWithSize:_sampleBufferSize];
    _recorder = [[SYRecorder alloc] initWithConfig:config];
    [_recorder startRecord];
}

- (void)stopRecord
{
    if (_camera == nil) {
        if (_delegateCache.cameraRecordStatusDidChange) {
            [_delegate cameraRecordStatusDidChange:_recordStatus withManager:self];
        }
        return;
    }
    
    if (_audioProcessing) {
        if (_delegateCache.cameraRecordStatusDidChange) {
            [_delegate cameraRecordStatusDidChange:_recordStatus withManager:self];
        }
        return;
    }
    _audioProcessing = YES;
    
    
    __weak typeof(self)weakSelf = self;
    [_camera removeMicrophoneWith:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf)strongSelf = weakSelf;
            strongSelf->_recordStatus = SYRecordNormal;
            if (strongSelf->_recorder) {
                [strongSelf realStopRecordWithCompletion:^{}];
            }
            strongSelf->_audioProcessing = NO;
            if (strongSelf->_delegateCache.cameraRecordStatusDidChange) {
                [strongSelf->_delegate cameraRecordStatusDidChange:strongSelf->_recordStatus withManager:self];
            }
        });
    }];
}

- (void)realStopRecordWithCompletion:(void(^)(void))completion
{
    __weak typeof(self)weakSelf = self;
    [_recorder stopRecordWithCompletion:^(NSURL * _Nullable outputURL, BOOL ret) {
        __strong typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->_recorder = nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            completion();
        });
        if (strongSelf->_delegateCache.cameraDidFinishProcessingVideo) {
            [strongSelf->_delegate cameraDidFinishProcessingVideo:outputURL withManager:strongSelf withError:nil];
        }
    }];
}

- (void)pauseRecord
{
    if (_camera == nil || _recorder == nil) {
        return;
    }
    _recordStatus = SYRecordPause;
}

- (void)resumeRecord
{
    if (_camera == nil || _recorder == nil) {
        return;
    }
    _recordStatus = SYRecording;
}

- (UIImage *)imageFromPixelBuffer:(CVPixelBufferRef) pixelbuffer
{
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelbuffer];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef videoImage = [context createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(pixelbuffer), CVPixelBufferGetHeight(pixelbuffer))];
    UIImage *image = [UIImage imageWithCGImage:videoImage];
    CGImageRelease(videoImage);
    return image;
}

- (void)setDeviceOrientation:(UIDeviceOrientation)orientation 
{
    _deviceOrientation = orientation;
    if (_camera) {
        AVCaptureVideoOrientation videoOrientation = [self convertOrientation:orientation];
        _camera.orientation = videoOrientation;
    }
}

- (AVCaptureVideoOrientation)convertOrientation:(UIDeviceOrientation)orientation
{
    AVCaptureVideoOrientation videoOrientation = AVCaptureVideoOrientationPortrait;
    switch (orientation) {
        case UIDeviceOrientationPortrait: {
            videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
        }
        case UIDeviceOrientationLandscapeLeft: {
            videoOrientation = AVCaptureVideoOrientationLandscapeRight;
            break;
        }
        case UIDeviceOrientationLandscapeRight: {
            videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        }
        case UIDeviceOrientationPortraitUpsideDown: {
            videoOrientation = AVCaptureVideoOrientationPortraitUpsideDown;
            break;
        }
        default: {
            break;
        }
    }
    return videoOrientation;
}

- (SYCameraMode)cameraMode
{
    if (_camera) {
        return _camera.mode;
    } else {
        return SYPhotoMode;
    }
}

- (CGFloat)zoom
{
    if (!_camera) {
        return 0.0;
    }
    return [_camera zoom];
}

- (CGFloat)minZoom
{
    if (!_camera) {
        return 0.0;
    }
    return [_camera minZoom];
}

- (CGFloat)maxZoom
{
    if (!_camera) {
        return 0.0;
    }
    return [_camera maxZoom];
}

- (void)setZoom:(CGFloat)zoom withAnimated:(BOOL)animated
{
    if (!_camera) {
        return;
    }
    [_camera setZoom:zoom withAnimated:animated];
}

#pragma mark - SYCameraDelegate


- (void)cameraDidFinishProcessingPhoto:(AVCapturePhoto *)photo error:(NSError *)error
{
    if (_delegateCache.cameraDidFinishProcessingPhoto) {
        NSData *imageData = [photo fileDataRepresentation];
        if (imageData == nil) {
            [_delegate cameraDidFinishProcessingPhoto:nil withMetaData:nil withManager:self withError:error];
            return;
        }
        SYPreviewView *previewView = _previewViews[@(_camera.cameraPosition)];
        UIImage *image = [[UIImage alloc] initWithData:imageData];
        CGFloat ratio = CGRectGetWidth(previewView.frame) / CGRectGetHeight(previewView.frame);
        UIImage *fixImage = [image fixImageWithOrientation:image.imageOrientation withRatio:ratio];
        
        if (fixImage == nil) {
            [_delegate cameraDidFinishProcessingPhoto:nil withMetaData:nil withManager:self withError:error];
            return;
        }
        
        [_delegate cameraDidFinishProcessingPhoto:fixImage withMetaData:photo.metadata withManager:self withError:error];
    }
}

- (void)cameraDidStarted
{
    if (_delegateCache.cameraDidStarted) {
        [_delegate cameraDidStarted:self];
    }
}

- (void)cameraDidStoped
{
    if (_delegateCache.cameraDidStoped) {
        [_delegate cameraDidStoped:self];
    }
}

- (void)cameraCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (_camera && _recorder && _camera.mode == SYVideoMode && _recordStatus == SYRecording) {
        [_recorder appendVideo:sampleBuffer];
    }
    if (_delegateCache.cameraDidOutputSampleBuffer) {
        [_delegate cameraDidOutputSampleBuffer:sampleBuffer];
    }
}

- (void)cameraCaptureAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (_camera && _recorder && _camera.mode == SYVideoMode && _recordStatus == SYRecording) {
        [_recorder appendAudio:sampleBuffer];
    }
}

- (void)cameraDidChangePosition:(BOOL)backFacing
{
    if (_delegateCache.changedPosition) {
        [_delegate cameraDidChangedPosition:backFacing withManager:self];
    }
}

- (void)cameraDidChangeFocus:(CGPoint)value mode:(AVCaptureFocusMode)mode
{
    if (_delegateCache.changedFocus) {
        [_delegate cameraDidChangedFocus:value mode:mode withManager:self];
    }
}

- (void)cameraDidChangeZoom:(CGFloat)value
{
    if (_delegateCache.changedZoom) {
        [_delegate cameraDidChangedZoom:value withManager:self];
    }
}

- (void)cameraDidChangeExposure:(CGPoint)value mode:(AVCaptureExposureMode)mode
{
    if (_delegateCache.changedExposure) {
        [_delegate cameraDidChangedExposure:value mode:mode withManager:self];
    }
}

- (void)camerahDidChangeFlash:(AVCaptureFlashMode)mode
{
    if (_delegateCache.changedFlash) {
        [_delegate camerahDidChangedFlash:mode withManager:self];
    }
}

- (void)cameraDidChangeEV:(CGFloat)value
{
    if (_delegateCache.changedEV) {
        [_delegate cameraDidChangedEV:value withManager:self];
    }
}

- (void)cameraWillProcessPhoto
{
    if (_delegateCache.cameraWillCapturePhoto) {
        [_delegate cameraWillCapturePhoto:self];
    }
}

- (void)cameraDidChangeMode:(SYCameraMode)mode
{
    if (_delegateCache.cameraDidChangeMode) {
        [_delegate cameraDidChangeMode:mode withManager:self];
    }
}

- (SYPreviewView *)getVideoPreviewForPosition:(AVCaptureDevicePosition)position
{
    return _previewViews[@(position)];
}


@end
