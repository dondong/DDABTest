//
//  DDTestSuperObject.h
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DDTestSuperObject : NSObject {
#if DemoTarget==1
    uint32_t _i32;
    uint8_t  _i8;
    uint64_t _i64;
    NSString *_str;
#else
    uint64_t _i64;
    uint32_t _i32;
    NSString *_str;
    NSNumber *_num;
    NSValue  *_val;
#endif
}
@property(nonatomic,strong) NSString *a;
@property(nonatomic,strong) NSString *b;
+ (void)staticMethodTest;
- (void)instanceMethodTest;
@end


NS_ASSUME_NONNULL_END
