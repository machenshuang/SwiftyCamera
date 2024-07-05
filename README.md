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

SwiftyCamera 通过 SYCameraConfig 配置相机的参数，使用 SYCameraManager 来管理相机对象，并用 SYCameraManagerDelegate 将相机的生命周期和状态回调给使用者。

### 构建单摄相机

构建单摄相机的过程：
```swift
let config = SYCameraConfig()
config.type = .singleDevice  // 单摄模式  
config.mode = .photoMode  // 拍照模式
cameraManager.requestCamera(with: config) { [weak self](ret) in
    guard let `self` = self else { return }
    if ret == .success {
        // 设置 delegate
        self.cameraManager.delegate = self 
        // 将预览视图添加到 View 上
        self.cameraManager.addPreview(to: self.previewView) 
        // 启动相机
        self.cameraManager.startCapture()  
    }
}
```

构建和启动结果会通过 SYCameraManagerDelegate 方法回调：
```swift
extension ViewController: SYCameraManagerDelegate {
    /// 相机配置结果
    /// - Parameters:
    ///   - result: SYSessionSetupResult
    ///   - manager: SYCameraManager
    func cameraSessionSetupResult(_ result: SYSessionSetupResult, with manager: SYCameraManager) {
        
    }
    
    /// 相机已启动
    /// - Parameter manager: SYCameraManager
    func cameraDidStarted(_ manager: SYCameraManager) {
        
    }
    
    /// 相机已停止
    /// - Parameter manager: SYCameraManager
    func cameraDidStoped(_ manager: SYCameraManager) {
        
    }    
}

```

### 切换摄像头

摄像头切换的过程：
```swift
@objc private func cameraFilp() {
    // 判断相机状态
    if cameraManager.result == .success {
        isBacking = !isBacking
        // 切换摄像头
        cameraManager.changeCameraPosition(isBacking ? .back : .front)
    }
}
```



### 切换拍照和录制模式
切换拍照和录制模式如下代码所示：
```swift 
@objc private func changeCameraMode(_ control: UISegmentedControl) {
    if cameraManager.result != .success {
        return
   }
    if control.selectedSegmentIndex == 0 {
        // 切换拍照模式
        cameraManager.changeCameraMode(.photoMode, withSessionPreset: nil)
    } else if control.selectedSegmentIndex == 1 {
        // 切换录制模式
        cameraManager.changeCameraMode(.videoMode, withSessionPreset: nil)
    }
}
```

摄像头切换后的结果会通过 SYCameraManagerDelegate 方法回调：
```swift
extension ViewController: SYCameraManagerDelegate {
    /// 相机设备切换改变
    /// - Parameters:
    ///   - backFacing: 是否是后置
    ///   - manager: SYCameraManager
    func cameraDidChangedPosition(_ backFacing: Bool, with manager: SYCameraManager) {
        
    } 
}
```

### 调整焦点和曝光
调整焦点和曝光的过程：
```swift
@objc private func handleTapEvent(_ sender: UITapGestureRecognizer) {
    if cameraManager.result != .success {
        return
    }
    let point = sender.location(in: previewView)
    cameraManager.focus(with: point, mode: .autoFocus)
    cameraManager.exposure(with: point, mode: .autoExpose)
}
```
调整焦点和曝光的结果会通过 SYCameraManagerDelegate 方法回调：
```swift
extension ViewController: SYCameraManagerDelegate {
    /// 相机焦点调整改变
    /// - Parameters:
    ///   - value: 位置
    ///   - mode: 模式
    ///   - manager: SYCameraManager
    func cameraDidChangedFocus(_ value: CGPoint, mode: AVCaptureDevice.FocusMode, with manager: SYCameraManager) {
        
    }
    
    /// 相机曝光值调整改变
    /// - Parameters:
    ///   - value: 曝光值
    ///   - mode: 模式
    ///   - manager: SYCameraManager
    func cameraDidChangedExposure(_ value: CGPoint, mode: AVCaptureDevice.ExposureMode, with manager: SYCameraManager) {
        
    }
}
```

### 调整焦距
调整焦距的过程：
```objc
@objc private func handlePinchEvent(_ sender: UIPinchGestureRecognizer) {

    if cameraManager.result != .success {
        return
    }

    let scale = sender.scale
    currentZoom = scale;
    cameraManager.setZoom(currentZoom, withAnimated: true)
}
```
调整焦距的结果会通过 SYCameraManagerDelegate 方法回调：
```swift
extension ViewController: SYCameraManagerDelegate {
    /// 相机焦距调整改变
    /// - Parameters:
    ///   - value: 焦距
    ///   - manager: SYCameraManager
    func cameraDidChangedZoom(_ value: CGFloat, with manager: SYCameraManager) {
    
    }
}
```

