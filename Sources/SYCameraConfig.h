//
//  SYCameraConfig.h
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/5/26.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

// 相机模式
typedef NS_ENUM(NSUInteger, SYCameraMode) {
    SYPhotoMode,    // 拍照模式
    SYVideoMode,    // 录制模式
    SYModeUnspecified,  // 未定义模式
};

typedef NS_ENUM(NSUInteger, SYRecordStatus) {
    SYRecordNormal,
    SYRecordPause,
    SYRecording,
};

@interface SYCameraConfig : NSObject

@property (nonatomic, assign) SYCameraMode mode;
@property (nonatomic, copy, nullable) AVCaptureSessionPreset sessionPreset;
@property (nonatomic, assign) AVCaptureDevicePosition devicePosition;


- (instancetype)init;

/// 初始化相机配置
/// - Parameters:
///   - sessionPreset: AVCaptureSessionPreset
///   - devicePosition: AVCaptureDevicePosition
- (instancetype)initWithMode:(SYCameraMode)mode
           withSessionPreset:(AVCaptureSessionPreset)sessionPreset
                withPosition:(AVCaptureDevicePosition)devicePosition;


@end

NS_ASSUME_NONNULL_END
