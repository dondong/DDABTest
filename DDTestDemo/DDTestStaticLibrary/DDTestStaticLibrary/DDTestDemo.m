//
//  DDTestDemo.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import "DDTestDemo.h"
#import "DDTestChildObjectA.h"
#import "DDTestChildObjectB.h"
#import "NSObject+Category.h"
#import "DDTestObject+Category.h"

@implementation DDTestDemo
+ (void)test
{
    DDLog(@"Begin test ...");
    
    DDLog(@"Inberit");
    [DDTestChildObjectA staticMethodTest];
    DDTestChildObjectA *a = [[DDTestChildObjectA alloc] init];
    [a instanceMethodTest];
    
    [DDTestChildObjectB staticMethodTest];
    DDTestChildObjectB *b = [[DDTestChildObjectB alloc] init];
    [b instanceMethodTest];
    
    
    DDLog(@"Category");
    [NSObject categoryStaticTest];
    NSObject *o = [[NSObject alloc] init];
    [o categoryInstanceTest];
    [DDTestObject categoryStaticTest];
    DDTestObject *o1 = [[DDTestObject alloc] init];
    [o1 categoryInstanceTest];
    
#if DemoTarget==1
#else
#endif
    
    DDLog(@"End test ...");
}
@end
