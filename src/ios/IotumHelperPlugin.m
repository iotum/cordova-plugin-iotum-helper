#import "IotumHelperPlugin.h"
#import <objc/runtime.h>
#import <AVKit/AVKit.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <WebKit/WebKit.h>

// ---------------------------------------------------------------------------
// Private interface – PiP properties kept out of the public header
// ---------------------------------------------------------------------------
@interface IotumHelperPlugin () <AVPictureInPictureControllerDelegate>

@property (nonatomic, strong) AVPictureInPictureController              *pipController;
@property (nonatomic, strong) AVPictureInPictureVideoCallViewController *pipContentViewController API_AVAILABLE(ios(15.0));
@property (nonatomic, strong) AVSampleBufferDisplayLayer                *pipDisplayLayer;
@property (nonatomic, copy)   NSString                                  *pipCallbackId;

@end

@implementation IotumHelperPlugin

#pragma mark Initialize

NSString* WKClassString;
static IMP WKOriginalImp;

- (void)pluginInitialize
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];

    [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

    // Prevent WKWebView from adding the adjustedContentInset
    // (https://github.com/WebKit/WebKit/blob/main/Source/WebKit/UIProcess/API/ios/WKWebViewIOS.mm)
    [nc removeObserver:self.webView name:UIKeyboardWillHideNotification object:nil];
    [nc removeObserver:self.webView name:UIKeyboardWillShowNotification object:nil];
    [nc removeObserver:self.webView name:UIKeyboardWillChangeFrameNotification object:nil];
    // [nc removeObserver:self.webView name:UIKeyboardDidChangeFrameNotification object:nil];

    WKClassString = [@[@"WK", @"Content", @"View"] componentsJoinedByString:@""];
}

- (void)setAppBackgroundColor:(CDVInvokedUrlCommand *)command
{
    NSString* color = [[NSString stringWithFormat:@"%@", [command.arguments objectAtIndex:0]] lowercaseString];

    if ([color hasPrefix:@"#"]) {
        // Set main view color (the parent of webView)
        self.webView.superview.backgroundColor = [self colorFromHexString:color];
    }
}

- (void)hideKeyboardAccessoryBar:(CDVInvokedUrlCommand *)command
{
    BOOL hide = [[command.arguments objectAtIndex:0] boolValue];

    Method WKMethod = class_getInstanceMethod(NSClassFromString(WKClassString), @selector(inputAccessoryView));

    if (hide) {
        WKOriginalImp = method_getImplementation(WKMethod);

        IMP newImp = imp_implementationWithBlock(^(id _s) {
            return nil;
        });

        method_setImplementation(WKMethod, newImp);
    } else {
        method_setImplementation(WKMethod, WKOriginalImp);
    }
}

// Supports a four-byte hex value (ARGB)
// Note: this is different from the CSS color (RGBA)
- (UIColor *)colorFromHexString:(NSString*)hexString {
    // Validate format
    NSError* error = NULL;
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern:@"^(#[0-9A-F]{3}|(0x|#)([0-9A-F]{2})?[0-9A-F]{6})$" options:NSRegularExpressionCaseInsensitive error:&error];
    NSUInteger countMatches = [regex numberOfMatchesInString:hexString options:0 range:NSMakeRange(0, [hexString length])];

    if (!countMatches) {
        return nil;
    }

    // #FAB to #FFAABB
    if ([hexString hasPrefix:@"#"] && [hexString length] == 4) {
        NSString* r = [hexString substringWithRange:NSMakeRange(1, 1)];
        NSString* g = [hexString substringWithRange:NSMakeRange(2, 1)];
        NSString* b = [hexString substringWithRange:NSMakeRange(3, 1)];
        hexString = [NSString stringWithFormat:@"#%@%@%@%@%@%@", r, r, g, g, b, b];
    }

    // #RRGGBB to 0xRRGGBB
    hexString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@"0x"];

    // 0xRRGGBB to 0xAARRGGBB
    if ([hexString hasPrefix:@"0x"] && [hexString length] == 8) {
        hexString = [@"0xFF" stringByAppendingString:[hexString substringFromIndex:2]];
    }

    // 0xAARRGGBB to int
    unsigned colorValue = 0;
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    if (![scanner scanHexInt:&colorValue]) {
        return nil;
    }

    // int to UIColor
    return [UIColor colorWithRed:((float)((colorValue & 0x00FF0000) >> 16)) / 255.0
                           green:((float)((colorValue & 0x0000FF00) >>  8)) / 255.0
                            blue:((float)((colorValue & 0x000000FF) >>  0)) / 255.0
                           alpha:((float)((colorValue & 0xFF000000) >> 24)) / 255.0];
}

