//
//  SYRecordConfig.h
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/8.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SYRecordConfig : NSObject

@property (nonatomic, assign) NSUInteger bitrate;
@property (nonatomic, assign) NSUInteger gop;
@property (nonatomic, assign) CGSize size;
@property (nonatomic, assign) NSUInteger frameRate;

@end

NS_ASSUME_NONNULL_END
