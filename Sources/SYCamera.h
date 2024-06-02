//
//  SYCamera.h
//  SwiftyCamera
//
//  Created by 马陈爽 on 2023/4/6.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol SYCameraDelegate <NSObject>

@required
- (void)cameraDidStarted:(NSError *_Nullable)error;
- (void)cameraDidStoped:(NSError *_Nullable)error;
- (void)cameraDidFinishProcessingPhoto:(AVCapturePhoto *_Nullable)photo
                                 error:(NSError *_Nullable)error;
@optional
- (void)cameraDidOutputSampleBuffer:(CMSampleBufferRef _Nullable)sampleBuffer;
- (void)cameraDidChangePosition:(BOOL)backFacing error:(NSError *_Nullable)error;
- (void)cameraDidChangeFocus:(CGPoint)value mode:(AVCaptureFocusMode)mode error:(NSError *_Nullable)error;
- (void)cameraDidChangeZoom:(CGFloat)value error:(NSError *_Nullable)error;
- (void)cameraDidChangeExposure:(CGPoint)value mode:(AVCaptureExposureMode)mode error:(NSError *_Nullable)error;
- (void)camerahDidChangeFlash:(AVCaptureFlashMode)mode error:(NSError *_Nullable)error;
- (void)cameraDidChangeEV:(CGFloat)value error:(NSError *_Nullable)error;
- (void)cameraWillCapturePhoto;

@end

@interface SYCamera : NSObject

@property (nonatomic, assign) AVCaptureFlashMode flashMode;
@property (nonatomic, assign) CGFloat zoom;
@property (nonatomic, assign, readonly) CGFloat minZoom;
@property (nonatomic, assign, readonly) CGFloat maxZoom;
@property (nonatomic, assign) BOOL enableOfZoomAnimation;
@property (nonatomic, assign) CGFloat ev;
@property (nonatomic, assign, readonly) AVCaptureDevicePosition cameraPosition;
@property (nonatomic, copy, readonly) AVCaptureSession *session;
@property (nonatomic, assign) AVCaptureVideoOrientation orientation;

@property (nullable, nonatomic, weak) id<SYCameraDelegate> delegate;

- (instancetype)initWithSessionPreset:(AVCaptureSessionPreset)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition;
- (void)startCapture;
- (void)stopCapture;
- (void)changeCameraPosition:(AVCaptureDevicePosition)position;
- (void)focusWithPoint:(CGPoint)point mode:(AVCaptureFocusMode)mode;
- (void)exposureWithPoint:(CGPoint)point mode:(AVCaptureExposureMode)mode;
- (void)takePhoto;

@end

NS_ASSUME_NONNULL_END
