//
//  DDTestObjectA.h
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import "DDTestSuperObject.h"

NS_ASSUME_NONNULL_BEGIN

@protocol DDTestObjectAProtocol <NSObject>
+ (void)staticMethodTestForObjectAProtocol;
- (void)instanceMethodTestForObjectAProtocol;
@end

@interface DDTestObjectA : DDTestSuperObject<DDTestObjectAProtocol> {
    NSInteger _valA;
}
@property(nonatomic,strong) NSString *a2;
@property(nonatomic,strong) NSString *b2;
+ (void)staticMethodTestForObjectA;
- (void)instanceMethodTestForObjectA;
@end

@interface NSObject(ObjectA)

@end

NS_ASSUME_NONNULL_END
