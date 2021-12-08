//
//  DDTestObject+Category.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/22.
//

#import "DDTestObject+Category.h"

#if DemoTarget==1
@implementation DDTestObject(Category)
#else
@implementation DDTestSuperObject(Category)
#endif
+ (void)categoryStaticTestObject
{
    DDLog(@"+[DDTestObject(Category) categoryStaticTestObject]");
}
- (void)categoryInstanceTestObject
{
    DDLog(@"-[DDTestObject(Category) categoryInstanceTestObject]");
}
@end

@implementation DDTestObject(Empty)
@end
