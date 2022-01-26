//
//  DDIRUtil_Objc.hpp
//  DDToolKit
//
//  Created by dondong on 2022/1/26.
//

#ifndef DDIRUtil_Objc_hpp
#define DDIRUtil_Objc_hpp

#include <llvm/IR/Module.h>
#include <llvm/IR/Constants.h>

extern const char * _Nullable IR_Objc_ClassTypeName;
extern const char * _Nullable IR_Objc_CacheTypeName;
extern const char * _Nullable IR_Objc_RoTypeName;
extern const char * _Nullable IR_Objc_MethodListTypeName;
extern const char * _Nullable IR_Objc_MethodTypeName;
extern const char * _Nullable IR_Objc_ProtocolListTypeName;
extern const char * _Nullable IR_Objc_ProtocolTypeName;
extern const char * _Nullable IR_Objc_IvarListTypeName;
extern const char * _Nullable IR_Objc_IvarTypeName;
extern const char * _Nullable IR_Objc_PropListTypeName;
extern const char * _Nullable IR_Objc_PropTypeName;
extern const char * _Nullable IR_Objc_CategoryTypeName;

llvm::GlobalVariable * _Nonnull createObjcClass(llvm::Module * _Nonnull module,
                                                const char * _Nonnull className,
                                                llvm::GlobalVariable * _Nonnull superCls,
                                                llvm::GlobalVariable * _Nonnull metaSuperCls,
                                                uint32_t flags,
                                                uint32_t classFlags,
                                                uint32_t instanceStart,
                                                uint32_t instanceSize,
                                                std::vector<llvm::Constant *> methods,
                                                std::vector<llvm::Constant *> classMethods,
                                                std::vector<llvm::Constant *> ivars,
                                                std::vector<llvm::Constant *> protocols,
                                                std::vector<llvm::Constant *> props,
                                                std::vector<llvm::Constant *> classProps);
llvm::GlobalVariable * _Nonnull createObjcCategory(llvm::Module * _Nonnull module,
                                                   const char * _Nonnull categoryName,
                                                   llvm::GlobalVariable * _Nonnull cls,
                                                   std::vector<llvm::Constant *> methods,
                                                   std::vector<llvm::Constant *> classMethods,
                                                   std::vector<llvm::Constant *> protocols,
                                                   std::vector<llvm::Constant *> props,
                                                   std::vector<llvm::Constant *> classProps,
                                                   int index = 0);
llvm::GlobalVariable * _Nonnull createObjcProtocol(llvm::Module * _Nonnull module,
                                                   const char * _Nonnull protocolName,
                                                   uint32_t flags,
                                                   std::vector<llvm::Constant *> protocols,
                                                   std::vector<llvm::Constant *> methods,
                                                   std::vector<llvm::Constant *> classMethods,
                                                   std::vector<llvm::Constant *> optionalMethods,
                                                   std::vector<llvm::Constant *> optionalClassMethods,
                                                   std::vector<llvm::Constant *> props,
                                                   std::vector<llvm::Constant *> classProps);
llvm::GlobalVariable * _Nonnull createMethodList(llvm::Module * _Nonnull module, std::vector<llvm::Constant *> list);
llvm::GlobalVariable * _Nonnull createProtocolList(llvm::Module * _Nonnull module, std::vector<llvm::Constant *> list);
llvm::GlobalVariable * _Nonnull createPropList(llvm::Module * _Nonnull module, std::vector<llvm::Constant *> list);
llvm::GlobalVariable * _Nonnull createIvarList(llvm::Module * _Nonnull module, std::vector<llvm::Constant *> list);
llvm::GlobalVariable * _Nonnull createObjcMethodName(llvm::Module * _Nonnull module, const char * _Nonnull name);
llvm::GlobalVariable * _Nonnull createObjcVarType(llvm::Module * _Nonnull module, const char * _Nonnull name);
llvm::GlobalVariable * _Nonnull createObjcClassName(llvm::Module * _Nonnull module, const char * _Nonnull name);

// get or create
llvm::GlobalVariable * _Nonnull getAndCreateClassReference(llvm::GlobalVariable * _Nonnull cls);
llvm::GlobalVariable * _Nonnull getAndCreateSelectorReference(const char * _Nonnull selector, llvm::GlobalVariable * _Nonnull cls);

// get
const char * _Nonnull getObjcClassName(llvm::GlobalVariable * _Nonnull cls);
const char * _Nonnull getObjcCategoryName(llvm::GlobalVariable * _Nonnull cat);
const char * _Nonnull getObjcClassNameFromCategory(llvm::GlobalVariable * _Nonnull cat);
const char * _Nonnull getObjcProcotolName(llvm::GlobalVariable * _Nonnull pro);
std::map<const char *, void *> getObjcClassType(llvm::Module * _Nonnull module);
std::map<const char *, void *> getObjcCategoryType(llvm::Module * _Nonnull module);
llvm::GlobalVariable * _Nullable getObjcClass(llvm::Module * _Nonnull module, const char * _Nonnull className);
llvm::GlobalVariable * _Nullable getCategory(llvm::Module * _Nonnull module, const char * _Nonnull categoryName, const char * _Nonnull className);
llvm::GlobalVariable * _Nullable getObjcProtocolLabel(llvm::Module * _Nonnull module, const char * _Nonnull protocolName);

#endif /* DDIRUtil_Objc_hpp */
