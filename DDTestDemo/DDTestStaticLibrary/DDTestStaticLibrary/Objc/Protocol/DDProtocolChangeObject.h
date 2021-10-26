//
//  DDProtocolChangeObject.h
//  DDTestStaticLibrary
//
//  Created by dondong on 2021/10/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol DDProtocolChange <NSObject>
@required
- (void)protocolInstanceTest;
+ (void)protocolClassTest;
#if DemoTarget==1
- (void)protocolChangeInstanceRequried_A;
+ (void)protocolChangeClassRequried_A;
#else
- (void)protocolChangeInstanceRequried_B;
+ (void)protocolChangeClassRequried_B;
#endif
@optional
#if DemoTarget==1
- (void)protocolChangeInstanceOptional_A;
+ (void)protocolChangeClassOptional_A;
#else
- (void)protocolChangeInstanceOptional_B;
+ (void)protocolChangeClassOptional_B;
#endif
@end

@interface DDProtocolChangeObject : NSObject<DDProtocolChange>

@end

NS_ASSUME_NONNULL_END
