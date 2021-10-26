//
//  DDProtocolObjectA.h
//  DDTestStaticLibraryA
//
//  Created by dondong on 2021/10/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@protocol DDProtocolA <NSObject>
@required
@property(nonatomic,strong) NSString *protoReqStr;
- (void)protocolAInstanceTest;
+ (void)protocolAClassTest;
@optional
@property(nonatomic,strong) NSString *protoOpStr;
- (void)protocolAInstanceOptional_A;
- (void)protocolAInstanceOptional_B;
- (void)protocolAInstanceOptional_C;
+ (void)protocolAClassOptional_A;
+ (void)protocolAClassOptional_B;
+ (void)protocolAClassOptional_C;
@end

@interface DDProtocolObjectA : NSObject<DDProtocolA>

@end

NS_ASSUME_NONNULL_END
