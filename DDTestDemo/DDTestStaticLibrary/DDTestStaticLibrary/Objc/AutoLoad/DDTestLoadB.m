//
//  DDTestLoadB.m
//  DDTestStaticLibraryB
//
//  Created by dondong on 2021/11/9.
//

#import "DDTestLoadB.h"

@implementation DDTestLoadB
+ (void)load
{
    DDLog(@"+[DDTestLoadB load]");
}
@end


__attribute__((constructor))
void initFuncTestB1(void)
{
    DDLog(@"initFuncTestB1");
}

__attribute__((constructor))
void initFuncTestB2(void)
{
    DDLog(@"initFuncTestB2");
}