- (void)keyboardDidShow: (NSNotification *) notif {
    NSLog(@"Keyboard: did show");

    int height = [self _getKeyboardHeight:notif];
    [self _updateFrame:height];
    NSString *js = [NSString stringWithFormat:@"cordova.plugins.iotumHelper.Keyboard.fireOnShow(%d);", height];
    [self.commandDelegate evalJs:js];
}

- (void)keyboardDidHide: (NSNotification *) notif {
    NSLog(@"Keyboard: did hide");

    [self.commandDelegate evalJs:@"cordova.plugins.iotumHelper.Keyboard.fireOnHide();"];
    [self _updateFrame:0];
}

- (void)keyboardWillShow: (NSNotification *) notif {
    NSLog(@"Keyboard: will show");
    [self _updateFrame:[self _getKeyboardHeight:notif]];
}

- (void)keyboardWillHide: (NSNotification *) notif {
    NSLog(@"Keyboard: will hide");
    [self _updateFrame:0];
}

- (int)_getKeyboardHeight: (NSNotification *) notif {
    NSValue *endFrameValue = [notif.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
    if (!endFrameValue)
        return 0;

    CGSize rect = [endFrameValue CGRectValue].size;
    return rect.height;
}

- (void)_updateFrame: (int) height {
    NSLog(@"Keyboard: updating frame %d", height);

    // NOTE: to handle split screen correctly, the application's window bounds must be used as opposed to the screen's bounds.
    CGSize size = [[[[UIApplication sharedApplication] delegate] window] bounds].size;
    CGPoint origin = self.webView.frame.origin;

    // Change the frame size to prevent the ScrollView from pushing the WebView up.
    [self.webView setFrame:CGRectMake(origin.x, origin.y, size.width - origin.x, size.height - origin.y - height)];
    [self.webView.scrollView setContentInset:UIEdgeInsetsZero];
}

- (void) log:(CDVInvokedUrlCommand*)command
{
    NSString* message = [command.arguments objectAtIndex:0];
    if (message != nil && [message length] > 0) {
        [self logMessage:message];
    }
}

- (void)logMessage:(NSString *)message
{
    NSLog(@"[IotumHelper]: %@", message);
}

#pragma mark - Picture in Picture

/**
 * Returns whether AVPictureInPictureController is supported on this device.
 * Calls back with a boolean result.
 */
- (void)isPictureInPictureSupported:(CDVInvokedUrlCommand *)command
{
    BOOL supported = [AVPictureInPictureController isPictureInPictureSupported];
    CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:supported];
    [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
}

/**
 * Enter Picture in Picture mode.
 *
 * Accepted options (NSDictionary from JS):
 *   mode             – @"webrtc" (default) | @"webview"
 *   url              – URL string to load inside the PiP webview (webview mode only)
 *   aspectRatioWidth – integer, default 16
 *   aspectRatioHeight– integer, default 9
 *
 * Requires iOS 15.0+.
 * The success callback fires when PiP actually starts (willStart delegate).
 * The error callback fires if PiP is unsupported or fails to start.
 */
- (void)enterPictureInPicture:(CDVInvokedUrlCommand *)command
{
    if (![AVPictureInPictureController isPictureInPictureSupported]) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                    messageAsString:@"Picture in Picture is not supported on this device"];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
        return;
    }

    NSDictionary *options = [command.arguments objectAtIndex:0];
    NSString *mode = options[@"mode"] ?: @"webrtc";
    NSInteger ratioWidth = options[@"aspectRatioWidth"] ? [options[@"aspectRatioWidth"] integerValue] : 16;
    NSInteger ratioHeight = options[@"aspectRatioHeight"] ? [options[@"aspectRatioHeight"] integerValue] : 9;
    NSString *url = options[@"url"];

    self.pipCallbackId = command.callbackId;

    dispatch_async(dispatch_get_main_queue(), ^{
        if (@available(iOS 15.0, *)) {
            if ([mode isEqualToString:@"webview"]) {
                [self _enterWebViewPiP:url ratioWidth:ratioWidth ratioHeight:ratioHeight];
            } else {
                [self _enterWebRTCPiP:ratioWidth ratioHeight:ratioHeight];
            }
        } else {
            CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                        messageAsString:@"Picture in Picture requires iOS 15.0 or later"];
            [self.commandDelegate sendPluginResult:result callbackId:self.pipCallbackId];
            self.pipCallbackId = nil;
        }
    });
}

