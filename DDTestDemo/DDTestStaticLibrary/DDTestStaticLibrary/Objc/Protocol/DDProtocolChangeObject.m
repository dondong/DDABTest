//
//  DDProtocolChange.m
//  DDTestStaticLibrary
//
//  Created by dondong on 2021/10/25.
//

#import "DDProtocolChangeObject.h"

@implementation DDProtocolChangeObject
- (void)protocolInstanceTest
{
    DDLog(@"-[DDProtocolChangeObject<DDProtocolChange> protocolInstanceTest]");
#if DemoTarget==1
    [self protocolChangeInstanceRequried_A];
    if ([self respondsToSelector:@selector(protocolChangeInstanceOptional_A)]) {
        [self protocolChangeInstanceOptional_A];
    }
#else
    [self protocolChangeInstanceRequried_B];
    if ([self respondsToSelector:@selector(protocolChangeInstanceOptional_B)]) {
        [self protocolChangeInstanceOptional_B];
    }
#endif
}

+ (void)protocolClassTest
{
    DDLog(@"+[DDProtocolChangeObject<DDProtocolChange> protocolClassTest]");
#if DemoTarget==1
    [self protocolChangeClassRequried_A];
    if ([self respondsToSelector:@selector(protocolChangeClassOptional_A)]) {
        [self protocolChangeClassOptional_A];
    }
#else
    [self protocolChangeClassRequried_B];
    if ([self respondsToSelector:@selector(protocolChangeClassOptional_B)]) {
        [self protocolChangeClassOptional_B];
    }
#endif
}

#if DemoTarget==1
- (void)protocolChangeInstanceRequried_A
{
    DDLog(@"-[DDProtocolChangeObject<DDProtocolChange> protocolChangeInstanceRequried_A]");
}

- (void)protocolChangeInstanceOptional_A
{
    DDLog(@"-[DDProtocolChangeObject<DDProtocolChange> protocolChangeInstanceOptional_A]");
}

+ (void)protocolChangeClassRequried_A
{
    DDLog(@"+[DDProtocolChangeObject<DDProtocolChange> protocolChangeClassRequried_A]");
}

+ (void)protocolChangeClassOptional_A
{
    DDLog(@"+[DDProtocolChangeObject<DDProtocolChange> protocolChangeClassOptional_A]");
}

#else
- (void)protocolChangeInstanceRequried_B
{
    DDLog(@"-[DDProtocolChangeObject<DDProtocolChange> protocolChangeInstanceRequried_B]");
}

- (void)protocolChangeInstanceOptional_B
{
    DDLog(@"-[DDProtocolChangeObject<DDProtocolChange> protocolChangeInstanceOptional_B]");
}

+ (void)protocolChangeClassRequried_B
{
    DDLog(@"+[DDProtocolChangeObject<DDProtocolChange> protocolChangeClassRequried_B]");
}

+ (void)protocolChangeClassOptional_B
{
    DDLog(@"+[DDProtocolChangeObject<DDProtocolChange> protocolChangeClassOptional_B]");
}
#endif
@end
