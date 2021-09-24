//
//  DDTestSuperObject.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import "DDTestSuperObject.h"

@implementation DDTestSuperObject
- (instancetype)init
{
    self = [super init];
    if (self) {
        _val = DemoTarget;
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
    DDLog(@"%@ %@", self.a, self.b);
    DDLog(@"-[DDTestSuperObject instanceMethodTest]");
}
@end

//@implementation DDTestSuperObjectEmpty
//@end
//
//@implementation DDTestSuperObjectEmpty(Empty)
//@end
