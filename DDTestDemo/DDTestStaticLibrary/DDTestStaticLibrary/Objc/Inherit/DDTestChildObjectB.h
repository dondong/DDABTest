//
//  DDTestChildObjectB.h
//  DDTestDemo
//
//  Created by dondong on 2021/9/22.
//

#import "DDTestObject.h"

NS_ASSUME_NONNULL_BEGIN

#if DemoTarget==1
@interface DDTestChildObjectB : DDTestObject
#else
@interface DDTestChildObjectB : DDTestSuperObject
#endif

@end

NS_ASSUME_NONNULL_END
