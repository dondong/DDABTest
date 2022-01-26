//
//  DDIRUtil.hpp
//  DDToolKit
//
//  Created by dondong on 2022/1/26.
//

#ifndef DDIRUtil_hpp
#define DDIRUtil_hpp

#include <llvm/IR/Module.h>
#include <llvm/IR/Constants.h>

// check
bool isNullValue(llvm::GlobalVariable * _Nonnull var, int index);
llvm::GlobalVariable * _Nullable getValue(llvm::GlobalVariable * _Nonnull var, int index);

// get
llvm::GlobalVariable * _Nonnull getLlvmCompilerUsed(llvm::Module * _Nonnull module);
llvm::GlobalVariable * _Nonnull getLlvmUsed(llvm::Module * _Nonnull module);
llvm::GlobalVariable * _Nullable getGlabalArray(llvm::Module * _Nonnull module, const char * _Nonnull sectionName);
llvm::StructType * _Nullable getStructType(llvm::Module * _Nonnull module, const char * _Nonnull name);
bool isExternalStaticVariable(llvm::GlobalVariable * _Nonnull var);
bool isExternalStaticVariableDeclaration(llvm::GlobalVariable * _Nonnull var);
bool isOnlyUsedByLLVM(llvm::GlobalValue * _Nonnull var);

// create
llvm::GlobalVariable * _Nonnull createGlobalVariable(llvm::GlobalVariable * _Nonnull copyVariable,
                                                     const char * _Nonnull name,
                                                     llvm::Type * _Nullable type = nullptr,
                                                     llvm::Constant * _Nullable initializer = nullptr);

// remove
void removeGlobalValue(llvm::GlobalValue * _Nonnull var, bool ignoreFunction = false);

// modify
void replaceGlobalVariable(llvm::GlobalVariable * _Nonnull oldVar, llvm::GlobalVariable * _Nonnull newVar);
void replaceFuction(llvm::Function * _Nonnull oldFun, llvm::Function * _Nonnull newFun);
//std::string changeGlobalValueName(llvm::GlobalValue * _Nonnull variable, const char * _Nonnull oldName, const char * _Nonnull newName);
void changeStringValue(llvm::Module * _Nonnull module, llvm::ConstantStruct * _Nonnull var, int index, const char * _Nonnull newString);
llvm::GlobalVariable * _Nonnull insertValue(llvm::Constant * _Nonnull value, llvm::GlobalVariable * _Nonnull array, int index = 0);
llvm::GlobalVariable * _Nonnull insertValue(llvm::Module * _Nonnull module, llvm::Constant * _Nonnull value, const char * _Nonnull arraySectionName, const char * _Nonnull defaultName, int index = 0);
llvm::GlobalVariable * _Nonnull removeValue(llvm::Constant * _Nonnull value, llvm::GlobalVariable * _Nonnull array);
llvm::GlobalVariable * _Nonnull removeValue(llvm::GlobalVariable * _Nonnull array, int index);

// atributes
const char * _Nonnull stringFromGlobalVariable(llvm::GlobalVariable * _Nonnull var);
#endif /* DDIRUtil_hpp */
