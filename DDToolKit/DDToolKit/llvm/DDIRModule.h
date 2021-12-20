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
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRGlobalVariable *> *staticVariableList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRGlobalVariable *> *externalStaticVariableList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRObjCClass *> *objcClassList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRObjCCategory *> *objcCategoryList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRObjCProtocol *> *objcProtocolList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRFunction *> *ctorFunctionList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRFunction *> *functionList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRFunction *> *hiddenFunctionList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRFunction *> *externalFunctionList;
@end

@interface DDIRModulePath : NSObject
@property(nonatomic,strong) NSString *path;
@end

static NSString * const DDIRReplaceResultGlobalVariableKey = @"DDIRReplaceResultGlobalVariableKey";
static NSString * const DDIRReplaceResultFunctionKey       = @"DDIRReplaceResultFunctionKey";
@interface DDIRModule : NSObject
@property(nonatomic,strong,readonly,nonnull) NSString *path;
+ (nullable instancetype)moduleFromPath:(nonnull NSString *)path;
+ (nullable instancetype)moduleFromBCPath:(nonnull NSString *)path;
+ (nullable instancetype)moduleFromLLPath:(nonnull NSString *)path;
+ (nullable instancetype)moduleFromModulePath:(nonnull DDIRModulePath *)path;
+ (void)linkIRFiles:(nonnull NSArray<NSString *> *)pathes toIRFile:(nonnull NSString *)outputPath;
- (nullable DDIRModuleData *)getData;

- (void)executeChangesWithBlock:(void (^_Nullable)(DDIRModule * _Nullable module))block;
- (void)executeChangesWithSavePath:(nonnull NSString *)savePath block:(void (^_Nullable)(DDIRModule * _Nullable module))block;
/*
 change
 */
typedef NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> DDIRReplaceResult;
// function
- (BOOL)replaceFunction:(nonnull NSString *)funName withNewComponentName:(nonnull NSString *)newName;
// class
- (void)addEmptyClass:(nonnull NSString *)className;
- (nullable DDIRReplaceResult *)replaceObjcClass:(nonnull NSString *)className withNewComponentName:(nonnull NSString *)newName;
- (BOOL)moveClass:(nonnull NSString *)className to:(nonnull NSString *)section;
// category
- (void)addEmptyCategory:(nonnull NSString *)categoryName toClass:(nonnull NSString *)className;
- (nullable DDIRReplaceResult *)replaceCategory:(nonnull NSString *)categoryName forObjcClass:(nonnull NSString *)className withNewComponentName:(nonnull NSString *)newName;
- (BOOL)moveCategory:(nonnull NSString *)categoryName forObjcClass:(nonnull NSString *)className to:(nonnull NSString *)section;
// protocol
- (BOOL)replaceObjcProtocol:(nonnull NSString *)protocolName withNewComponentName:(nonnull NSString *)newName;
@end

NS_ASSUME_NONNULL_END
