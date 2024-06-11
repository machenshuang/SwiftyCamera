//
//  SYRecorder.h
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/2.
//

#import <Foundation/Foundation.h>
#import "SYRecordConfig.h"
#import <CoreMedia/CoreMedia.h>

NS_ASSUME_NONNULL_BEGIN

@interface SYRecorder : NSObject

- (instancetype)initWithConfig:(SYRecordConfig *)config;
- (void)startRecord;
- (void)stopRecord;
- (void)pauseRecord;
- (void)resumeRecord;
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

NS_ASSUME_NONNULL_END
