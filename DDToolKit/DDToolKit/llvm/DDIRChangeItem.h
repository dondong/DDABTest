//
//  DDIRChangeItem.h
//  DDToolKit
//
//  Created by dondong on 2021/12/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

static const NSInteger DDIRChangeTypeGlobalVariable = 0;
static const NSInteger DDIRChangeTypeFunction       = 1;

@interface DDIRChangeItem : NSObject
@property(nonatomic,assign) NSInteger type;
@property(nonatomic,strong,nonnull) NSString *targetName;
+ (nonnull instancetype)globalVariableItemWithTargetName:(nonnull NSString *)targetName;
+ (nonnull instancetype)functionItemWithTargetName:(nonnull NSString *)targetName;
@end

@interface DDIRRemoveChangeItem : DDIRChangeItem
@end

@interface DDIRNameChangeItem : DDIRChangeItem
@property(nonatomic,strong) NSString *name;
+ (nonnull instancetype)globalVariableItemWithTargetName:(nonnull NSString *)targetName newName:(nonnull NSString *)newName;
+ (nonnull instancetype)functionItemWithTargetName:(nonnull NSString *)targetName newName:(nonnull NSString *)newName;
@end

@interface DDIRLinkageChangeItem : DDIRChangeItem
@property(nonatomic,assign) NSInteger newLinkage;
@end

@interface DDIRRemoveDefineChangeItem : DDIRChangeItem
@end

@interface DDIRStaticVariableChangeItem : DDIRChangeItem
@property(nonatomic,strong) NSString *valueName;
+ (nonnull instancetype)globalVariableItemWithTargetName:(nonnull NSString *)targetName valueName:(nonnull NSString *)valueName;
@end

@interface DDIRChangeItemSet : DDIRChangeItem
@property(nonatomic,strong,nonnull) NSArray<DDIRChangeItem *> *items;
+ (nonnull instancetype)itemSetWithItems:(nonnull NSArray<DDIRChangeItem *> *)items;
@end

NS_ASSUME_NONNULL_END
