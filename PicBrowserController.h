/* PicBrowserController */

#import <Cocoa/Cocoa.h>

@interface PicBrowserController : NSObject
{
    IBOutlet id imageView;
    IBOutlet id ipAddressField;
    IBOutlet id pictureServiceList;
    IBOutlet id portField;

    NSNetServiceBrowser * browser;
    NSMutableArray * services;
    NSNetService * serviceBeingResolved;
}
- (IBAction)serviceClicked:(id)sender;
@end