### 拍照

拍照的流程：
```swift
@objc private func takePhoto() {
    if cameraManager.result != .success {
        return
    }
    cameraManager.takePhoto()
}
```

拍照的结果会通过 SYCameraManagerDelegate 方法回调：
```swift
extension ViewController: SYCameraManagerDelegate {
    /// 相机拍照结果
    /// - Parameters:
    ///   - image: 图片
    ///   - metaData: 摘要
    ///   - manager: SYCameraManager
    ///   - error: 错误
    func cameraDidFinishProcessingPhoto(_ image: UIImage?, withMetaData metaData: [AnyHashable : Any]?, with manager: SYCameraManager, withError error: Error?) {
        
    }
}
```
### 切换录制模式

切换录制模式流程：
```swift
@objc private func changeCameraMode(_ control: UISegmentedControl) {
    if cameraManager.result != .success {
        return
    }
    if control.selectedSegmentIndex == 0 {
        cameraManager.changeCameraMode(.photoMode, withSessionPreset: nil)
    } else if control.selectedSegmentIndex == 1 {
        cameraManager.changeCameraMode(.videoMode, withSessionPreset: nil)
    }
}
```
模式切换的结果会通过 SYCameraManagerDelegate 方法回调：
```swift
extension ViewController: SYCameraManagerDelegate {
    /// 相机模式改变
    /// - Parameters:
    ///   - mode: 模式
    ///   - manager: SYCameraManager
    func cameraDidChange(_ mode: SYCameraMode, with manager: SYCameraManager) {
    
    }
}
```

## 开始录制和结束录制

开始录制和结束录制如下代码所示：
```swift
@objc private func handleRecordEvent(_ button: UIButton) {
    if cameraManager.result != .success {
        return
    }
    if recordMode == .recordNormal {
        cameraManager.startRecord()
    } else {
        cameraManager.stopRecord()
    }
}
```

录制状态和录制结果会通过 SYCameraManagerDelegate 方法回调：
```swift
extension ViewController: SYCameraManagerDelegate {
    
    /// 相机录制结果
    /// - Parameters:
    ///   - outputURL: 保存路径
    ///   - manager: SYCameraManager
    ///   - error: error
    func cameraDidFinishProcessingVideo(_ outputURL: URL?, with manager: SYCameraManager, withError error: Error?) {
        
    }
    
    /// 相机录制状态改变
    /// - Parameters:
    ///   - status: 录制状态
    ///   - manager: SYCameraManager
    func cameraRecordStatusDidChange(_ status: SYRecordStatus, with manager: SYCameraManager) {
        
    }    
}
```
### 构建双摄相机

双摄相机构建前，需要先判断当前设备和系统是否支持：
```swift

if SYCameraManager.isMultiCamSupported() {
    // 开始构建双摄相机 
}

```

双摄相机构建流程：
```swift
let config = SYCameraConfig()
config.type = .dualDevice  // 双摄模式  
config.mode = .photoMode  // 拍照模式
cameraManager.requestCamera(with: config) { [weak self](ret) in
    guard let `self` = self else { return }
    if ret == .success {
        // 设置 delegate
        self.cameraManager.delegate = self 
        // 将预览视图添加到 View 上
        self.cameraManager.addPreview(to: self.previewView) 
        // 启动相机
        self.cameraManager.startCapture()  
    }
}
```

构建和启动结果会通过 SYCameraManagerDelegate 方法回调：
```swift
extension ViewController: SYCameraManagerDelegate {
    /// 相机配置结果
    /// - Parameters:
    ///   - result: SYSessionSetupResult
    ///   - manager: SYCameraManager
    func cameraSessionSetupResult(_ result: SYSessionSetupResult, with manager: SYCameraManager) {
        
    }
    
    /// 相机已启动
    /// - Parameter manager: SYCameraManager
    func cameraDidStarted(_ manager: SYCameraManager) {
        
    }
    
    /// 相机已停止
    /// - Parameter manager: SYCameraManager
    func cameraDidStoped(_ manager: SYCameraManager) {
        
    }    
}

```

## Author

chenshuangma@foxmail.com

## License

SwiftyCamera is available under the MIT license. See the LICENSE file for more info.
