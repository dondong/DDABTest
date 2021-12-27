//
//  DDTestManager.h
//  DDTestStaticLibrary
//
//  Created by dondong on 2021/12/21.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const DDTestManagerTestNotification;
//extern NSString * DDTestManagerTestString;

@interface DDTestManager : NSObject
+ (instancetype)sharedInstance;
- (void)test;
@end

NS_ASSUME_NONNULL_END
