#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wquoted-include-in-framework-header"
#import "FIRApp.h"
#import "FIRConfiguration.h"
#import "FirebaseCore.h"
#import "FIRLoggerLevel.h"
#import "FIROptions.h"
#import "FIRTimestamp.h"
#import "FIRVersion.h"
#pragma clang diagnostic pop

FOUNDATION_EXPORT double FirebaseCoreVersionNumber;
FOUNDATION_EXPORT const unsigned char FirebaseCoreVersionString[];

