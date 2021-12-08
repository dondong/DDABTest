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
typedef NSDictionary<NSString *, DDIRReplaceResult *> DDIRChangeRecord;
+ (nonnull DDIRChangeRecord *)mergeIRFiles:(nonnull NSArray<NSString *> *)pathes withControlId:(UInt32)controlId toIRFile:(nonnull NSString *)outputPath;
+ (void)extractObjcDataAndFunctionDeclarationFromIRFiles:(nonnull NSArray<NSString *> *)pathes toIRFile:(nonnull NSString *)outputPath;
// change
- (void)remeveObjcData;
- (void)mergeObjcData;
- (void)synchronzieReplaceResult:(nonnull DDIRReplaceResult *)result;
@end

NS_ASSUME_NONNULL_END
