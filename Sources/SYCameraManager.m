//
//  SYCameraManager.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/5/25.
//

#import "SYCameraManager.h"
#import "SYCamera.h"
#import "SYPreviewView.h"
#import "SYRecorder.h"
#import "UIImage+SYImage.h"

typedef struct SYCameraManagerDelegateCache {
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
} SYCameraManagerDelegateCache;

@interface SYCameraManager () <SYCameraDelegate>
{
    SYCamera *_camera;
    SYPreviewView *_previewView;
    SYCameraManagerDelegateCache _delegateCache;
    SYRecorder *_recorder;
    CGSize _sampleBufferSize;
    BOOL _audioProcessing;
}

@property (nonatomic, assign, readwrite) BOOL isAuthority;
@property (nonatomic, assign, readwrite) SYRecordStatus recordStatus;

@end

@implementation SYCameraManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _sampleBufferSize = CGSizeMake(1080, 1920);
        _previewView = [SYPreviewView new];
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
    
    AVCaptureSessionPreset preset = config.sessionPreset;
    AVCaptureDevicePosition position = config.devicePosition;
    SYCameraMode mode = config.mode;
    if (position == AVCaptureDevicePositionUnspecified) {
        position = AVCaptureDevicePositionBack;
    }
    
    if (mode == SYModeUnspecified) {
        mode = SYPhotoMode;
    }
    
    if (preset == nil) {
        if (mode == SYPhotoMode) {
            preset = AVCaptureSessionPresetPhoto;
        } else {
            preset = AVCaptureSessionPresetHigh;
        }
    }
    
    _camera = [[SYCamera alloc] initWithSessionPreset:preset cameraPosition:position withMode:mode];
    _camera.delegate = self;
    _previewView.session = _camera.session;
    _camera.orientation = [self convertOrientation:self.deviceOrientation];
    completion(self.isAuthority);
}

- (void)changeCameraMode:(SYCameraMode)mode withSessionPreset:(AVCaptureSessionPreset)preset
{
    if (!_camera) {
        return;
    }
    
    if (mode == SYModeUnspecified) {
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
    if (_previewView.superview != nil) {
        [_previewView removeFromSuperview];
    }
    [view addSubview:_previewView];
    
    // 有性能优化，精准控制布局
    _previewView.translatesAutoresizingMaskIntoConstraints = NO;
    [view addConstraints:@[
        [NSLayoutConstraint constraintWithItem:_previewView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeLeading multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:_previewView attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTrailing multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:_previewView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeBottom multiplier:1 constant:0],
        [NSLayoutConstraint constraintWithItem:_previewView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTop multiplier:1 constant:0],
    ]];
}

- (void)setDelegate:(id<SYCameraManagerDelegate>)delegate
{
    _delegate = delegate;
    _delegateCache.cameraDidStarted = [delegate respondsToSelector:@selector(cameraDidStarted:withError:)];
    _delegateCache.cameraDidStoped = [delegate respondsToSelector:@selector(cameraDidStoped:withError:)];
    _delegateCache.cameraDidOutputSampleBuffer = [delegate respondsToSelector:@selector(cameraDidOutputSampleBuffer:withManager:)];
    _delegateCache.cameraDidFinishProcessingPhoto = [delegate respondsToSelector:@selector(cameraDidFinishProcessingPhoto:withMetaData:withManager:withError:)];
    _delegateCache.changedPosition = [delegate respondsToSelector:@selector(cameraDidChangedPosition:withManager:withError:)];
    _delegateCache.changedFocus = [delegate respondsToSelector:@selector(cameraDidChangedFocus:mode:withManager:withError:)];
    _delegateCache.changedZoom = [delegate respondsToSelector:@selector(cameraDidChangedZoom:withManager:withError:)];
    _delegateCache.changedExposure = [delegate respondsToSelector:@selector(cameraDidChangedExposure:mode:withManager:withError:)];
    _delegateCache.changedFlash = [delegate respondsToSelector:@selector(camerahDidChangedFlash:withManager:withError:)];
    _delegateCache.changedEV = [delegate respondsToSelector:@selector(cameraDidChangedEV:withManager:withError:)];
    _delegateCache.cameraWillCapturePhoto = [delegate respondsToSelector:@selector(cameraWillCapturePhoto:)];
    _delegateCache.cameraDidChangeMode = [delegate respondsToSelector:@selector(cameraDidChangeMode:withManager:error:)];
    _delegateCache.cameraDidFinishProcessingVideo = [delegate respondsToSelector:@selector(cameraDidFinishProcessingVideo:withManager:withError:)];
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
        return;
    }
    
    if (_audioProcessing) {
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
        return SYModeUnspecified;
    }
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
        UIImage *image = [[UIImage alloc] initWithData:imageData];
        CGFloat ratio = CGRectGetWidth(_previewView.frame) / CGRectGetHeight(_previewView.frame);
        UIImage *fixImage = [image fixImageWithOrientation:image.imageOrientation withRatio:ratio];
        
        
        if (fixImage == nil) {
            [_delegate cameraDidFinishProcessingPhoto:nil withMetaData:nil withManager:self withError:error];
            return;
        }
        
        [_delegate cameraDidFinishProcessingPhoto:fixImage withMetaData:photo.metadata withManager:self withError:error];
    }
}

