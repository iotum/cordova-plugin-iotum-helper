#import "IotumHelperPlugin.h"

@implementation IotumHelperPlugin

- (void)setAppBackgroundColor:(CDVInvokedUrlCommand *)command
{
    NSString* color = [[NSString stringWithFormat:@"%@", [command.arguments objectAtIndex:0]] lowercaseString];

    if ([color hasPrefix:@"#"]) {
        // Set main view color
        UIWindow *window = [[[UIApplication sharedApplication] delegate] window];
        UIView *topView = window.rootViewController.view;
        topView.backgroundColor = [self colorFromHexString:color];
    }
}

// Supports a four-byte hex value (ARGB)
// Note: this is different from the CSS color (RGBA)
- (UIColor *)colorFromHexString:(NSString*)hexString {
    unsigned int rgbValue = 0;
    hexString = [hexString stringByReplacingOccurrencesOfString:@"#" withString:@"0xFF"];
    NSScanner *scanner = [NSScanner scannerWithString:hexString];
    [scanner scanHexInt:&rgbValue];

    return [UIColor colorWithRed:((float)((rgbValue & 0x00FF0000) >> 16)) / 255.0
                           green:((float)((rgbValue & 0x0000FF00) >>  8)) / 255.0
                            blue:((float)((rgbValue & 0x000000FF) >>  0)) / 255.0
                           alpha:((float)((rgbValue & 0xFF000000) >> 24)) / 255.0];
}


- (void)pluginInitialize {
}


@end
