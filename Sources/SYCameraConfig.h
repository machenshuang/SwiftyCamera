//
//  SYCameraConfig.h
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/5/26.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SYCameraMode) {
    SKPhotoMode,
    SKVideoMode,
    SKModeUnspecified,
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
