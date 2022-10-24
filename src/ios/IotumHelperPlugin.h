#import <Cordova/CDVPlugin.h>

@interface IotumHelperPlugin : CDVPlugin
- (void)setAppBackgroundColor:(CDVInvokedUrlCommand*)command;
- (void)hideKeyboardAccessoryBar:(CDVInvokedUrlCommand *)command;
@end
