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

@interface DDIRUtil : NSObject
// check
bool isNullValue(llvm::GlobalVariable * _Nonnull var, int index);
llvm::GlobalVariable *getValue(llvm::GlobalVariable * _Nonnull var, int index);
// get
+ (llvm::GlobalVariable * _Nonnull)getLlvmCompilerUsedInModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable * _Nonnull)getLlvmUsedInModule:(llvm::Module * _Nonnull)module;
+ (llvm::StructType * _Nullable)getStructType:(const char * _Nonnull)name inModule:(llvm::Module * _Nonnull)module;
// create
+ (llvm::GlobalVariable * _Nonnull)createGlobalVariableName:(const char * _Nonnull)name
                                         fromGlobalVariable:(llvm::GlobalVariable * _Nonnull)other
                                                       type:(llvm::Type * _Nullable)type
                                                initializer:(llvm::Constant * _Nullable)initializer
                                                   inModule:(llvm::Module * _Nonnull)module;

// remove
+ (void)removeGlobalValue:(llvm::GlobalValue * _Nonnull)var inModule:(llvm::Module * _Nonnull)module;
// modify
+ (void)replaceGlobalVariable:(llvm::GlobalVariable * _Nonnull)var1
                         with:(llvm::GlobalVariable * _Nonnull)var2;
+ (nonnull NSString *)changeGlobalValueName:(llvm::GlobalValue * _Nonnull)variable
                                       from:(nonnull NSString *)oldName
                                         to:(nonnull NSString *)newName;
+ (void)changeStringValue:(llvm::ConstantStruct * _Nonnull)target
                atOperand:(NSUInteger)index
                       to:(nonnull NSString *)newValue
                 inModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable * _Nonnull)insertValue:(llvm::Constant * _Nonnull)value toGlobalArray:(llvm::GlobalVariable * _Nonnull)variable at:(NSUInteger)index inModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable *_Nonnull)removeValue:(llvm::Constant *_Nonnull)var fromGlobalArray:(llvm::GlobalVariable *_Nonnull)variable inModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable *_Nonnull)removeValueAtIndex:(NSUInteger)index fromGlobalArray:(llvm::GlobalVariable *_Nonnull)variable  inModule:(llvm::Module * _Nonnull)module;
// atributes
+ (nonnull NSString *)stringFromGlobalVariable:(llvm::GlobalVariable * _Nonnull)var;
@end

NS_ASSUME_NONNULL_END
