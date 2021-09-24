//
//  DDTestChildObjectB.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/22.
//

#import "DDTestChildObjectB.h"

@implementation DDTestChildObjectB
+ (void)staticMethodTest
{
    [super staticMethodTest];
    DDLog(@"+[DDTestChildObjectB staticMethodTest]");
}

- (void)instanceMethodTest
{
    [super instanceMethodTest];
    DDLog(@"-[DDTestChildObjectB instanceMethodTest]");
}
@end
