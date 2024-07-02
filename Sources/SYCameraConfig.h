//
//  SYCameraConfig.h
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/5/26.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "SYPreviewView.h"

NS_ASSUME_NONNULL_BEGIN


typedef NS_ENUM(NSUInteger, SYDeviceType) {
    SYSingleDevice,   // 单摄
    SYDualDevice, // 前后摄
};


typedef NS_ENUM(NSUInteger, SYCameraMode) {
    SYPhotoMode,    // 拍照模式
    SYVideoMode,    // 录制模式
};

typedef NS_ENUM(NSUInteger, SYRecordStatus) {
    SYRecordNormal,
    SYRecordPause,
    SYRecording,
};

@interface SYCameraConfig : NSObject

@property (nonatomic, assign) SYDeviceType type;
@property (nonatomic, assign) SYCameraMode mode;
@property (nonatomic, assign) AVCaptureDevicePosition devicePosition;
@property (nonatomic, copy, nullable) AVCaptureSessionPreset sessionPreset;
@property (nonatomic, copy, nullable) NSDictionary<NSNumber *, NSValue *> *previewViewRects;


- (instancetype)init;

/// 初始化相机配置
/// - Parameters:
///   - devicePosition: AVCaptureDevicePosition
///   - mode: 相机模式，SYCameraMode
- (instancetype)initWithMode:(SYCameraMode)mode
                withPosition:(AVCaptureDevicePosition)devicePosition;

/// 初始化相机配置
/// - Parameters:
///   - devicePosition: AVCaptureDevicePosition
///   - mode: 相机模式，SYCameraMode
///   - type: 摄像头类型 SYDeviceType
- (instancetype)initWithMode:(SYCameraMode)mode
                    withType:(SYDeviceType)type
                withPosition:(AVCaptureDevicePosition)devicePosition;
@end

NS_ASSUME_NONNULL_END
