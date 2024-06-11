//
//  SYRecorderConfig.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/8.
//

#import "SYRecordConfig.h"

@implementation SYRecordConfig

- (instancetype)init
{
    self = [super init];
    if (self) {
        _bitrate = 3000;
        _gop = 30;
        _size = CGSizeMake(1080, 1920);
        _frameRate = 30;
    }
    return self;
}

@end
