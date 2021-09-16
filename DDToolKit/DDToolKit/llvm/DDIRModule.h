//
//  DDIRModule.h
//  DDToolKit
//
//  Created by dondong on 2021/8/30.
//

#import <Foundation/Foundation.h>
#import "DDIRStringVariable.h"
#import "DDIRObjCClass.h"
#import "DDIRFunction.h"

NS_ASSUME_NONNULL_BEGIN

@interface DDIRModule : NSObject
@property(nonatomic,strong,readonly,nonnull) NSString *path;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRStringVariable *> *stringList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRObjCClass *> *objcClassList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRObjCCategory *> *objcCategoryList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRFunction *> *functionList;
+ (nullable instancetype)moduleFromLLPath:(nonnull NSString *)path;
// change
- (void)changeClassNameFrom:(nonnull NSString *)oldClassName to:(nonnull NSString *)newClassName;
- (void)addEmptyClass:(nonnull NSString *)className;
- (void)addEmptyCategory:(nonnull NSString *)categoryName toClass:(nonnull NSString *)className;
- (void)moveClass:(nonnull NSString *)className to:(nonnull NSString *)section;
- (void)executeChangesWithBlock:(void (^_Nullable)(DDIRModule * _Nullable module))block;
- (void)executeChangesWithSavePath:(nonnull NSString *)savePath block:(void (^_Nullable)(DDIRModule * _Nullable module))block;
@end

NS_ASSUME_NONNULL_END
