#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Error domain used for `NSException`s converted by `FPVExceptionCatcher`.
extern NSErrorDomain const FPVExceptionCatcherErrorDomain;

/// `userInfo` key holding `NSException.name` (an `NSString`).
extern NSString *const FPVExceptionNameKey;
/// `userInfo` key holding `NSException.reason`. Absent when the exception had
/// no reason, so callers can reproduce Objective-C's `(null)` formatting.
extern NSString *const FPVExceptionReasonKey;
/// `userInfo` key holding `NSException.description`, i.e. what
/// `NSLog(@"%@", exception)` would have printed.
extern NSString *const FPVExceptionDescriptionKey;

/// Bridges Objective-C's `@try`/`@catch` to Swift.
///
/// Swift cannot catch `NSException`, but PDFKit (like most of UIKit) still
/// raises them. Anywhere the Objective-C implementation of this plugin wrapped
/// a PDFKit call in `@try`/`@catch`, the Swift implementation routes the same
/// call through this shim so the behaviour (log a warning, keep going) is
/// preserved.
///
/// This is deliberately the only Objective-C left in the plugin; it lives in
/// its own SwiftPM target because SwiftPM forbids mixed-language targets.
@interface FPVExceptionCatcher : NSObject

/// Runs `block`, translating any raised `NSException` into `error`.
///
/// @param block The work to perform. Never escapes.
/// @param error On return, the exception that was raised, if any.
/// @return `YES` if `block` completed without raising, `NO` otherwise.
+ (BOOL)catchException:(void (NS_NOESCAPE ^)(void))block
                 error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
