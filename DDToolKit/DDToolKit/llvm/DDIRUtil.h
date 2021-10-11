//
//  DDIRUtil.h
//  DDToolKit
//
//  Created by dondong on 2021/9/15.
//

#import <Foundation/Foundation.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/Constants.h>

NS_ASSUME_NONNULL_BEGIN
extern const char *IR_Ojbc_ClassTypeName;
extern const char *IR_Ojbc_CacheTypeName;
extern const char *IR_Ojbc_RoTypeName;
extern const char *IR_Ojbc_MethodListTypeName;
extern const char *IR_Ojbc_MethodTypeName;
extern const char *IR_Ojbc_ProtocolListTypeName;
extern const char *IR_Ojbc_ProtocolTypeName;
extern const char *IR_Ojbc_IvarListTypeName;
extern const char *IR_Ojbc_IvarTypeName;
extern const char *IR_Ojbc_PropListTypeName;
extern const char *IR_Ojbc_PropTypeName;
extern const char *IR_Ojbc_CategoryTypeName;



@interface DDIRUtil : NSObject
+ (nonnull NSDictionary<NSString *, NSValue *> *)getObjcClassTypeInModule:(llvm::Module * _Nonnull)module;
+ (nonnull NSDictionary<NSString *, NSValue *> *)getObjcCategoryTypeInModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable * _Nullable)getObjcClass:(nonnull NSString *)className
                                        inModule:(llvm::Module * _Nonnull)module;
+ (llvm:: GlobalVariable * _Nullable)getCategory:(nonnull NSString *)categoryName
                                    forObjcClass:(nonnull NSString *)className
                                        inModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable * _Nonnull)getLlvmCompilerUsedInModule:(llvm::Module * _Nonnull)module;
+ (llvm::StructType * _Nullable)getStructType:(const char *)name inModule:(llvm::Module * _Nonnull)module;
+ (nonnull NSString *)changeGlobalValueName:(llvm::GlobalValue * _Nonnull)variable
                                       from:(nonnull NSString *)oldName
                                         to:(nonnull NSString *)newName;
+ (void)changeStringValue:(llvm::ConstantStruct * _Nonnull)target
                atOperand:(NSUInteger)index
                       to:(nonnull NSString *)newValue
                 inModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable * _Nonnull)insertValue:(llvm::Constant * _Nonnull)value toConstantArray:(llvm::GlobalVariable * _Nonnull)variable at:(NSUInteger)index inModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable *_Nonnull)removeValueFromConstantArray:(llvm::GlobalVariable *_Nonnull)variable constant:(llvm::Constant *_Nonnull)constant inModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable *_Nonnull)removeValueFromConstantArray:(llvm::GlobalVariable *_Nonnull)variable at:(NSUInteger)index inModule:(llvm::Module * _Nonnull)module;
+ (nonnull NSString *)stringFromArray:(llvm::ConstantDataArray * _Nonnull)array;
+ (nonnull NSString *)classNameFromGlobalVariable:(llvm::GlobalVariable * _Nonnull)cls;
@end

NS_ASSUME_NONNULL_END
