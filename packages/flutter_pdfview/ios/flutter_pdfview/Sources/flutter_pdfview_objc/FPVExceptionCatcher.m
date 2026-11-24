#import "./include/FPVExceptionCatcher.h"

NSErrorDomain const FPVExceptionCatcherErrorDomain =
    @"io.endigo.plugins.pdfviewflutter.FPVExceptionCatcher";

NSString *const FPVExceptionNameKey = @"FPVExceptionName";
NSString *const FPVExceptionReasonKey = @"FPVExceptionReason";
NSString *const FPVExceptionDescriptionKey = @"FPVExceptionDescription";

@implementation FPVExceptionCatcher

+ (BOOL)catchException:(void (NS_NOESCAPE ^)(void))block
                 error:(NSError *_Nullable __autoreleasing *_Nullable)error {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (error != NULL) {
            NSMutableDictionary<NSString *, id> *userInfo =
                [NSMutableDictionary dictionary];
            userInfo[FPVExceptionNameKey] = exception.name;
            userInfo[FPVExceptionDescriptionKey] = exception.description;
            if (exception.reason != nil) {
                userInfo[FPVExceptionReasonKey] = exception.reason;
                userInfo[NSLocalizedDescriptionKey] = exception.reason;
            } else {
                userInfo[NSLocalizedDescriptionKey] = exception.name;
            }
            *error = [NSError errorWithDomain:FPVExceptionCatcherErrorDomain
                                         code:0
                                     userInfo:userInfo];
        }
        return NO;
    }
}

@end
