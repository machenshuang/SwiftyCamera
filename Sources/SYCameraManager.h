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
- (void)cameraDidStarted:(SYCameraManager *)manager;
- (void)cameraDidStoped:(SYCameraManager *)manager;
- (void)cameraDidFinishProcessingPhoto:(UIImage *_Nullable)image
                          withMetaData:(NSDictionary *_Nullable)metaData
                           withManager:(SYCameraManager *)manager
                             withError:(NSError *_Nullable)error;
- (void)cameraDidFinishProcessingVideo:(NSURL *_Nullable)outputURL
                           withManager:(SYCameraManager *)manager
                             withError:(NSError *_Nullable)error;
@optional
- (void)cameraDidOutputSampleBuffer:(CMSampleBufferRef _Nullable)sampleBuffer;

- (void)cameraDidChangedPosition:(BOOL)backFacing
                     withManager:(SYCameraManager *)manager;

- (void)cameraDidChangedFocus:(CGPoint)value mode:(AVCaptureFocusMode)mode
                  withManager:(SYCameraManager *)manager;

- (void)cameraDidChangedZoom:(CGFloat)value
                 withManager:(SYCameraManager *)manager;

- (void)cameraDidChangedExposure:(CGPoint)value mode:(AVCaptureExposureMode)mode
                     withManager:(SYCameraManager *)manager;

- (void)camerahDidChangedFlash:(AVCaptureFlashMode)mode
                   withManager:(SYCameraManager *)manager;

- (void)cameraDidChangedEV:(CGFloat)value
               withManager:(SYCameraManager *)manager;

- (void)cameraWillCapturePhoto:(SYCameraManager *)manager;

- (void)cameraDidChangeMode:(SYCameraMode)mode
                withManager:(SYCameraManager *)manager;

- (void)cameraRecordStatusDidChange:(SYRecordStatus)status
                        withManager:(SYCameraManager *)manager;


@end

@interface SYCameraManager : NSObject

@property (nullable, nonatomic, weak) id<SYCameraManagerDelegate> delegate;
@property (nonatomic, assign, readonly) BOOL isAuthority;
@property (nonatomic, assign) UIDeviceOrientation deviceOrientation;
@property (nonatomic, assign, readonly) SYRecordStatus recordStatus;
@property (nonatomic, assign, readonly) SYCameraMode cameraMode;


- (void)requestCameraWithConfig:(SYCameraConfig *)config withCompletion:(void(^)(BOOL isAuthority))completion;

- (void)addPreviewToView:(UIView *)view;

/// 启动相机流
- (void)startCapture;

/// 停止相机流
- (void)stopCapture;

/// 切换相机前后置
/// - Parameter position: AVCaptureDevicePosition
- (void)changeCameraPosition:(AVCaptureDevicePosition)position;

- (void)changeCameraMode:(SYCameraMode)mode
       withSessionPreset:(nullable AVCaptureSessionPreset)preset;

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

/// 开始录屏
- (void)startRecord;

/// 结束录屏
- (void)stopRecord;



@end

NS_ASSUME_NONNULL_END
