//
//  DDTestManager.m
//  DDTestStaticLibrary
//
//  Created by dondong on 2021/12/21.
//

#import "DDTestManager.h"

@implementation DDTestManager
#if DemoTarget==1
NSString * const DDTestManagerTestNotification = @"DDTestManagerTestNotification_A";
#else
NSString * const DDTestManagerTestNotification = @"DDTestManagerTestNotification_B";
#endif
//NSString * DDTestManagerTestString = nil;

+ (instancetype)sharedInstance
{
    static DDTestManager *_sharedInstance = nil;
    @synchronized (self) {
        if (nil == _sharedInstance) {
            _sharedInstance = [[self alloc] init];
        }
    }
    return  _sharedInstance;
}

- (void)test
{
    DDLog(@"-[DDTestManager test]");
//    DDTestManagerTestString = @"DDTestManagerTestString";
    [[NSNotificationCenter defaultCenter] postNotification:DDTestManagerTestNotification];
}
@end