/**
 * webview mode: renders a WKWebView loading the given URL inside the PiP window.
 */
- (void)_enterWebViewPiP:(NSString *)url ratioWidth:(NSInteger)ratioWidth ratioHeight:(NSInteger)ratioHeight API_AVAILABLE(ios(15.0))
{
    // Content view controller that will be shown inside the PiP window
    self.pipContentViewController = [[AVPictureInPictureVideoCallViewController alloc] init];
    self.pipContentViewController.preferredContentSize = CGSizeMake(ratioWidth * 100, ratioHeight * 100);

    // Embed a WKWebView as the PiP content
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.allowsInlineMediaPlayback = YES;
    config.allowsPictureInPictureMediaPlayback = YES;

    WKWebView *pipWebView = [[WKWebView alloc] initWithFrame:self.pipContentViewController.view.bounds
                                               configuration:config];
    pipWebView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

    if (url.length > 0) {
        NSURL *nsURL = [NSURL URLWithString:url];
        if (nsURL) {
            [pipWebView loadRequest:[NSURLRequest requestWithURL:nsURL]];
        }
    }

    [self.pipContentViewController.view addSubview:pipWebView];

    [self _startPiPWithContentViewController:self.pipContentViewController];
}

/**
 * webrtc mode: renders an AVSampleBufferDisplayLayer inside the PiP window.
 * Video frames are pushed frame-by-frame via -setPictureInPictureFrame:.
 */
- (void)_enterWebRTCPiP:(NSInteger)ratioWidth ratioHeight:(NSInteger)ratioHeight API_AVAILABLE(ios(15.0))
{
    // Content view controller that will be shown inside the PiP window
    self.pipContentViewController = [[AVPictureInPictureVideoCallViewController alloc] init];
    self.pipContentViewController.preferredContentSize = CGSizeMake(ratioWidth * 100, ratioHeight * 100);

    // AVSampleBufferDisplayLayer receives frames pushed by -setPictureInPictureFrame:
    self.pipDisplayLayer = [[AVSampleBufferDisplayLayer alloc] init];
    self.pipDisplayLayer.frame = self.pipContentViewController.view.bounds;
    self.pipDisplayLayer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;
    self.pipDisplayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.pipDisplayLayer.backgroundColor = [UIColor blackColor].CGColor;
    [self.pipContentViewController.view.layer addSublayer:self.pipDisplayLayer];

    [self _startPiPWithContentViewController:self.pipContentViewController];
}

/** Common setup: create the AVPictureInPictureController and start PiP. */
- (void)_startPiPWithContentViewController:(AVPictureInPictureVideoCallViewController *)contentVC API_AVAILABLE(ios(15.0))
{
    // sourceView is the view in the main app that visually "owns" the PiP content.
    // Using self.webView keeps the zoom-in/out animation anchored to the web view.
    AVPictureInPictureControllerContentSource *contentSource =
        [[AVPictureInPictureControllerContentSource alloc]
            initWithActiveVideoCallSourceView:self.webView
                        contentViewController:contentVC];

    self.pipController = [[AVPictureInPictureController alloc] initWithContentSource:contentSource];
    self.pipController.delegate = self;

    [self.pipController startPictureInPicture];
}

/**
 * Stop the active PiP session.
 */
- (void)exitPictureInPicture:(CDVInvokedUrlCommand *)command
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.pipController && self.pipController.isPictureInPictureActive) {
            [self.pipController stopPictureInPicture];
        }
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:command.callbackId];
    });
}

/**
 * Push a video frame into the active WebRTC PiP display layer.
 *
 * @param command.arguments[0] – base64-encoded JPEG/PNG image data (no data-URI prefix)
 *
 * This is designed to be called from JavaScript on every animation frame, e.g.:
 *
 *   function captureAndSend(videoEl) {
 *     const canvas = document.createElement('canvas');
 *     canvas.width = videoEl.videoWidth;
 *     canvas.height = videoEl.videoHeight;
 *     canvas.getContext('2d').drawImage(videoEl, 0, 0);
 *     const base64 = canvas.toDataURL('image/jpeg', 0.7).split(',')[1];
 *     cordova.plugins.iotumHelper.setPictureInPictureFrame(base64);
 *     requestAnimationFrame(() => captureAndSend(videoEl));
 *   }
 */
