//
//  MARecordViewController.m
//  MacTest
//
//  Created by 马英伦 on 2020/12/6.
//  Copyright © 2020 马英伦. All rights reserved.
//

#import "MARecordViewController.h"
#import <AVKit/AVKit.h>

//#import "avcodec.h"
//#import "opt.h"
//#import "imgutils.h"
#import <libavcodec/avcodec.h>
#import <libavutil/opt.h>
#import <libavutil/imgutils.h>

@interface MARecordViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVFrame *_frame;
    AVCodecContext *_codecContext;
    FILE *_file;
}

@property (strong,nonatomic) AVCaptureSession *captureSession;//负责输入和输出设置之间的数据传递
@property (strong,nonatomic) AVCaptureDeviceInput *captureDeviceInput;//负责从AVCaptureDevice获得输入数据
@property (strong,nonatomic) AVCaptureVideoDataOutput *captureMovieFileOutput;//视频输出流
@property (strong,nonatomic) AVCaptureVideoPreviewLayer *captureVideoPreviewLayer;//相机拍摄预览图层

@end

@implementation MARecordViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.wantsLayer = YES;
    
    NSString *targetDic = [NSTemporaryDirectory() stringByAppendingPathComponent:@"Test"];
    NSFileManager *fileManager = NSFileManager.defaultManager;
    if (![fileManager fileExistsAtPath:targetDic]) {
        [fileManager createDirectoryAtPath:targetDic withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *targetPath = [targetDic stringByAppendingPathComponent:@"RecordH264.h264"];
    
    [self setupCodec:targetPath];
    
    
    [self setupCapture];
}

- (BOOL)setupCodec:(NSString *)fileName
{
    const AVCodec *codec;
    AVCodecContext *c= NULL;
    int ret;
//    int i, ret, x, y, got_output;
    FILE *f;
//    AVFrame *frame;
//    AVPacket pkt;
    
    codec = avcodec_find_encoder_by_name(@"libx264".UTF8String);
    if (!codec) {
        NSLog(@"Codec not found\n");
        return NO;
    }
    
    c = avcodec_alloc_context3(codec);
    if (!c) {
        NSLog(@"Could not allocate video codec context\n");
        return NO;
    }
    
/* put sample parameters */
    c->bit_rate = 400000;
    /* resolution must be a multiple of two */
    c->width = 1280;
    c->height = 720;
    /* frames per second */
    c->time_base = (AVRational){1, 25};
    c->framerate = (AVRational){25, 1};

    /* emit one intra frame every ten frames
     * check frame pict_type before passing frame
     * to encoder, if frame->pict_type is AV_PICTURE_TYPE_I
     * then gop_size is ignored and the output of encoder
     * will always be I frame irrespective to gop_size
     */
    c->gop_size = 10;
    c->max_b_frames = 1;
    c->pix_fmt = AV_PIX_FMT_NV12;
    
    if (codec->id == AV_CODEC_ID_H264)
        av_opt_set(c->priv_data, "preset", "slow", 0);
    
    if (avcodec_open2(c, codec, NULL) < 0) {
        NSLog(@"Could not open codec");
        return NO;
    }
    
    _codecContext = c;
    
    f = fopen(fileName.UTF8String, "wb");
    if (!f) {
        NSLog(@"Could not open: %@", fileName);
        return NO;
    }
    
    _file = f;
    
    _frame = av_frame_alloc();
    if (!_frame) {
        NSLog(@"Could not allocate video frame");
        return NO;
    }
    
    _frame->format = c->pix_fmt;
    _frame->width  = c->width;
    _frame->height = c->height;
    
    ret = av_frame_get_buffer(_frame, 0);
    if (ret < 0) {
        NSLog(@"Could not allocate the video frame data");
        return NO;
    }
    
    return YES;
}

- (void)viewDidAppear
{
    [super viewDidAppear];
    [self startCapture];
}

- (void)viewDidDisappear
{
    [super viewDidDisappear];
    [self stopCapture];
}

- (void)startCapture {
    [self.captureSession startRunning];
}

- (void)stopCapture {
    [self.captureSession stopRunning];
}

- (void)setupCapture {
    //初始化会话
    _captureSession=[[AVCaptureSession alloc]init];
    if ([_captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {//设置分辨率
        _captureSession.sessionPreset=AVCaptureSessionPreset1280x720;
    }
      
    //获得输入设备
    
    AVCaptureDevice *captureDevice=[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo][1];
    if (!captureDevice) {
        NSLog(@"取得后置摄像头时出现问题.");
        return;
    }
    //添加一个音频输入设备
//    NSArray *list = [AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio];
    AVCaptureDevice *audioCaptureDevice=[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio][1];
      
      
    NSError *error=nil;
    //根据输入设备初始化设备输入对象，用于获得输入数据
    _captureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    
    dispatch_queue_t videoQueue = dispatch_queue_create("myEncoderQueue_video", DISPATCH_QUEUE_CONCURRENT);
//    dispatch_queue_t audioQueue = dispatch_queue_create("myEncoderQueue_audio", DISPATCH_QUEUE_CONCURRENT);
      
    //初始化设备输出对象，用于获得输出数据
    _captureMovieFileOutput=[[AVCaptureVideoDataOutput alloc]init];
    NSDictionary *settings = [[NSDictionary alloc] initWithObjectsAndKeys:
                              [NSNumber numberWithUnsignedInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange],
                              kCVPixelBufferPixelFormatTypeKey,
                              nil];
    _captureMovieFileOutput.videoSettings = settings;
    
    
    [_captureMovieFileOutput setSampleBufferDelegate:self queue:videoQueue];
      
    //将设备输入添加到会话中
    if ([_captureSession canAddInput:_captureDeviceInput]) {
        [_captureSession addInput:_captureDeviceInput];
        [_captureSession addInput:audioCaptureDeviceInput];
//        AVCaptureConnection *captureConnection=[_captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
    }
      
    //将设备输出添加到会话中
    if ([_captureSession canAddOutput:_captureMovieFileOutput]) {
        [_captureSession addOutput:_captureMovieFileOutput];
    }
  
      
    //创建视频预览层，用于实时展示摄像头状态
    _captureVideoPreviewLayer=[[AVCaptureVideoPreviewLayer alloc]initWithSession:self.captureSession];
      
    CALayer *layer=self.view.layer;
    layer.masksToBounds=YES;
      
    _captureVideoPreviewLayer.frame=layer.bounds;
    _captureVideoPreviewLayer.videoGravity=AVLayerVideoGravityResizeAspectFill;//填充模式
    //将视频预览层添加到界面中
    [layer addSublayer:_captureVideoPreviewLayer];
      
}
    
#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    
    // 这里的sampleBuffer就是采集到的数据了，但它是Video还是Audio的数据，得根据connection来判断
    if (captureOutput == self.captureMovieFileOutput) {
        
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        
        size_t height = CVPixelBufferGetHeight(pixelBuffer);
        size_t width = CVPixelBufferGetWidth(pixelBuffer);
        
        uint8_t *data = NULL;

        unsigned int pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer);
        switch (pixelFormat) {
            case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            {
                
                int ret = av_frame_make_writable(_frame);
                if (ret == 0)
                {
                    size_t count = CVPixelBufferGetPlaneCount(pixelBuffer);
                    NSLog(@"mayinglun log:%zu", count);
                    
                    unsigned long y_size = width * height;
                    unsigned long uv_size = y_size / 2;
                    uint8_t *y_frame = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
                    memcpy(_frame->data[0], y_frame, y_size);
                    uint8_t *uv_frame = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
                    memcpy(_frame->data[1], uv_frame, uv_size);
                    _frame->pts = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer));
                    
                    AVPacket pkt;
                    av_init_packet(&pkt);
                    pkt.data = NULL;    // packet data will be allocated by the encoder
                    pkt.size = 0;

                    fflush(stdout);
                    
                    int got_output;
                    
                    /* encode the image */
                    ret = avcodec_encode_video2(_codecContext, &pkt, _frame, &got_output);
                    if (ret == 0) {
//                        fprintf(stderr, "Error encoding frame\n");
                        if (got_output) {
                            fwrite(pkt.data, 1, pkt.size, _file);
                            av_packet_unref(&pkt);
                            NSLog(@"mayinglun log got_output:%d", got_output);
                        }
                    }

                   
                }
                
//                unsigned long y_size = width * height;
//                unsigned long uv_size = y_size / 2;
//                data = (uint8_t *)malloc(y_size + uv_size);
//                uint8_t *y_frame = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
//                memcpy(data, y_frame, y_size);
//                uint8_t *uv_frame = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
//                memcpy(data + y_size, uv_frame, uv_size);
//                NDI_video_frame.FourCC = NDIlib_FourCC_video_type_NV12;
//                NDI_video_frame.p_data = (uint8_t*)data;
                
//                AVPacket pkt;
//                av_init_packet(&pkt);
//                pkt.data = NULL;    // packet data will be allocated by the encoder
//                pkt.size = 0;
//
//                fflush(stdout);
//
//                int ret = 0;
//                /* make sure the frame data is writable */
//                ret = av_frame_make_writable(_frame);
//                if (ret == 0) {
//
//                    size_t n = CVPixelBufferGetPlaneCount(pixelBuffer);
//
//                    NSLog(@"mayinglun log:%d", n);
//                }
                    
                
            }
                break;
            case kCVPixelFormatType_32BGRA:
            {
                uint16_t pitch = CVPixelBufferGetBytesPerRow(pixelBuffer);
                GLubyte *rawImageBytes = (GLubyte*)CVPixelBufferGetBaseAddress(pixelBuffer);
                
//                NDI_video_frame.FourCC = NDIlib_FourCC_video_type_BGRA;
//                NDI_video_frame.p_data = rawImageBytes;

//                unsigned *data1 = (unsigned *)malloc(width * height * 4);
//                memcpy(data1, rawImageBytes, width * height * 4);
//                memset(data1, width, 100 * 100 * 4);
                
            }
                break;
            default:
                CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
                return;
                break;
        }

//        CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);

        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    }
    
}

@end
