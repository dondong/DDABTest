//
//  DDIRFunction.h
//  DDToolKit
//
//  Created by dondong on 2021/8/31.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, DDIRFunctionType) {
    DDIRFunctionType_Declare = 0,
    DDIRFunctionType_Define  = 1
};

@interface DDIRFunction : NSObject
@property(nonatomic,strong,nonnull) NSString *name;
@property(nonatomic,assign) DDIRFunctionType type;
@end

NS_ASSUME_NONNULL_END
