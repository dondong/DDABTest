//
//  DDProtocolObjectA.m
//  DDTestStaticLibraryA
//
//  Created by dondong on 2021/10/25.
//

#import "DDProtocolObjectA.h"

@implementation DDProtocolObjectA
@synthesize protoReqStr;
@synthesize protoOpStr;

- (void)protocolAInstanceTest
{
    self.protoReqStr = @"AA";
    DDLog(@"-[DDProtocolObjectA<DDProtocolA> protocolAInstanceTest]  %@", self.protoReqStr);
    if ([self respondsToSelector:@selector(protocolAInstanceOptional_A)]) {
        [self protocolAInstanceOptional_A];
    }
    if ([self respondsToSelector:@selector(protocolAInstanceOptional_B)]) {
        [self protocolAInstanceOptional_B];
    }
    if ([self respondsToSelector:@selector(protocolAInstanceOptional_C)]) {
        [self protocolAInstanceOptional_C];
    }
}

+ (void)protocolAClassTest
{
    DDLog(@"+[DDProtocolObjectA<DDProtocolA> protocolAClassTest]");
    if ([self respondsToSelector:@selector(protocolAClassOptional_A)]) {
        [self protocolAClassOptional_A];
    }
    if ([self respondsToSelector:@selector(protocolAClassOptional_B)]) {
        [self protocolAClassOptional_B];
    }
    if ([self respondsToSelector:@selector(protocolAClassOptional_C)]) {
        [self protocolAClassOptional_C];
    }
}

- (void)protocolAInstanceOptional_B
{
    DDLog(@"-[DDProtocolObjectA<DDProtocolA> protocolAInstanceOptional_B]");
}

- (void)protocolAInstanceOptional_C
{
    DDLog(@"-[DDProtocolObjectA<DDProtocolA> protocolAInstanceOptional_C]");
}

+ (void)protocolAClassOptional_B
{
    DDLog(@"+[DDProtocolObjectA<DDProtocolA> protocolAClassOptional_B]");
}

+ (void)protocolAClassOptional_C
{
    DDLog(@"+[DDProtocolObjectA<DDProtocolA> protocolAClassOptional_C]");
}
@end
