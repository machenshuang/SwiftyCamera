//
//  SYRecorder.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/2.
//

#import "SYRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import "SYLog.h"

static NSString * TAG = @"SYRecorder";

@interface SYRecorder ()
{
    AVAssetWriter *_writer;
    AVAssetWriterInput *_videoWriterInput;
    AVAssetWriterInput *_audioWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *_adaptor;
    dispatch_queue_t _recordQueue;
    SYRecordConfig *_config;
    bool _canWriting;
}

@end

@implementation SYRecorder

- (instancetype)initWithConfig:(SYRecordConfig *)config
{
    self = [super init];
    if (self) {
        _recordQueue = dispatch_queue_create("com.machenshuang.camera.SYRecorder", DISPATCH_QUEUE_SERIAL);
        _config = config;
        [self configure];
    }
    return self;
}

- (void)startRecord
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_recordQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->_canWriting = YES;
        SYLog(TAG, "startRecord canWriting = %d", strongSelf->_canWriting);
    });
}

- (void)stopRecordWithCompletion:(void (^)(NSURL * _Nullable, BOOL))completion
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_recordQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->_canWriting = NO;
        SYLog(TAG, "stopRecordWithCompletion canWriting = %d", strongSelf->_canWriting);
        [strongSelf->_writer finishWritingWithCompletionHandler:^{
            if (strongSelf->_writer.status == AVAssetWriterStatusCompleted) {
                completion(strongSelf->_writer.outputURL, YES);
            } else {
                SYLog(TAG, "stopRecordWithCompletion failure, status = %ld", (long)strongSelf->_writer.status);
                completion(nil, NO);
            }
        }];
    });
}

- (void)pauseRecord 
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_recordQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->_canWriting = NO;
        SYLog(TAG, "startRecord canWriting = %d", strongSelf->_canWriting);
    });
}

- (void)resumeRecord
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_recordQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->_canWriting = YES;
        SYLog(TAG, "startRecord canWriting = %d", strongSelf->_canWriting);
    });
}

- (void)configure
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_recordQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        if (!strongSelf->_writer) {
            AVMediaType mediaType = AVFileTypeMPEG4;
            NSError *error;
            
            strongSelf->_writer = [[AVAssetWriter alloc] initWithURL:[strongSelf getURL] fileType:mediaType error:&error];
            // 适合网络播放
            strongSelf->_writer.shouldOptimizeForNetworkUse = YES;
        }
        
        [strongSelf addVideoWriterInput];
        [strongSelf addAudioWriterInput];
        [strongSelf configureAdaptor];
        SYLog(TAG, "configure");
    });
    
}

- (void)appendVideo:(CMSampleBufferRef)sampleBuffer
{
    CFRetain(sampleBuffer);
    __weak typeof(self)weakSelf = self;
    dispatch_async(_recordQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (!strongSelf->_canWriting) {
            CFRelease(sampleBuffer);
            return;
        }
        CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        if (strongSelf->_writer.status == AVAssetWriterStatusUnknown) {
            [strongSelf->_writer startWriting];
            [strongSelf->_writer startSessionAtSourceTime:timestamp];
            CFRelease(sampleBuffer);
            SYLog(TAG, "appendVideo writer status is AVAssetWriterStatusUnknown");
            return;
        }
        
        if (strongSelf->_writer.status != AVAssetWriterStatusWriting) {
            CFRelease(sampleBuffer);
            SYLog(TAG, "appendVideo writer status is %ld, error = %@", (long)strongSelf->_writer.status, strongSelf->_writer.error.description);
            return;
        }
        
        if (!strongSelf->_videoWriterInput.isReadyForMoreMediaData) {
            CFRelease(sampleBuffer);
            SYLog(TAG, "appendVideo writer status is not readyForMoreMediaData");
            return;
        }
        
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        [self->_adaptor appendPixelBuffer:pixelBuffer withPresentationTime:timestamp];
        CFRelease(sampleBuffer);
    });
}

