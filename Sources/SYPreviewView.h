//
//  SYPreviewView.h
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/5/25.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SYPreviewView : UIView

@property (nonnull, nonatomic, copy, readonly) AVCaptureVideoPreviewLayer *previewLayer;
@property (nullable, nonatomic, strong) AVCaptureSession *session;

@end

NS_ASSUME_NONNULL_END
