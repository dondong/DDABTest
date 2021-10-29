//
//  DDTestObject.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import "DDTestObject.h"

@interface DDTestObject()
+ (void)staticMethodTestForObject_Privaty;
- (void)instanceMethodTestForObject_Privaty;
@end

@implementation DDTestObject
- (instancetype)init
{
    self = [super init];
    if (self) {
        _f32 = 0.32;
        _d64 = 0.64;
    }
    return self;
}

+ (void)staticMethodTest
{
    [super staticMethodTest];
    DDLog(@"+[DDTestObject staticMethodTest]");
    [self staticMethodTestForObject];
    [self staticMethodTestForObject_Privaty];
}

- (void)instanceMethodTest
{
    [super instanceMethodTest];
    DDLog(@"-[DDTestObject instanceMethodTest]");
    DDLog(@"check ivar  _f32: %f,  _d64: %f", _f32, _d64);
    [self instanceMethodTestForObject];
    [self instanceMethodTestForObject_Privaty];
}

+ (void)staticMethodTestForObject
{
    DDLog(@"+[DDTestObject staticMethodTestForObject]");
}

- (void)instanceMethodTestForObject
{
    DDLog(@"-[DDTestObject instanceMethodTestForObject]");
}

+ (void)staticMethodTestForObject_Privaty
{
    DDLog(@"+[DDTestObject() staticMethodTestForObject_Privaty]");
}

- (void)instanceMethodTestForObject_Privaty
{
    DDLog(@"-[DDTestObject() instanceMethodTestForObject_Privaty]");
}
@end


@implementation DDTestSuperObjectEmpty
@end
