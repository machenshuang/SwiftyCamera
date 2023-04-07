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
- (void)cameraCaptureSampleBuffer:(CMSampleBufferRef _Nullable)sampleBuffer
                              withMetaData:(NSDictionary *_Nullable)metaData
                                     error:(NSError *_Nullable)error;
@optional
- (void)cameraDisplaySampleBuffer:(CMSampleBufferRef _Nullable)sampleBuffer;
- (void)cameraDidChangedPosition:(BOOL)backFacing error:(NSError *_Nullable)error;
- (void)cameraDidChangedFocus:(CGPoint)value mode:(AVCaptureFocusMode)mode error:(NSError *_Nullable)error;
- (void)cameraDidChangedZoom:(CGFloat)value error:(NSError *_Nullable)error;
- (void)cameraDidChangedExposure:(CGPoint)value mode:(AVCaptureExposureMode)mode error:(NSError *_Nullable)error;
- (void)camerahDidChangedFlash:(AVCaptureFlashMode)mode error:(NSError *_Nullable)error;
- (void)cameraDidChangedEV:(CGFloat)value error:(NSError *_Nullable)error;

@end

@interface SYCamera : NSObject

@property (nonatomic, assign) AVCaptureFlashMode flashMode;
@property (nonatomic, assign) CGFloat zoom;
@property (nonatomic, assign, readonly) CGFloat minZoom;
@property (nonatomic, assign, readonly) CGFloat maxZoom;
@property (nonatomic, assign) BOOL enableOfZoomAnimation;
@property (nonatomic, assign) CGFloat ev;
@property (nonatomic, assign, readonly) AVCaptureDevicePosition cameraPositon;

- (instancetype)initWithSessionPreset:(AVCaptureSessionPreset)sessionPreset cameraPosition:(AVCaptureDevicePosition)cameraPosition;
- (void)startCapture;
- (void)stopCapture;
- (void)changeCameraPosition:(AVCaptureDevicePosition)position;
- (void)focusWithPoint:(CGPoint)point mode:(AVCaptureFocusMode)mode;
- (void)exposureWithPoint:(CGPoint)point mode:(AVCaptureExposureMode)mode;
- (void)takePhoto;

@end

NS_ASSUME_NONNULL_END