- (void)appendAudio:(CMSampleBufferRef)sampleBuffer
{
    CFRetain(sampleBuffer);
    __weak typeof(self)weakSelf = self;
    dispatch_async(_recordQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        if (!strongSelf->_canWriting) {
            CFRelease(sampleBuffer);
            return;
        }
        
        if (strongSelf->_writer.status != AVAssetWriterStatusWriting) {
            CFRelease(sampleBuffer);
            SYLog(TAG, "appendAudio writer status is %ld", (long)strongSelf->_writer.status);
            return;
        }
        
        if (!strongSelf->_audioWriterInput.isReadyForMoreMediaData) {
            CFRelease(sampleBuffer);
            SYLog(TAG, "appendAudio writer status is not readyForMoreMediaData");
            return;
        }
        
        [strongSelf->_audioWriterInput appendSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    });
}

- (void)addVideoWriterInput
{
    if (!_videoWriterInput) {
        _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:[self fetchVideoSetting]];
        _videoWriterInput.expectsMediaDataInRealTime = YES;
    }
    
    if ([_writer canAddInput:_videoWriterInput]) {
        [_writer addInput:_videoWriterInput];
    } else {
        SYLog(TAG, "addVideoWriterInput addInput failure");
    }
}

- (void)addAudioWriterInput
{
    if (!_audioWriterInput) {
        _audioWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:[self fetchAudioSetting]];
        _audioWriterInput.expectsMediaDataInRealTime = YES;
    }
    
    if ([_writer canAddInput:_audioWriterInput]) {
        [_writer addInput:_audioWriterInput];
    } else {
        SYLog(TAG, "addAudioWriterInput addInput failure");
    }
}

- (void)configureAdaptor
{
    if (!_adaptor) {
        NSDictionary *sourcePixelBufferAttributes = @{
            (id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA),
            (id)kCVPixelBufferWidthKey: @(_config.size.width),
            (id)kCVPixelBufferHeightKey: @(_config.size.height),
        };
        _adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoWriterInput sourcePixelBufferAttributes:sourcePixelBufferAttributes];
    }
}

- (NSURL *)getURL
{
    NSString *filename = [NSString stringWithFormat:@"%ld", (long)(CFAbsoluteTimeGetCurrent() * 1000)];
    NSString *path = [[NSTemporaryDirectory() stringByAppendingPathComponent:filename] stringByAppendingPathExtension:@"MP4"];
    NSURL *documentURL = [[NSURL alloc] initFileURLWithPath:path];
    SYLog(TAG, "getURL url = %@", documentURL.path);
    return documentURL;
}

- (NSDictionary<NSString *, id> *)fetchVideoSetting
{
    NSMutableDictionary *compressDict = [NSMutableDictionary dictionaryWithDictionary: @{
        AVVideoAverageBitRateKey: @(_config.bitrate*1024),
        AVVideoMaxKeyFrameIntervalKey: @(_config.gop),
        AVVideoExpectedSourceFrameRateKey: @30,
        AVVideoAllowFrameReorderingKey: @(NO),
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
    }];
    
    return @{
        AVVideoCodecKey: AVVideoCodecTypeH264,
        AVVideoCompressionPropertiesKey: compressDict,
        AVVideoWidthKey: @(_config.size.width),
        AVVideoHeightKey: @(_config.size.height),
    };
    
}

- (NSDictionary<NSString *, id> *)fetchAudioSetting
{
    AudioChannelLayout acl;
    bzero(&acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    NSUInteger sampleRate = [AVAudioSession sharedInstance].sampleRate;
    if (sampleRate < 44100) {
        sampleRate = 44100;
    } else if (sampleRate > 48000) {
        sampleRate = 48000;
    }
    return @{
        AVFormatIDKey: @(kAudioFormatMPEG4AAC),
        AVNumberOfChannelsKey: @(1),
        AVSampleRateKey: @(sampleRate),
        AVChannelLayoutKey: [NSData dataWithBytes:&acl length:sizeof(acl)],
        AVEncoderBitRateKey: @(64000),
    };
}



@end
