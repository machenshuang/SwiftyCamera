//
//  UIImage+SYImage.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/24.
//

#import "UIImage+SYImage.h"

@implementation UIImage (SYImage)

- (UIImage *)fixImageWithOrientation:(UIImageOrientation)ori withCropRect:(CGRect)rect
{
    CGImageRef cgImage = self.CGImage;
    int width = (int)CGImageGetWidth(cgImage);
    int height = (int)CGImageGetHeight(cgImage);
    
    int contextW = width;
    int contextH = height;
    CGAffineTransform transform = CGAffineTransformIdentity;
    
    switch (ori) {
        case UIImageOrientationDown:
        case UIImageOrientationDownMirrored: {
            transform = CGAffineTransformTranslate(transform, contextW / 2.0, contextH / 2.0);
            transform = CGAffineTransformRotate(transform, M_PI);
            break;
        }
        case UIImageOrientationLeft:
        case  UIImageOrientationLeftMirrored: {
            contextW = height;
            contextH = width;
            transform = CGAffineTransformTranslate(transform, contextW / 2.0, contextH / 2.0);
            transform = CGAffineTransformRotate(transform, M_PI_2);
            break;
        }
        case UIImageOrientationRight:
        case UIImageOrientationRightMirrored: {
            contextW = height;
            contextH = width;
            transform = CGAffineTransformTranslate(transform, contextW / 2.0, contextH / 2.0);
            transform = CGAffineTransformRotate(transform, -M_PI_2);
            break;
        }
        default: {
            break;
        }
    }
    
    transform = CGAffineTransformTranslate(transform, -contextW / 2.0, 0);
    
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

@end
