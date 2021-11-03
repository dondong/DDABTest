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

@interface DDTestDemo() {
}
#if DemoTarget==1
#else
@property(nonatomic,strong) NSString *strB;
@property(nonatomic,assign) NSInteger intB;
- (NSInteger)printString:(nonnull NSString *)str andInt:(NSInteger)intVal;
#endif
@end

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
    
    DDLog(@"library");
#if DemoTarget==1
    [self testA];
#else
    [self testB];
#endif
    
    DDLog(@"End test ...");
}
#if DemoTarget==1
+ (void)testA
{
    DDLog(@"+[DDTestDemo testA]");
}
#else
+ (void)testB
{
    DDLog(@"+[DDTestDemo testB]");
    [self testOtherB];
    DDTestDemo *demo = [[DDTestDemo alloc] init];
    demo.strB = @"before";
    demo.intB = 2010;
    [demo printString:@"after" andInt:2020];
}

+ (void)testOtherB
{
    DDLog(@"+[DDTestDemo testOtherB]");
}

- (NSInteger)printString:(nonnull NSString *)str andInt:(NSInteger)intVal
{
    DDLog(@"before -[DDTestDemo printString:andInt:]  strB: %@  intB: %d", self.strB, self.intB);
    self.strB = str;
    self.intB = intVal;
    DDLog(@"after -[DDTestDemo printString:andInt:]  strB: %@  intB: %d", self.strB, self.intB);
    return 0;
}
#endif
@end
