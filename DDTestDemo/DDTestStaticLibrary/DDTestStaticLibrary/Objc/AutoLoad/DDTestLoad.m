//
//  DDTestLoad.m
//  DDTestStaticLibrary
//
//  Created by dondong on 2021/11/4.
//

#import "DDTestLoad.h"

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
