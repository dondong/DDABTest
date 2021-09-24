//
//  NSObject+Category.h
//  DDTestDemo
//
//  Created by dondong on 2021/9/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSObject(Category)
+ (void)categoryStaticTest;
- (void)categoryInstanceTest;
@end


NS_ASSUME_NONNULL_END
