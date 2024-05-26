//
//  SYCameraManager.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/5/25.
//

#import "SYCameraManager.h"
#import "SYCamera.h"
#import "SYPreviewView.h"

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
} SYCameraManagerDelegateCache;

@interface SYCameraManager () <SYCameraDelegate>
{
    SYCamera *_camera;
    SYPreviewView *_previewView;
    SYCameraManagerDelegateCache _delegateCache;
    SYCameraConfig *_config;
}

@property (nonatomic, assign, readwrite) BOOL isAuthority;

@end

@implementation SYCameraManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _previewView = [SYPreviewView new];
    }
    return self;
}

- (void)requestCameraWithConfig:(SYCameraConfig *)config 
                 withCompletion:(void (^)(BOOL))completion
{
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status != AVAuthorizationStatusAuthorized) {
        self.isAuthority = NO;
        completion(self.isAuthority);
        return;
    }
    _camera = [[SYCamera alloc] initWithSessionPreset:config.sessionPreset cameraPosition:config.devicePosition];
    _camera.delegate = self;
    _previewView.session = _camera.session;
    self.isAuthority = YES;
    completion(self.isAuthority);
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

- (UIImage *)imageFromPixelBuffer:(CVPixelBufferRef) pixelbuffer
{
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelbuffer];
    CIContext *context = [CIContext contextWithOptions:nil];
    CGImageRef videoImage = [context createCGImage:ciImage fromRect:CGRectMake(0, 0, CVPixelBufferGetWidth(pixelbuffer), CVPixelBufferGetHeight(pixelbuffer))];
    UIImage *image = [UIImage imageWithCGImage:videoImage];
    CGImageRelease(videoImage);
    return image;
}


#pragma mark - SYCameraDelegate


- (void)cameraDidFinishProcessingPixelBuffer:(CVPixelBufferRef _Nullable)pixelBuffer withMetaData:(NSDictionary * _Nullable)metaData error:(NSError * _Nullable)error 
{
    if (_delegateCache.cameraDidFinishProcessingPhoto) {
        if (pixelBuffer == nil) {
            [_delegate cameraDidFinishProcessingPhoto:nil withMetaData:metaData withManager:self withError:error];
            return;
        }
        UIImage *image = [self imageFromPixelBuffer:pixelBuffer];
        [_delegate cameraDidFinishProcessingPhoto:image withMetaData:metaData withManager:self withError:error];
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

- (void)cameraDidOutputSampleBuffer:(CMSampleBufferRef _Nullable)sampleBuffer
{
    if (_delegateCache.cameraDidOutputSampleBuffer) {
        [_delegate cameraDidOutputSampleBuffer:sampleBuffer withManager:self];
    }
}

- (void)cameraDidChangedPosition:(BOOL)backFacing error:(NSError *_Nullable)error
{
    if (_delegateCache.changedPosition) {
        [_delegate cameraDidChangedPosition:backFacing withManager:self withError:error];
    }
}

- (void)cameraDidChangedFocus:(CGPoint)value mode:(AVCaptureFocusMode)mode error:(NSError *_Nullable)error
{
    if (_delegateCache.changedFocus) {
        [_delegate cameraDidChangedFocus:value mode:mode withManager:self withError:error];
    }
}

- (void)cameraDidChangedZoom:(CGFloat)value error:(NSError *_Nullable)error
{
    if (_delegateCache.changedZoom) {
        [_delegate cameraDidChangedZoom:value withManager:self withError:error];
    }
}

- (void)cameraDidChangedExposure:(CGPoint)value mode:(AVCaptureExposureMode)mode error:(NSError *_Nullable)error
{
    if (_delegateCache.cameraDidStoped) {
        [_delegate cameraDidChangedExposure:value mode:mode withManager:self withError:error];
    }
}

- (void)camerahDidChangedFlash:(AVCaptureFlashMode)mode error:(NSError *_Nullable)error
{
    if (_delegateCache.changedFlash) {
        [_delegate camerahDidChangedFlash:mode withManager:self withError:error];
    }
}

- (void)cameraDidChangedEV:(CGFloat)value error:(NSError *_Nullable)error
{
    if (_delegateCache.changedEV) {
        [_delegate cameraDidChangedEV:value withManager:self withError:error];
    }
}

- (void)cameraWillCapturePhoto
{
    if (_delegateCache.cameraWillCapturePhoto) {
        [_delegate cameraWillCapturePhoto:self];
    }
}

@end
