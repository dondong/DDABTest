//
//  DDTestSuperObject.h
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DDTestSuperObject : NSObject {
    NSInteger _val;
}
@property(nonatomic,strong) NSString *a;
@property(nonatomic,strong) NSString *b;
+ (void)staticMethodTest;
- (void)instanceMethodTest;
@end

//@interface DDTestSuperObjectEmpty : NSObject
//@end
//
//@interface DDTestSuperObjectEmpty(Empty)
//@end

NS_ASSUME_NONNULL_END
