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
- (void)mergeClassInfos:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos withSize:(NSUInteger)size controlVariable:(nonnull NSString *)varName;
- (void)mergeCategoryInfos:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos forClass:(nonnull NSString *)clsName withSize:(NSUInteger)size controlVariable:(nonnull NSString *)varName;
@end

NS_ASSUME_NONNULL_END
