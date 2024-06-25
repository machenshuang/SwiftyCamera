//
//  UIImage+SYImage.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/24.
//

#import "UIImage+SYImage.h"

@implementation UIImage (SYImage)

- (UIImage *)fixImageWithOrientation:(UIImageOrientation)ori withRatio:(CGFloat)ratio
{
    // CGContext 理解成依附在画布上的一个窗口，画布严格遵循笛卡尔坐标系，窗口内的数据可见，窗口外的数据会被裁剪
    // transform 是影响画布的绘制起点坐标轴的位置、走向、x轴y轴的方向，窗口的位置仍然不变
    // 当进行绘制的时候，严格按照从(0,0)开始
    CGImageRef cgImage = self.CGImage;
    int width = (int)CGImageGetWidth(cgImage);
    int height = (int)CGImageGetHeight(cgImage);
    
    CGRect cropRect = CGRectZero;
    
    if (ratio > 0) {
        switch (ori) {
            case UIImageOrientationLeft:
            case UIImageOrientationLeftMirrored:
            case UIImageOrientationRight:
            case UIImageOrientationRightMirrored: {
                cropRect = [self calculateCropRect:CGSizeMake(width, height) ratio:1/ratio];
                break;
            }
            default: {
                cropRect = [self calculateCropRect:CGSizeMake(width, height) ratio:ratio];
                break;
            }
        }
    } else {
        cropRect = CGRectMake(0, 0, width, height);
    }
    
    int contextW = CGRectGetWidth(cropRect);
    int contextH = CGRectGetHeight(cropRect);
    
    CGAffineTransform transform = CGAffineTransformIdentity;
    switch (ori) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored: {
            CGFloat translateW = contextW - (width - contextW) / 2;
            CGFloat translateH = contextH - (height - contextH) / 2;
            transform = CGAffineTransformTranslate(transform, translateW, translateH);
            transform = CGAffineTransformRotate(transform, M_PI);
            if (ori == UIImageOrientationDownMirrored) {
                transform = CGAffineTransformTranslate(transform, contextW, 0);
                transform = CGAffineTransformScale(transform, -1, 1);
            }
            break;
        }
        case UIImageOrientationLeft:
        case  UIImageOrientationLeftMirrored: {
            contextW = CGRectGetHeight(cropRect);
            contextH = CGRectGetWidth(cropRect);
            CGFloat translateW = contextW + (height - contextW) / 2;
            CGFloat translateH = - (width - contextH) / 2;
            transform = CGAffineTransformTranslate(transform, translateW, translateH);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            if (ori == UIImageOrientationLeftMirrored) {
                transform = CGAffineTransformTranslate(transform, contextH, 0);
                transform = CGAffineTransformScale(transform, -1, 1);
            }
            break;
        }
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored: {
            contextW = CGRectGetHeight(cropRect);
            contextH = CGRectGetWidth(cropRect);
            CGFloat translateW = - (height - contextW) / 2;
            CGFloat translateH = contextH - (width - contextH) / 2;
            transform = CGAffineTransformTranslate(transform, translateW, translateH);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            if (ori == UIImageOrientationLeftMirrored) {
                transform = CGAffineTransformTranslate(transform, contextH, 0);
                transform = CGAffineTransformScale(transform, -1, 1);
            }
            break;
        }
        default: {
            CGFloat translateW = - (width - contextW) / 2;
            CGFloat translateH = - (height - contextH) / 2;
            transform = CGAffineTransformTranslate(transform, translateW, translateH);
            if (ori == UIImageOrientationUpMirrored) {
                transform = CGAffineTransformTranslate(transform, contextW, 0);
                transform = CGAffineTransformScale(transform, -1, 1);
            }
            break;
        }
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
