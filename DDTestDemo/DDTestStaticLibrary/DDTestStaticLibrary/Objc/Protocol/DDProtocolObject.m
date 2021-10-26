//
//  DDProtocolObject.m
//  DDTestStaticLibrary
//
//  Created by dondong on 2021/10/25.
//

#import "DDProtocolObject.h"
#if DemoTarget==1
#import "DDProtocolObjectA.h"
#else
#import "DDProtocolObjectB.h"
#endif

@implementation DDProtocolObject
- (void)protocolInstanceTest
{
    DDLog(@"-[DDProtocolObject<DDProtocol> protocolInstanceTest]");
    if ([self respondsToSelector:@selector(protocolInstanceOptional_A)]) {
        [self protocolInstanceOptional_A];
    }
    if ([self respondsToSelector:@selector(protocolInstanceOptional_B)]) {
        [self protocolInstanceOptional_B];
    }
#if DemoTarget==1
    id<DDProtocolA> o = [[DDProtocolObjectA alloc] init];
    [o protocolAInstanceTest];
#else
    id<DDProtocolB> o = [[DDProtocolObjectB alloc] init];
    [o protocolBInstanceTest];
#endif
}

+ (void)protocolClassTest
{
    DDLog(@"+[DDProtocolObject<DDProtocol> protocolClassTest]");
    if ([self respondsToSelector:@selector(protocolClassOptional_A)]) {
        [self protocolClassOptional_A];
    }
    if ([self respondsToSelector:@selector(protocolClassOptional_B)]) {
        [self protocolClassOptional_B];
    }
#if DemoTarget==1
    [DDProtocolObjectA protocolAClassTest];
#else
    [DDProtocolObjectB protocolBClassTest];
#endif
}

- (void)protocolInstanceOptional_A
{
    DDLog(@"-[DDProtocolObject<DDProtocol> protocolInstanceOptional_A]");
}
#if DemoTarget==1
- (void)protocolInstanceOptional_B
{
    DDLog(@"-[DDProtocolObject<DDProtocol> protocolInstanceOptional_B]");
}
#endif

+ (void)protocolClassOptional_A
{
    DDLog(@"+[DDProtocolObject<DDProtocol> protocolClassOptional_A]");
}
#if DemoTarget==2
+ (void)protocolClassOptional_B
{
    DDLog(@"+[DDProtocolObject<DDProtocol> protocolClassOptional_B]");
}
#endif
@end
