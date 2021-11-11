//
//  DDTestSuperObject.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import "DDTestSuperObject.h"
#import <objc/runtime.h>

@implementation DDTestSuperObject
#if DemoTarget==1
@synthesize a;
@synthesize b;
#else
@synthesize c;
#endif

- (instancetype)init
{
    self = [super init];
    if (self) {
#if DemoTarget==1
        _i32 = 1032;
        _i8  = 10;
        _i64 = 1064;
        _str = @"From Demo A";
        self.a = [NSString stringWithFormat:@"Ivar a In %@", DemoName];
        self.b = [NSString stringWithFormat:@"Ivar b In %@", DemoName];
#else
        _i64 = 2064;
        _i32 = 2032;
        _str = @"From Demo B";
        _num = @(2000);
        _val = [NSValue valueWithRange:NSMakeRange(0, 100)];
        self.c = 2033;
#endif
    }
    return self;
}

+ (void)staticMethodTest
{
    DDLog(@"+[DDTestSuperObject staticMethodTest]");
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList(NSClassFromString(@"DDTestSuperObject"), &count);
    for (int i = 0; i < count; ++i) {
        DDLog(@"Class: DDTestSuperObject   name: %s   attribute: %s", property_getName(properties[i]), property_getAttributes(properties[i]));
    }
}
- (void)instanceMethodTest
{
    DDLog(@"-[DDTestSuperObject instanceMethodTest]");
#if DemoTarget==1
    DDLog(@"%@ %@", self.a, self.b);
    DDLog(@"check ivar  _i8: %d,  _i32: %d,  _i64: %llu,  _str: %@", _i8, _i32, _i64, _str);
#else
    DDLog(@"%zd", self.c);
    DDLog(@"check ivar  _i32: %d,  _i64: %llu,  _str: %@,  _num: %@,  _val: %@", _i32, _i64, _str, _num, _val);
#endif
}
@end

