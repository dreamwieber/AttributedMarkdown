#import <TargetConditionals.h>

#if TARGET_OS_IPHONE    // iPhone-specific

#import <UIKit/UIKit.h>
#define TARGET_PLATFORM_COLOR UIColor
#define TARGET_PLATFORM_FONT UIFont

#else                   // OS X-specific

#import <AppKit/AppKit.h>
#define TARGET_PLATFORM_COLOR NSColor
#define TARGET_PLATFORM_FONT NSFont

#endif
