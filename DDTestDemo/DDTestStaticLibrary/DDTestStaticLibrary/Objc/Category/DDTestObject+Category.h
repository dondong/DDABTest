//
//  DDTestObject+Category.h
//  DDTestDemo
//
//  Created by dondong on 2021/9/22.
//

#import "DDTestObject.h"

NS_ASSUME_NONNULL_BEGIN

#if DemoTarget==1
@interface DDTestObject(Category)
#else
@interface DDTestSuperObject(Category)
#endif
+ (void)categoryStaticTestObject;
- (void)categoryInstanceTestObject;
@end

@interface DDTestObject(Empty)
@end

NS_ASSUME_NONNULL_END
