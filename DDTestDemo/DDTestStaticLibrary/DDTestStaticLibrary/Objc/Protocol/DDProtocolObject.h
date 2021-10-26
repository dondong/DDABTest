//
//  DDProtocolObject.h
//  DDTestStaticLibrary
//
//  Created by dondong on 2021/10/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DDProtocol <NSObject>
@required
- (void)protocolInstanceTest;
+ (void)protocolClassTest;
@optional
- (void)protocolInstanceOptional_A;
- (void)protocolInstanceOptional_B;
+ (void)protocolClassOptional_A;
+ (void)protocolClassOptional_B;
@end

@interface DDProtocolObject : NSObject<DDProtocol>

@end

NS_ASSUME_NONNULL_END
