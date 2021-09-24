//
//  DDTestChildObjectA.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/22.
//

#import "DDTestChildObjectA.h"

@implementation DDTestChildObjectA
+ (void)staticMethodTest
{
    [super staticMethodTest];
    DDLog(@"+[DDTestChildObjectA staticMethodTest]");
}

- (void)instanceMethodTest
{
    [super instanceMethodTest];
    DDLog(@"-[DDTestChildObjectA instanceMethodTest]");
}
@end
