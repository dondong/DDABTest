//
//  DDTestSuperObject.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import "DDTestSuperObject.h"

@implementation DDTestSuperObject
@synthesize a;
@synthesize b;

- (instancetype)init
{
    self = [super init];
    if (self) {
#if DemoTarget==1
        _i32 = 1032;
        _i8  = 10;
        _i64 = 1064;
        _str = @"From Demo A";
#else
        _i64 = 2064;
        _i32 = 2032;
        _str = @"From Demo B";
        _num = @(2000);
        _val = [NSValue valueWithRange:NSMakeRange(0, 100)];
#endif
        self.a = [NSString stringWithFormat:@"Ivar a In %@", DemoName];
        self.b = [NSString stringWithFormat:@"Ivar b In %@", DemoName];
    }
    return self;
}

+ (void)staticMethodTest
{
    DDLog(@"+[DDTestSuperObject staticMethodTest]");
}
- (void)instanceMethodTest
{
    DDLog(@"-[DDTestSuperObject instanceMethodTest]");
    DDLog(@"%@ %@", self.a, self.b);
#if DemoTarget==1
    DDLog(@"check ivar  _i8: %d,  _i32: %d,  _i64: %llu,  _str: %@", _i8, _i32, _i64, _str);
#else
    DDLog(@"check ivar  _i32: %d,  _i64: %llu,  _str: %@,  _num: %@,  _val: %@", _i32, _i64, _str, _num, _val);
#endif
}
@end

