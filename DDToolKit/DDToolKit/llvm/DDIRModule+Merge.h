//
//  DDIRModule+Merge.h
//  DDToolKit
//
//  Created by dondong on 2021/10/21.
//

#import "DDIRModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface DDIRModuleMergeInfo : NSObject
@property(nonatomic,strong,readonly,nonnull) NSString *target;
@property(nonatomic,assign) NSInteger index;
+ (instancetype)infoWithTarget:(nonnull NSString *)target index:(NSUInteger)index;
@end

@interface DDIRModule(Merge)
+ (void)mergeLLFiles:(nonnull NSArray<NSString *> *)pathes toLLFile:(nonnull NSString *)outputPath;
- (void)mergeObjcData;
@end

NS_ASSUME_NONNULL_END
