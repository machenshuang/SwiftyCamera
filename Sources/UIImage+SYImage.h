//
//  UIImage+SYImage.h
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/24.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (SYImage)

- (UIImage *)fixImageWithOrientation:(UIImageOrientation)ori withCropRect:(CGRect)rect;

@end

NS_ASSUME_NONNULL_END
