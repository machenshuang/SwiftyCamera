//
//  UIImage+SYImage.h
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/24.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIImage (SYImage)

- (UIImage *)fixImageWithRatio:(CGFloat)ratio isFront:(BOOL)isFront;

+ (UIImage * _Nullable)stitchDualImages:(NSArray<UIImage *> *)images andRects:(NSArray<NSValue *> *)rects;

@end

NS_ASSUME_NONNULL_END
