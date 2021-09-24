//
//  NSObject+B.h
//  DDTestDemoB
//
//  Created by dondong on 2021/9/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject(B1)
+ (void)categoryStaticTest_B1;
- (void)categoryInstanceTest_B1;
@end

@interface NSObject(B2)
+ (void)categoryStaticTest_B2;
- (void)categoryInstanceTest_B2;
@end

NS_ASSUME_NONNULL_END
