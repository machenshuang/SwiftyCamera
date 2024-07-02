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

/// 相机已启动
/// - Parameter manager: SYCameraManager
- (void)cameraDidStarted:(SYCameraManager *)manager;


/// 相机已停止
/// - Parameter manager: SYCameraManager
- (void)cameraDidStoped:(SYCameraManager *)manager;


/// 相机拍照结果
/// - Parameters:
///   - image: 图片
///   - metaData: 摘要
///   - manager: SYCameraManager
///   - error: 错误
- (void)cameraDidFinishProcessingPhoto:(UIImage *_Nullable)image
                          withMetaData:(NSDictionary *_Nullable)metaData
                           withManager:(SYCameraManager *)manager
                             withError:(NSError *_Nullable)error;

/// 相机录制结果
/// - Parameters:
///   - outputURL: 保存路径
///   - manager: SYCameraManager
///   - error: error
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

@property (nonatomic, assign, readonly) CGFloat zoom;
@property (nonatomic, assign, readonly) CGFloat minZoom;
@property (nonatomic, assign, readonly) CGFloat maxZoom;


/// 是否支持多摄像头
+ (BOOL)isMultiCamSupported API_AVAILABLE(ios(13.0), macCatalyst(14.0), tvos(17.0)) API_UNAVAILABLE(macos, visionos) API_UNAVAILABLE(watchos);

/// 创建相机
/// - Parameters:
///   - config: SYCameraConfig
///   - completion: 创建回调
- (void)requestCameraWithConfig:(SYCameraConfig *)config withCompletion:(void(^)(BOOL isAuthority))completion;


/// 将预览视图添加到 View 上
/// - Parameter view: 展示的 View
- (void)addPreviewToView:(UIView *)view;

/// 启动相机流
- (void)startCapture;

/// 停止相机流
- (void)stopCapture;

/// 切换相机前后置
/// - Parameter position: AVCaptureDevicePosition
- (void)changeCameraPosition:(AVCaptureDevicePosition)position;


/// 切换模式
/// - Parameters:
///   - mode: SYCameraMode
///   - preset: AVCaptureSessionPreset
- (void)changeCameraMode:(SYCameraMode)mode
       withSessionPreset:(nullable AVCaptureSessionPreset)preset;


/// 调整相机焦距
/// - Parameters:
///   - point: 焦距位置
///   - mode: 模式
- (void)focusWithPoint:(CGPoint)point mode:(AVCaptureFocusMode)mode;


/// 调整相机曝光
/// - Parameters:
///   - point: 曝光位置
///   - mode: 模式
- (void)exposureWithPoint:(CGPoint)point mode:(AVCaptureExposureMode)mode;

/// 拍照
- (void)takePhoto;

/// 开始录屏
- (void)startRecord;

/// 结束录屏
- (void)stopRecord;


/// 调整缩放值
/// - Parameters:
///   - zoom: value
///   - animated: 是否带动画
- (void)setZoom:(CGFloat)zoom withAnimated:(BOOL)animated;

@end

NS_ASSUME_NONNULL_END
