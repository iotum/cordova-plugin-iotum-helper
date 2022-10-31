#import "IotumHelperPlugin.h"
#import <objc/runtime.h>

@implementation IotumHelperPlugin

#pragma mark Initialize

NSString* WKClassString;
static IMP WKOriginalImp;

- (void)pluginInitialize
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

    [nc addObserver:self selector:@selector(keyboardDidShow:) name:UIKeyboardDidShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardDidHide:) name:UIKeyboardDidHideNotification object:nil];

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
    [self.webView.scrollView setContentInset:UIEdgeInsetsZero];

    CGSize rect = [notif.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    NSString *js = [NSString stringWithFormat:@"cordova.plugins.iotumHelper.Keyboard.fireOnShow(%d);", (int)rect.height];
    [self.commandDelegate evalJs:js];
}

- (void)keyboardDidHide: (NSNotification *) notif {
    [self.commandDelegate evalJs:@"cordova.plugins.iotumHelper.Keyboard.fireOnHide();"];

    [self.webView.scrollView setContentInset:UIEdgeInsetsZero];
}

@end
