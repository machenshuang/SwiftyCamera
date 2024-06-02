//
//  SYCameraManager.h
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/5/25.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>
#import "SYCameraConfig.h"
@class SYCameraManager;

NS_ASSUME_NONNULL_BEGIN



@protocol SYCameraManagerDelegate <NSObject>

@required
- (void)cameraDidStarted:(SYCameraManager *)manager withError:(NSError *_Nullable)error;
- (void)cameraDidStoped:(SYCameraManager *)manager withError:(NSError *_Nullable)error;
- (void)cameraDidFinishProcessingPhoto:(UIImage *_Nullable)image
                          withMetaData:(NSDictionary *_Nullable)metaData
                           withManager:(SYCameraManager *)manager
                             withError:(NSError *_Nullable)error;
@optional
- (void)cameraDidOutputSampleBuffer:(CMSampleBufferRef _Nullable)sampleBuffer
                        withManager:(SYCameraManager *)manager;

- (void)cameraDidChangedPosition:(BOOL)backFacing
                     withManager:(SYCameraManager *)manager
                       withError:(NSError *_Nullable)error;

- (void)cameraDidChangedFocus:(CGPoint)value mode:(AVCaptureFocusMode)mode
                  withManager:(SYCameraManager *)manager
                    withError:(NSError *_Nullable)error;

- (void)cameraDidChangedZoom:(CGFloat)value
                 withManager:(SYCameraManager *)manager
                   withError:(NSError *_Nullable)error;

- (void)cameraDidChangedExposure:(CGPoint)value mode:(AVCaptureExposureMode)mode
                     withManager:(SYCameraManager *)manager
                       withError:(NSError *_Nullable)error;

- (void)camerahDidChangedFlash:(AVCaptureFlashMode)mode
                   withManager:(SYCameraManager *)manager
                     withError:(NSError *_Nullable)error;

- (void)cameraDidChangedEV:(CGFloat)value
               withManager:(SYCameraManager *)manager
                 withError:(NSError *_Nullable)error;

- (void)cameraWillCapturePhoto:(SYCameraManager *)manager;

@end

@interface SYCameraManager : NSObject

@property (nullable, nonatomic, weak) id<SYCameraManagerDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isAuthority;
@property (nonatomic, assign) UIDeviceOrientation deviceOrientation;


- (void)requestCameraWithConfig:(SYCameraConfig *)config withCompletion:(void(^)(BOOL isAuthority))completion;

- (void)addPreviewToView:(UIView *)view;

/// 启动相机流
- (void)startCapture;

/// 停止相机流
- (void)stopCapture;

/// 切换相机前后置
/// - Parameter position: AVCaptureDevicePosition
- (void)changeCameraPosition:(AVCaptureDevicePosition)position;

/// 调整焦点
/// - Parameters:
///   - point: CGPoint
///   - mode: AVCaptureFocusMode
- (void)focusWithPoint:(CGPoint)point mode:(AVCaptureFocusMode)mode;

/// 调整曝光
/// - Parameters:
///   - point: CGPoint
///   - mode: AVCaptureExposureMode
- (void)exposureWithPoint:(CGPoint)point mode:(AVCaptureExposureMode)mode;

/// 拍照
- (void)takePhoto;



@end

NS_ASSUME_NONNULL_END
