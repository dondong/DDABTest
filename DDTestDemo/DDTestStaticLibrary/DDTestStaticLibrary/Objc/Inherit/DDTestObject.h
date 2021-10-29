//
//  DDTestObject.h
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import "DDTestSuperObject.h"

NS_ASSUME_NONNULL_BEGIN


@interface DDTestObject : DDTestSuperObject {
    float  _f32;
    double _d64;
}
+ (void)staticMethodTestForObject;
- (void)instanceMethodTestForObject;
@end


@interface DDTestSuperObjectEmpty : NSObject
@end

NS_ASSUME_NONNULL_END
