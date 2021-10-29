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
+ (void)mergeLLFiles:(nonnull NSArray<NSString *> *)pathes withControlId:(UInt32)controlId toLLFile:(nonnull NSString *)outputPath;
// change
- (void)mergeObjcData;
- (void)addControlVariable:(nonnull NSString *)name controlId:(UInt32)controlId section:(nonnull NSString *)section;
@end

NS_ASSUME_NONNULL_END
