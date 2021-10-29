//
//  DDTestChildObjectA.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/22.
//

#import "DDTestChildObjectA.h"

@implementation DDTestChildObjectA
- (instancetype)init
{
    self = [super init];
    if (self) {
#if DemoTarget==1
        _arr = @[@(101), @(102)];
#else
        _set = [NSSet setWithArray:@[@(204), @(205), @(206)]];
        _dic = @{@"bkey_1": @(207), @"bkey_2": @(208)};
#endif
    }
    return self;
}
+ (void)staticMethodTest
{
    [super staticMethodTest];
    DDLog(@"+[DDTestChildObjectA staticMethodTest]");
}

- (void)instanceMethodTest
{
    [super instanceMethodTest];
    DDLog(@"-[DDTestChildObjectA instanceMethodTest]");
#if DemoTarget==1
    DDLog(@"check ivar  _arr: %@", _arr);
#else
    DDLog(@"check ivar  _set: %@,  _dic: %@", _set, _dic);
#endif
}
@end
