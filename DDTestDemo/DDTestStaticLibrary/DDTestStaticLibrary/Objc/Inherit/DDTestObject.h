//
//  DDTestObject.h
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import "DDTestSuperObject.h"

NS_ASSUME_NONNULL_BEGIN


@interface DDTestObject : DDTestSuperObject {
}
+ (void)staticMethodTestForObject;
- (void)instanceMethodTestForObject;
@end

NS_ASSUME_NONNULL_END
