//
//  NSObject+B.m
//  DDTestDemoB
//
//  Created by dondong on 2021/9/22.
//

#import "NSObject+B.h"

@implementation NSObject(B1)
+ (void)categoryStaticTest_B1
{
    DDLog(@"+[NSObject(B1) categoryStaticTest_B1]");
}

- (void)categoryInstanceTest_B1
{
    DDLog(@"-[NSObject(B1) categoryInstanceTest_B1]");
}
@end

@implementation NSObject(B2)
+ (void)categoryStaticTest_B2
{
    DDLog(@"+[NSObject(B2) categoryStaticTest_B2]");
}

- (void)categoryInstanceTest_B2
{
    DDLog(@"-[NSObject(B2) categoryInstanceTest_B2]");
}
@end
