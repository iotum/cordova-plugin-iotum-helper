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

- (void)pluginInitialize {
}

@end
