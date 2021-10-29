//
//  DDTestChildObjectA.h
//  DDTestDemo
//
//  Created by dondong on 2021/9/22.
//

#import "DDTestObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface DDTestChildObjectA : DDTestObject {
#if DemoTarget==1
    NSArray *_arr;
#else
    NSSet *_set;
    NSDictionary *_dic;
#endif
}

@end

NS_ASSUME_NONNULL_END
