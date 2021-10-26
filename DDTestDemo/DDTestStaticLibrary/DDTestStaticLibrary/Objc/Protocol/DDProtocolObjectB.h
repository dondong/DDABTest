//
//  DDProtocolObjectB.h
//  DDTestStaticLibraryB
//
//  Created by dondong on 2021/10/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DDProtocolB <NSObject>
@required
@property(nonatomic,strong) NSString *protoReqStr;
- (void)protocolBInstanceTest;
+ (void)protocolBClassTest;
@optional
@property(nonatomic,strong) NSString *protoOpStr;
- (void)protocolBInstanceOptional_A;
- (void)protocolBInstanceOptional_B;
- (void)protocolBInstanceOptional_C;
+ (void)protocolBClassOptional_A;
+ (void)protocolBClassOptional_B;
+ (void)protocolBClassOptional_C;
@end

@interface DDProtocolObjectB : NSObject<DDProtocolB>

@end

NS_ASSUME_NONNULL_END
