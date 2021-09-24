//
//  NSObject+A.m
//  DDTestDemoA
//
//  Created by dondong on 2021/9/22.
//

#import "NSObject+A.h"

@implementation NSObject(A)
+ (void)categoryStaticTest_A
{
    DDLog(@"+[NSObject(A) categoryStaticTest_A]");
}

- (void)categoryInstanceTest_A
{
    DDLog(@"-[NSObject(A) categoryInstanceTest_A]");
}
@end
