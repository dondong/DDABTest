//
//  DDIRModule+Merge.h
//  DDToolKit
//
//  Created by dondong on 2021/10/21.
//

#import "DDIRModule.h"
#import "DDIRChangeItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface DDIRModuleMergeInfo : NSObject
@property(nonatomic,strong,readonly,nonnull) NSString *target;
@property(nonatomic,assign) NSInteger index;
+ (instancetype)infoWithTarget:(nonnull NSString *)target index:(NSUInteger)index;
@end

//static NSString * const DDIRReplaceResultGlobalVariableKey;
//static NSString * const DDIRReplaceResultFunctionKey;
typedef NSDictionary<NSString *, NSArray<NSString *> *> DDIRChangeDeclareRecord;
@interface DDIRModulePath(Merge)
@property(nonatomic,strong) DDIRChangeDeclareRecord *declareChangedRecord;
@end

@interface DDIRModule(Merge)
typedef NSDictionary<NSString *, NSArray<DDIRChangeItem *> *> DDIRChangeReplaceRecord;
+ (nonnull DDIRChangeReplaceRecord *)mergeIRFiles:(nonnull NSArray<NSString *> *)pathes withControlId:(UInt32)controlId toIRFile:(nonnull NSString *)outputPath;
+ (nonnull DDIRChangeReplaceRecord *)mergeIRModules:(nonnull NSArray<DDIRModulePath *> *)moudules withControlId:(UInt32)controlId toIRFile:(nonnull NSString *)outputPath;
// change
- (nonnull DDIRChangeDeclareRecord *)extractObjcDataAndFunctionDeclaration;
- (void)remeveObjcData;
- (void)mergeObjcData;
- (void)synchronzieChangees:(nonnull NSArray<DDIRChangeItem *> *)items;
@end

NS_ASSUME_NONNULL_END
