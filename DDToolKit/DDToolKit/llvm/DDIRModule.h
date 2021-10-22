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

@interface DDIRModuleData : NSObject
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRStringVariable *> *stringList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRObjCClass *> *objcClassList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRObjCCategory *> *objcCategoryList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRFunction *> *functionList;
@end

@interface DDIRModule : NSObject
@property(nonatomic,strong,readonly,nonnull) NSString *path;
+ (nullable instancetype)moduleFromLLPath:(nonnull NSString *)path;
+ (void)linkLLFiles:(nonnull NSArray<NSString *> *)pathes toLLFile:(nonnull NSString *)outputPath;
- (nullable DDIRModuleData *)getData;

- (void)executeChangesWithBlock:(void (^_Nullable)(DDIRModule * _Nullable module))block;
- (void)executeChangesWithSavePath:(nonnull NSString *)savePath block:(void (^_Nullable)(DDIRModule * _Nullable module))block;
// change
- (void)addControlVariable:(nonnull NSString *)name section:(nonnull NSString *)section;
- (void)addEmptyClass:(nonnull NSString *)className;
- (void)addEmptyCategory:(nonnull NSString *)categoryName toClass:(nonnull NSString *)className;
- (BOOL)replaceObjcClass:(nonnull NSString *)className withNewComponentName:(nonnull NSString *)newName;
- (BOOL)moveClass:(nonnull NSString *)className to:(nonnull NSString *)section;
- (BOOL)replaceCategory:(nonnull NSString *)categoryName forObjcClass:(nonnull NSString *)className withNewComponentName:(nonnull NSString *)newName;
- (BOOL)moveCategory:(nonnull NSString *)categoryName forObjcClass:(nonnull NSString *)className to:(nonnull NSString *)section;
@end

NS_ASSUME_NONNULL_END
