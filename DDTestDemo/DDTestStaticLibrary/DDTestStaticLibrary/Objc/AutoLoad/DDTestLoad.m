//
//  DDTestLoad.m
//  DDTestStaticLibrary
//
//  Created by dondong on 2021/11/4.
//

#import "DDTestLoad.h"

@interface DDTestLoad(Load1)
@end

@implementation DDTestLoad(Load1)
+ (void)load
{
    DDLog(@"+[DDTestLoad(Load1) load]");
    DDTestLoad *l = [[DDTestLoad alloc] init];
    [l instanceTest1];
}
+ (void)classTest1
{
    DDLog(@"+[DDTestLoad classTest1]");
}
- (void)instanceTest1
{
    DDLog(@"-[DDTestLoad instanceTest1]");
}
@end

@interface DDTestLoad(Load2)
@end

@implementation DDTestLoad(Load2)
+ (void)load
{
    DDLog(@"+[DDTestLoad(Load2) load]");
    DDTestLoad *l = [[DDTestLoad alloc] init];
    [l instanceTest2];
}
+ (void)classTest2
{
    DDLog(@"+[DDTestLoad classTest2]");
}
- (void)instanceTest2
{
    DDLog(@"-[DDTestLoad instanceTest2]");
}
@end

@implementation DDTestLoad
+ (void)classTest
{
    DDLog(@"+[DDTestLoad classTest]");
}

- (void)instanceTest
{
    DDLog(@"-[DDTestLoad instanceTest]");
}

+ (void)load
{
    DDLog(@"+[DDTestLoad load]");
    [self classTest1];
    [self classTest2];
#if DemoTarget==1
#else
    [self classTest];
#endif
}
+ (void)initialize
{
    DDLog(@"+[DDTestLoad initialize]");
}
@end

__attribute__((constructor))
void initFuncTest(void)
{
    DDLog(@"initFuncTest");
}

#if DemoTarget==1
#else
__attribute__((constructor))
#endif
void initFuncTestOption(void)
{
    DDLog(@"initFuncTestOption");
}