- (void)setPictureInPictureFrame:(CDVInvokedUrlCommand *)command
{
    NSString *base64 = [command.arguments objectAtIndex:0];

    if (!base64 || base64.length == 0 || !self.pipDisplayLayer) {
        return;
    }

    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64
                                                            options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!imageData) return;

    UIImage *image = [UIImage imageWithData:imageData];
    if (!image) return;

    // Do the heavy pixel-buffer work off the main thread
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        CVPixelBufferRef pixelBuffer = [self _pixelBufferFromImage:image];
        if (!pixelBuffer) return;

        CMSampleBufferRef sampleBuffer = [self _sampleBufferFromPixelBuffer:pixelBuffer];
        CVPixelBufferRelease(pixelBuffer);

        if (!sampleBuffer) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            if (self.pipDisplayLayer.status == AVQueuedSampleBufferRenderingStatusFailed) {
                [self.pipDisplayLayer flush];
            }
            [self.pipDisplayLayer enqueueSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer);
        });
    });
}

#pragma mark - PiP helpers

/** Convert a UIImage to a CVPixelBuffer (kCVPixelFormatType_32BGRA). */
- (CVPixelBufferRef)_pixelBufferFromImage:(UIImage *)image
{
    CGImageRef cgImage = image.CGImage;
    size_t width  = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);

    NSDictionary *options = @{
        (NSString *)kCVPixelBufferCGImageCompatibilityKey:       @YES,
        (NSString *)kCVPixelBufferCGBitmapContextCompatibilityKey: @YES,
    };

    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, width, height,
                                         kCVPixelFormatType_32BGRA,
                                         (__bridge CFDictionaryRef)options,
                                         &pixelBuffer);
    if (status != kCVReturnSuccess) return NULL;

    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void   *pixelData   = CVPixelBufferGetBaseAddress(pixelBuffer);
    size_t  bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pixelData,
                                                 width, height,
                                                 8, bytesPerRow,
                                                 colorSpace,
                                                 kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGColorSpaceRelease(colorSpace);

    if (!context) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        CVPixelBufferRelease(pixelBuffer);
        return NULL;
    }

    CGContextDrawImage(context, CGRectMake(0, 0, width, height), cgImage);
    CGContextRelease(context);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    return pixelBuffer;
}

/** Wrap a CVPixelBuffer in a CMSampleBuffer stamped with the current clock time. */
- (CMSampleBufferRef)_sampleBufferFromPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    CMVideoFormatDescriptionRef videoInfo = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault,
                                                                   pixelBuffer,
                                                                   &videoInfo);
    if (status != noErr) return NULL;

    CMSampleTimingInfo timing;
    timing.duration             = kCMTimeInvalid;
    timing.decodeTimeStamp      = kCMTimeInvalid;
    timing.presentationTimeStamp = CMTimeMakeWithSeconds(CACurrentMediaTime(), 1000000);

    CMSampleBufferRef sampleBuffer = NULL;
    status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                                pixelBuffer,
                                                true, NULL, NULL,
                                                videoInfo,
                                                &timing,
                                                &sampleBuffer);
    CFRelease(videoInfo);

    if (status != noErr) return NULL;
    return sampleBuffer;
}

#pragma mark - AVPictureInPictureControllerDelegate

- (void)pictureInPictureControllerWillStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    // Resolve the enterPictureInPicture callback as soon as PiP begins
    if (self.pipCallbackId) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:result callbackId:self.pipCallbackId];
        self.pipCallbackId = nil;
    }
}

- (void)pictureInPictureControllerDidStartPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    [self.commandDelegate evalJs:@"cordova.plugins.iotumHelper.PictureInPicture.fireOnStart();"];
}

- (void)pictureInPictureControllerDidStopPictureInPicture:(AVPictureInPictureController *)pictureInPictureController
{
    [self.commandDelegate evalJs:@"cordova.plugins.iotumHelper.PictureInPicture.fireOnStop();"];
    self.pipController = nil;
    if (@available(iOS 15.0, *)) {
        self.pipContentViewController = nil;
    }
    self.pipDisplayLayer = nil;
}

- (void)pictureInPictureController:(AVPictureInPictureController *)pictureInPictureController
    failedToStartPictureInPictureWithError:(NSError *)error
{
    NSLog(@"[IotumHelper] PiP failed to start: %@", error.localizedDescription);
    if (self.pipCallbackId) {
        CDVPluginResult *result = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                    messageAsString:error.localizedDescription];
        [self.commandDelegate sendPluginResult:result callbackId:self.pipCallbackId];
        self.pipCallbackId = nil;
    }
}

@end
