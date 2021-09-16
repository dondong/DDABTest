//
//  DDTestSuperObject.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import "DDTestSuperObject.h"

@implementation DDTestSuperObject
+ (void)staticMethodTest {
    NSLog(@"DDTestSuperObject  staticMethodTest");
}
- (void)instanceMethodTest {
    NSLog(@"DDTestSuperObject  instanceMethodTest");
}
@end

@implementation DDTestSuperObjectEmpty
@end

@implementation DDTestSuperObjectEmpty(Empty)
@end
