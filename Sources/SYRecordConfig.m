//
//  SYRecorderConfig.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/8.
//

#import "SYRecordConfig.h"

@implementation SYRecordConfig

- (instancetype)initWithSize:(CGSize)size
{
    self = [self initWithSize:size withBitrate:3000 withGop:30 withFrameRate:30];
    return self;
}
- (instancetype)initWithSize:(CGSize)size withBitrate:(NSUInteger)bitrate withGop:(NSUInteger)gop withFrameRate:(NSUInteger)frameRate
{
    self = [super init];
    if (self) {
        _bitrate = bitrate;
        _gop = gop;
        _size = size;
        _frameRate = frameRate;
    }
    return self;
}

@end
