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
#import "DDProtocolObject.h"

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
    
    DDLog(@"Procotol");
    [DDProtocolObject protocolClassTest];
    id<DDProtocol> p = [[DDProtocolObject alloc] init];
    [p protocolInstanceTest];
    
#if DemoTarget==1
#else
#endif
    
    DDLog(@"End test ...");
}
@end
