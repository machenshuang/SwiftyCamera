//
//  SYBaseCamera.h
//  SwiftyCamera
//
//  Created by 马陈爽 on 2023/4/6.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SYCameraConfig.h"
#import "SYPreviewView.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SYCameraDelegate <NSObject>

@required
- (void)cameraDidStarted;
- (void)cameraDidStoped;
- (void)cameraDidFinishProcessingPhoto:(AVCapturePhoto *_Nullable)photo
                          withPosition:(AVCaptureDevicePosition)position
                                 error:(NSError *_Nullable)error;

- (void)cameraCaptureVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)cameraCaptureAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)cameraDidChangePosition:(BOOL)backFacing;
- (void)cameraDidChangeMode:(SYCameraMode)mode;
- (void)cameraDidChangeFocus:(CGPoint)value mode:(AVCaptureFocusMode)mode;
- (void)cameraDidChangeZoom:(CGFloat)value;
- (void)cameraDidChangeExposure:(CGPoint)value mode:(AVCaptureExposureMode)mode;
- (void)camerahDidChangeFlash:(AVCaptureFlashMode)mode;
- (void)cameraDidChangeEV:(CGFloat)value;
- (void)cameraWillProcessPhoto;
- (SYPreviewView *)getVideoPreviewForPosition:(AVCaptureDevicePosition)position;

@end

typedef struct SYCameraDelegateMap {
    unsigned int cameraDidStarted : 1;
    unsigned int cameraDidStoped : 1;
    unsigned int cameraCaptureVideoSampleBuffer : 1;
    unsigned int cameraCaptureAudioSampleBuffer : 1;
    unsigned int cameraDidFinishProcessingPhoto : 1;
    unsigned int changedPosition : 1;
    unsigned int changedFocus : 1;
    unsigned int changedZoom : 1;
    unsigned int changedExposure : 1;
    unsigned int changedFlash : 1;
    unsigned int changedEV : 1;
    unsigned int cameraWillProcessPhoto : 1;
    unsigned int cameraDidChangeMode: 1;
    unsigned int getVideoPreviewForPosition: 1;
} SYCameraDelegateMap;

@interface SYBaseCamera : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>

@property (nonatomic, assign) AVCaptureFlashMode flashMode;
@property (nonatomic, assign) CGFloat ev;
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, assign) AVCaptureVideoOrientation orientation;
@property (nonatomic, assign, readonly) CGFloat zoom;
@property (nonatomic, assign, readonly) CGFloat minZoom;
@property (nonatomic, assign, readonly) CGFloat maxZoom;
@property (nonatomic, assign, readonly) AVCaptureDevicePosition cameraPosition;
@property (nonatomic, assign, readonly) SYCameraMode mode;
@property (nonatomic, strong, readonly) dispatch_queue_t sessionQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t cameraProcessQueue;
@property (nonatomic, strong, readonly) dispatch_queue_t captureQueue;
@property (nonatomic, assign, readonly) SYCameraDelegateMap delegateMap;


@property (nullable, nonatomic, weak) id<SYCameraDelegate> delegate;

+(SYBaseCamera * _Nullable)createCameraWithConfig:(SYCameraConfig *)config withDelegate:(id<SYCameraDelegate>)delegate;

- (instancetype)initWithSessionPreset:(AVCaptureSessionPreset)sessionPreset
                       cameraPosition:(AVCaptureDevicePosition)cameraPosition
                             withMode:(SYCameraMode)mode
                         withDelegate:(id<SYCameraDelegate>)delegate;

- (void)setupCaptureSession;
- (BOOL)setupCameraDevice;
- (void)setupVideoDeviceInput;
- (void)setupVideoOutput;
- (void)setupPhotoOutput;
- (void)startCapture;
- (void)stopCapture;
- (void)changeCameraPosition:(AVCaptureDevicePosition)position;
- (void)changeCameraMode:(SYCameraMode)mode
       withSessionPreset:(AVCaptureSessionPreset)sessionPreset;
- (void)addMicrophoneWith:(void(^)(void))completion;
- (void)removeMicrophoneWith:(void(^)(void))completion;
- (void)focusWithPoint:(CGPoint)point mode:(AVCaptureFocusMode)mode;
- (void)exposureWithPoint:(CGPoint)point mode:(AVCaptureExposureMode)mode;
- (void)takePhoto;
- (void)setZoom:(CGFloat)zoom withAnimated:(BOOL)animated;
- (AVCaptureDevice *)fetchCameraDeviceWithPosition:(AVCaptureDevicePosition)position;


@end

NS_ASSUME_NONNULL_END