- (void)cameraDidStarted:(NSError * _Nullable)error 
{
    if (_delegateCache.cameraDidStarted) {
        [_delegate cameraDidStarted:self withError:error];
    }
}

- (void)cameraDidStoped:(NSError * _Nullable)error 
{
    if (_delegateCache.cameraDidStoped) {
        [_delegate cameraDidStoped:self withError:error];
    }
}

- (void)cameraCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (_camera && _recorder && _camera.mode == SYVideoMode && _recordStatus == SYRecording) {
        [_recorder appendVideo:sampleBuffer];
    }
    if (_delegateCache.cameraDidOutputSampleBuffer) {
        [_delegate cameraDidOutputSampleBuffer:sampleBuffer withManager:self];
    }
}

- (void)cameraCaptureAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (_camera && _recorder && _camera.mode == SYVideoMode && _recordStatus == SYRecording) {
        [_recorder appendAudio:sampleBuffer];
    }
}

- (void)cameraDidChangePosition:(BOOL)backFacing error:(NSError *_Nullable)error
{
    if (_delegateCache.changedPosition) {
        [_delegate cameraDidChangedPosition:backFacing withManager:self withError:error];
    }
}

- (void)cameraDidChangeFocus:(CGPoint)value mode:(AVCaptureFocusMode)mode error:(NSError *_Nullable)error
{
    if (_delegateCache.changedFocus) {
        [_delegate cameraDidChangedFocus:value mode:mode withManager:self withError:error];
    }
}

- (void)cameraDidChangeZoom:(CGFloat)value error:(NSError *_Nullable)error
{
    if (_delegateCache.changedZoom) {
        [_delegate cameraDidChangedZoom:value withManager:self withError:error];
    }
}

- (void)cameraDidChangeExposure:(CGPoint)value mode:(AVCaptureExposureMode)mode error:(NSError *_Nullable)error
{
    if (_delegateCache.changedExposure) {
        [_delegate cameraDidChangedExposure:value mode:mode withManager:self withError:error];
    }
}

- (void)camerahDidChangeFlash:(AVCaptureFlashMode)mode error:(NSError *_Nullable)error
{
    if (_delegateCache.changedFlash) {
        [_delegate camerahDidChangedFlash:mode withManager:self withError:error];
    }
}

- (void)cameraDidChangeEV:(CGFloat)value error:(NSError *_Nullable)error
{
    if (_delegateCache.changedEV) {
        [_delegate cameraDidChangedEV:value withManager:self withError:error];
    }
}

- (void)cameraWillProcessPhoto
{
    if (_delegateCache.cameraWillCapturePhoto) {
        [_delegate cameraWillCapturePhoto:self];
    }
}

- (void)cameraDidChangeMode:(SYCameraMode)mode error:(NSError *)error
{
    if (_delegateCache.cameraDidChangeMode) {
        [_delegate cameraDidChangeMode:mode withManager:self error:error];
    }
}

@end
