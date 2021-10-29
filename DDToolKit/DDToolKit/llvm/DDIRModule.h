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
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRObjCProtocol *> *objcProtocolList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRFunction *> *functionList;
@end

@interface DDIRModule : NSObject
@property(nonatomic,strong,readonly,nonnull) NSString *path;
+ (nullable instancetype)moduleFromLLPath:(nonnull NSString *)path;
+ (void)linkLLFiles:(nonnull NSArray<NSString *> *)pathes toLLFile:(nonnull NSString *)outputPath;
- (nullable DDIRModuleData *)getData;

- (void)executeChangesWithBlock:(void (^_Nullable)(DDIRModule * _Nullable module))block;
- (void)executeChangesWithSavePath:(nonnull NSString *)savePath block:(void (^_Nullable)(DDIRModule * _Nullable module))block;
/*
 change
 */
// class
- (void)addEmptyClass:(nonnull NSString *)className;
- (BOOL)replaceObjcClass:(nonnull NSString *)className withNewComponentName:(nonnull NSString *)newName;
- (BOOL)moveClass:(nonnull NSString *)className to:(nonnull NSString *)section;
// category
- (void)addEmptyCategory:(nonnull NSString *)categoryName toClass:(nonnull NSString *)className;
- (BOOL)replaceCategory:(nonnull NSString *)categoryName forObjcClass:(nonnull NSString *)className withNewComponentName:(nonnull NSString *)newName;
- (BOOL)moveCategory:(nonnull NSString *)categoryName forObjcClass:(nonnull NSString *)className to:(nonnull NSString *)section;
// protocol
- (BOOL)replaceObjcProtocol:(nonnull NSString *)protocolName withNewComponentName:(nonnull NSString *)newName;
@end

NS_ASSUME_NONNULL_END
