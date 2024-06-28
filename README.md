---
theme: smartblue
---

# SwiftyCamera

[SwiftyCamera](https://github.com/machenshuang/SwiftyCamera) 是基于 Objective-C 开发的一个轻量级相机 SDK，其目的是想让开发相机应用的开发者更快速的集成相机功能。

## 集成方式

在 Podfile 中引入：
```ruby
pod 'SwiftyCamera' :git => 'https://github.com/machenshuang/SwiftyCamera', :branch => 'master'
```

## 功能介绍

### 相机创建

创建相机前，需要先获取访问相机的权限，如果是录制还需要申请访问麦克风权限。SwiftyCamera 通过 SYCameraManager 来管理相机的生命周期和功能实现，通过 SYCameraManagerDelegate 来回调结果。

对于创建相机，需要先配置好参数，SwiftyCamera 用 SYCameraConfig 封装相机常用参数，如下图所示：
```objc
// 相机模式
typedef NS_ENUM(NSUInteger, SYCameraMode) {
    SYPhotoMode,    // 拍照模式
    SYVideoMode,    // 录制模式
    SYModeUnspecified,  // 未定义模式
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
```

配置完 config 后，则通过 SYCameraManager 的 requestCameraWithConfig:withCompletion: 方法开始创建相机：
```objc
/// 创建相机
/// - Parameters:
///   - config: SYCameraConfig
///   - completion: 创建回调
- (void)requestCameraWithConfig:(SYCameraConfig *)config withCompletion:(void(^)(BOOL isAuthority))completion;
```

若回调成功，需要将相机的预览视图添加到展示的 View，目前预览视图的宽高和 View 是一样的，内部做了约束：
```objc
/// 将预览视图添加到 View 上
/// - Parameter view: 展示的 View
- (void)addPreviewToView:(UIView *)view;
```

之后便可以调用 SYCameraManager 的 startCapture 方法启动相机流，也可以通过 stopCapture 停止相机流：
```
/// 启动相机流
- (void)startCapture;

/// 停止相机流
- (void)stopCapture;
```
delegate 也会回调相应的状态
 
```objc
/// 相机已启动
/// - Parameter manager: SYCameraManager
- (void)cameraDidStarted:(SYCameraManager *)manager;


/// 相机已停止
/// - Parameter manager: SYCameraManager
- (void)cameraDidStoped:(SYCameraManager *)manager;
```

综上所述，初始化相机其启动相机流的代码如下所示：
```swift
let config = SYCameraConfig()
config.mode = cameraMode
let cameraManager = SYCameraManager()
// 初始值相机
cameraManager.requestCamera(with: config) { [weak self](ret) in
    guard let `self` = self else { return }
    if ret {
        self.cameraManager.delegate = self  // 设置 delegate，用于回调内容
        self.cameraManager.addPreview(to: self.previewView) // 设置容器，用于展示相机预览
        self.cameraManager.startCapture() // 启动相机
    }
}
```

### 相机拍照

SwiftyCamera 提供了拍照功能，通过 SYCameraManager 的 takePhoto 方法实现拍照：
```objc
/// 拍照

- (void)takePhoto;
```

拍照结果通过 SYCameraManagerDelegate 回调回来：
```objc
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
```

### 视频录制

SwiftyCamera 提供了视频录制功能，通过 SYCameraManager 的 startRecord 启动录制，stopRecord 结束录制：
```objc
/// 开始录屏
- (void)startRecord;

/// 结束录屏
- (void)stopRecord;
```

录制结果通过 SYCameraManagerDelegate 回调回来：
```objc
/// 相机录制结果
/// - Parameters:
///   - outputURL: 保存路径
///   - manager: SYCameraManager
///   - error: error
- (void)cameraDidFinishProcessingVideo:(NSURL *_Nullable)outputURL
                           withManager:(SYCameraManager *)manager
                             withError:(NSError *_Nullable)error;
```

### 其他

除此之外，SwiftCamera 提供了摄像头切换、焦距调整等其他功能：
```objc
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

/// 调整缩放值
/// - Parameters:
///   - zoom: value
///   - animated: 是否带动画
- (void)setZoom:(CGFloat)zoom withAnimated:(BOOL)animated;
```


## Author

chenshuangma@foxmail.com

## License

SwiftyCamera is available under the MIT license. See the LICENSE file for more info.
