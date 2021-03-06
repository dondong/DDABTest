//
//  NSObject+Category.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/22.
//

#import "NSObject+Category.h"
#import "DDTestObject+Category.h"
#if DemoTarget==1
#import "NSObject+A.h"
#else
#import "NSObject+B.h"
#endif

@implementation NSObject(Category)
+ (void)categoryStaticTest
{
    DDLog(@"+[NSObject(Category) categoryStaticTest]");
    [DDTestObject categoryStaticTestObject];
#if DemoTarget==1
    [self categoryStaticTest_A];
#else
    [self categoryStaticTest_B1];
    [self categoryStaticTest_B2];
#endif
}

- (void)categoryInstanceTest
{
    DDLog(@"-[NSObject(Category) categoryInstanceTest]");
    DDTestObject *o = [[DDTestObject alloc] init];
    [o categoryInstanceTestObject];
#if DemoTarget==1
    [self categoryInstanceTest_A];
#else
    [self categoryInstanceTest_B1];
    [self categoryInstanceTest_B2];
#endif
}
@end
