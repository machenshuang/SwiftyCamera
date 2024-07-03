//
//  UIImage+SYImage.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/24.
//

#import "UIImage+SYImage.h"

@implementation UIImage (SYImage)

- (UIImage *)fixImageWithRatio:(CGFloat)ratio isFront:(BOOL)isFront {
    // CGContext 理解成依附在画布上的一个窗口，画布严格遵循笛卡尔坐标系，窗口内的数据可见，窗口外的数据会被裁剪
    // transform 是影响画布的绘制起点坐标轴的位置、走向、x轴y轴的方向，窗口的位置仍然不变，且坐标方向不变
    // 当进行绘制的时候，严格按照从(0,0)开始
    CGImageRef cgImage = self.CGImage;
    int width = (int)CGImageGetWidth(cgImage);
    int height = (int)CGImageGetHeight(cgImage);
    
    CGRect cropRect;
    
    if (ratio > 0) {
        cropRect = [self calculateCropRect:CGSizeMake(height, width) ratio:ratio];
    } else {
        cropRect = CGRectMake(0, 0, width, height);
    }
    
    int contextW = CGRectGetWidth(cropRect);
    int contextH = CGRectGetHeight(cropRect);
    // x 轴向左，y 轴向上
    CGAffineTransform transform = CGAffineTransformIdentity;
    transform = CGAffineTransformTranslate(transform, 0, width);
    transform = CGAffineTransformRotate(transform, -M_PI_2);
    // x 轴向下，y 轴向右
    if (isFront) {
        transform = CGAffineTransformTranslate(transform, 0, height);
        transform = CGAffineTransformScale(transform, 1, -1);
        // x 轴向下，y 轴向左
        transform = CGAffineTransformTranslate(transform,  (width-contextH)/2, (height-contextW)/2);
    } else {
        transform = CGAffineTransformTranslate(transform, (width-contextH)/2, -(height-contextW)/2);
    }
    
    CGColorSpaceRef colorSpace = CGImageGetColorSpace(cgImage);
    CGContextRef context = CGBitmapContextCreate(NULL, contextW, contextH, 8, contextW * 4, colorSpace, CGImageGetBitmapInfo(cgImage));
    CGContextConcatCTM(context, transform);
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGImageRef newCGImage = CGBitmapContextCreateImage(context);
    UIImage *newImage = [UIImage imageWithCGImage:newCGImage scale:1.0 orientation:UIImageOrientationUp];
    
    CGImageRelease(newCGImage);
    CGContextRelease(context);
    return newImage;
}

+ (UIImage *)stitchDualImages:(NSArray<UIImage *> *)images andRects:(NSArray<NSValue *> *)rects {
    size_t outputWidth;
    size_t outputHeigth;
    
    UIImage *firstImage = images[0];
    UIImage *secondImage = images[1];
    CGRect firstRect = [rects[0] CGRectValue];
    CGRect secondRect = [rects[1] CGRectValue];
    
    outputWidth = firstImage.size.width / firstRect.size.width;
    outputHeigth = firstImage.size.height / firstRect.size.height;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 outputWidth,
                                                 outputHeigth,
                                                 8,
                                                 outputWidth * 4,
                                                 colorSpace,
                                                 kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst);
    if (!context) return nil;
    CGContextDrawImage(context, CGRectMake(outputWidth * firstRect.origin.x, outputHeigth * (1 - firstRect.origin.y - firstRect.size.height), outputWidth * firstRect.size.width, outputHeigth * firstRect.size.height), firstImage.CGImage);
    CGContextDrawImage(context, CGRectMake(outputWidth * secondRect.origin.x, outputHeigth * (1 - secondRect.origin.y - secondRect.size.height), outputWidth * secondRect.size.width, outputHeigth * secondRect.size.height), secondImage.CGImage);
    CGImageRef imgRef = CGBitmapContextCreateImage(context);
    UIImage *img = [UIImage imageWithCGImage:imgRef scale:1.0 orientation:UIImageOrientationUp];
    CGImageRelease(imgRef);
    CGContextRelease(context);
    return img;
}

- (CGRect)calculateCropRect:(CGSize)size ratio:(CGFloat)ratio
{
    CGFloat cropW = size.width;
    CGFloat cropH = cropW / ratio;
    if (cropH > size.height) {
        cropH = size.height;
        cropW = cropH * ratio;
    }
    CGFloat cropX = (size.width - cropW) / 2;
    CGFloat cropY = (size.height - cropH) / 2;
    CGRect cropRect = CGRectMake((int)cropX, (int)cropY, (int)cropW, (int)cropH);
    return cropRect;
}

@end
