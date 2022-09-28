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

- (void)pluginInitialize {
}

@end
