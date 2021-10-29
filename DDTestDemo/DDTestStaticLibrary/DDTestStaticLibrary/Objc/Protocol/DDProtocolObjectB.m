//
//  DDProtocolObjectB.m
//  DDTestStaticLibraryB
//
//  Created by dondong on 2021/10/25.
//

#import "DDProtocolObjectB.h"

@implementation DDProtocolObjectB
@synthesize protoReqStr;
@synthesize protoOpStr;

- (void)protocolBInstanceTest
{
    self.protoReqStr = @"BB";
    DDLog(@"-[DDProtocolObjectB<DDProtocolB> protocolBInstanceTest]  %@", self.protoReqStr);
    if ([self respondsToSelector:@selector(protocolBInstanceOptional_A)]) {
        [self protocolBInstanceOptional_A];
    }
    if ([self respondsToSelector:@selector(protocolBInstanceOptional_B)]) {
        [self protocolBInstanceOptional_B];
    }
    if ([self respondsToSelector:@selector(protocolBInstanceOptional_C)]) {
        [self protocolBInstanceOptional_C];
    }
}

+ (void)protocolBClassTest
{
    DDLog(@"+[DDProtocolObjectB<DDProtocolB> protocolBClassTest]");
    if ([self respondsToSelector:@selector(protocolBClassOptional_A)]) {
        [self protocolBClassOptional_A];
    }
    if ([self respondsToSelector:@selector(protocolBClassOptional_B)]) {
        [self protocolBClassOptional_B];
    }
    if ([self respondsToSelector:@selector(protocolBClassOptional_C)]) {
        [self protocolBClassOptional_C];
    }
}

- (void)protocolBInstanceOptional_A
{
    DDLog(@"-[DDProtocolObjectB<DDProtocolB> protocolBInstanceOptional_A]");
}

- (void)protocolBInstanceOptional_C
{
    DDLog(@"-[DDProtocolObjectB<DDProtocolB> protocolBInstanceOptional_C]");
}

+ (void)protocolBClassOptional_A
{
    DDLog(@"+[DDProtocolObjectB<DDProtocolB> protocolBClassOptional_A]");
}

+ (void)protocolBClassOptional_C
{
    DDLog(@"+[DDProtocolObjectB<DDProtocolB> protocolBClassOptional_A]");
}

@end
