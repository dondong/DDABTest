//
//  DDTestObjectB.h
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import "DDTestSuperObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface DDTestObjectB : DDTestSuperObject {
    NSInteger _valB;
}
@property(nonatomic,strong) NSString *a2;
@property(nonatomic,strong) NSString *b2;
+ (void)staticMethodTestForObjectB;
- (void)instanceMethodTestForObjectB;
@end

NS_ASSUME_NONNULL_END
