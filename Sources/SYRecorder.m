//
//  SYRecorder.m
//  SwiftyCamera
//
//  Created by 马陈爽 on 2024/6/2.
//

#import "SYRecorder.h"
#import <AVFoundation/AVFoundation.h>

@interface SYRecorder ()
{
    AVAssetWriter *_writer;
    AVAssetWriterInput *_videoWriterInput;
    AVAssetWriterInput *_audioWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *_adaptor;
    dispatch_queue_t _recordQueue;
    bool _resetTime;
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
        strongSelf->_resetTime = YES;
        [strongSelf->_writer startWriting];
    });
}

- (void)stopRecordWithCompletion:(void (^)(NSURL * _Nullable, BOOL))completion
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_recordQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->_canWriting = NO;
        strongSelf->_resetTime = YES;
        [strongSelf->_writer finishWritingWithCompletionHandler:^{
            if (strongSelf->_writer.status == AVAssetWriterStatusCompleted) {
                completion(strongSelf->_writer.outputURL, YES);
            } else {
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
    });
}

- (void)resumeRecord
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_recordQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->_canWriting = YES;
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
        
        [strongSelf addWriterInput];
        [strongSelf addAudioWriterInput];
        [strongSelf configureAdaptor];
    });
    
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    __weak typeof(self)weakSelf = self;
    dispatch_async(_recordQueue, ^{
        __strong typeof(weakSelf)strongSelf = weakSelf;
        
        if (!strongSelf->_canWriting) {
            return;
        }
        
        if (strongSelf->_writer.status != AVAssetWriterStatusWriting) {
            return;
        }
        
        CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
        if (formatDescription == NULL) {
            return;
        }
        
        CMMediaType mediaType = CMFormatDescriptionGetMediaType(formatDescription);
        
        CMTime timesampe = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        
        if (strongSelf->_resetTime) {
            [strongSelf->_writer startSessionAtSourceTime:timesampe];
            strongSelf->_resetTime = NO;
        }
        
        switch (mediaType) {
            case kCMMediaType_Video: {
                [strongSelf processVideoSample:sampleBuffer withPresentationTime:timesampe];
                break;
            }
            case kCMMediaType_Audio: {
                [strongSelf processAudioSample:sampleBuffer];
                break;
            }
            default: {
                break;
            }
               
        }
    });
}

- (void)processVideoSample:(CMSampleBufferRef)sampleBuffer withPresentationTime:(CMTime)presentationTime
{
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    [self->_adaptor appendPixelBuffer:pixelBuffer withPresentationTime:presentationTime];
}

- (void)processAudioSample:(CMSampleBufferRef)sampleBuffer
{
    [self->_audioWriterInput appendSampleBuffer:sampleBuffer];
}

- (void)addWriterInput
{
    if (!_videoWriterInput) {
        _videoWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:[self fetchVideoSetting]];
        _videoWriterInput.expectsMediaDataInRealTime = YES;
    }
    
    if ([_writer canAddInput:_videoWriterInput]) {
        [_writer addInput:_videoWriterInput];
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
    NSError *error;
    NSURL *documentURL = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:&error];
    NSString *filename = [NSString stringWithFormat:@"%d", (int)(CFAbsoluteTimeGetCurrent() * 1000)];
    return [documentURL URLByAppendingPathComponent:filename];
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
