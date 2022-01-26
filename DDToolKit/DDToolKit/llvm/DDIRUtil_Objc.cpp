//
//  DDIRUtil_Objc.cpp
//  DDToolKit
//
//  Created by dondong on 2022/1/26.
//

#include "DDIRUtil_Objc.hpp"
#include "DDIRUtil.hpp"
#include <llvm/IR/Module.h>
using namespace llvm;

const char *IR_Objc_ClassTypeName        = "struct._class_t";
const char *IR_Objc_CacheTypeName        = "struct._objc_cache";
const char *IR_Objc_RoTypeName           = "struct._class_ro_t";
const char *IR_Objc_MethodListTypeName   = "struct.__method_list_t";
const char *IR_Objc_MethodTypeName       = "struct._objc_method";
const char *IR_Objc_ProtocolListTypeName = "struct._objc_protocol_list";
const char *IR_Objc_ProtocolTypeName     = "struct._protocol_t";
const char *IR_Objc_IvarListTypeName     = "struct._ivar_list_t";
const char *IR_Objc_IvarTypeName         = "struct._ivar_t";
const char *IR_Objc_PropListTypeName     = "struct._prop_list_t";
const char *IR_Objc_PropTypeName         = "struct._prop_t";
const char *IR_Objc_CategoryTypeName     = "struct._category_t";

#pragma mark create
llvm::GlobalVariable * _Nonnull _createObjcClass(llvm::Module * _Nonnull module,
                                                 const char * _Nonnull className,
                                                 llvm::GlobalVariable * _Nonnull name,
                                                 llvm::GlobalVariable * _Nonnull isa,
                                                 llvm::GlobalVariable * _Nonnull superClass,
                                                 llvm::GlobalVariable * _Nonnull cache,
                                                 uint32_t flags,
                                                 uint32_t instanceStart,
                                                 uint32_t instanceSize,
                                                 std::vector<llvm::Constant *> methods,
                                                 std::vector<llvm::Constant *> ivars,
                                                 std::vector<llvm::Constant *> protocols,
                                                 std::vector<llvm::Constant *> props,
                                                 bool meta)
{
    std::map<const char *, void *> map = getObjcClassType(module);
    StructType *classType        = (StructType *)map[IR_Objc_ClassTypeName];
    StructType *roType           = (StructType *)map[IR_Objc_RoTypeName];
    StructType *methodListType   = (StructType *)map[IR_Objc_MethodListTypeName];
    StructType *protocolListType = (StructType *)map[IR_Objc_ProtocolListTypeName];
    StructType *ivarListType     = (StructType *)map[IR_Objc_IvarListTypeName];
    StructType *propListType     = (StructType *)map[IR_Objc_PropListTypeName];
    assert(nullptr != classType && nullptr != roType && nullptr != methodListType && nullptr != protocolListType && nullptr != ivarListType && nullptr != propListType);
    Constant *zero = ConstantInt::get(Type::getInt32Ty(module->getContext()), 0);

    std::vector<Constant *> roList;
    roList.push_back(ConstantInt::get(Type::getInt32Ty(module->getContext()), flags));
    roList.push_back(ConstantInt::get(Type::getInt32Ty(module->getContext()), instanceStart));
    roList.push_back(ConstantInt::get(Type::getInt32Ty(module->getContext()), instanceSize));
    roList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(module->getContext())));
    roList.push_back(ConstantExpr::getInBoundsGetElementPtr(name->getInitializer()->getType(), name, (Constant *[]){zero, zero}));
    if (methods.size() > 0) {
        GlobalVariable *p = createMethodList(module, methods);
        if (meta) {
            p->setName(std::string("_OBJC_$_CLASS_METHODS_") + className);
        } else {
            p->setName(std::string("_OBJC_$_INSTANCE_METHODS_") + className);
        }
        roList.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        roList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    if (protocols.size() > 0) {
        GlobalVariable *p = createProtocolList(module, protocols);
        if (meta) {
            p->setName(std::string("_OBJC_METACLASS_PROTOCOLS_$_") + className);
        } else {
            p->setName(std::string("_OBJC_CLASS_PROTOCOLS_$_") + className);
        }
        roList.push_back(ConstantExpr::getBitCast(p, protocolListType->getPointerTo()));
    } else {
        roList.push_back(ConstantPointerNull::get(PointerType::getUnqual(protocolListType)));
    }
    if (ivars.size() > 0) {
        GlobalVariable *p = createIvarList(module, ivars);
        if (meta) {
            p->setName(std::string("_OBJC_$_CLASS_VARIABLES_") + className);
        } else {
            p->setName(std::string("_OBJC_$_INSTANCE_VARIABLES_") + className);
        }
        roList.push_back(ConstantExpr::getBitCast(p, ivarListType->getPointerTo()));
    } else {
        roList.push_back(ConstantPointerNull::get(PointerType::getUnqual(ivarListType)));
    }
    roList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(module->getContext())));
    if (props.size() > 0) {
        GlobalVariable *p = createPropList(module, props);
        if (meta) {
            p->setName(std::string("_OBJC_$_CLASS_PROP_LIST_") + className);
        } else {
            p->setName(std::string("_OBJC_$_PROP_LIST_") + className);
        }
        roList.push_back(ConstantExpr::getBitCast(p, propListType->getPointerTo()));
    } else {
        roList.push_back(ConstantPointerNull::get(PointerType::getUnqual(propListType)));
    }
    GlobalVariable *ro = new GlobalVariable(*module,
                                            roType,
                                            false,
                                            GlobalValue::InternalLinkage,
                                            ConstantStruct::get(roType, roList),
                                            (meta ? std::string("_OBJC_METACLASS_RO_$_") + className:
                                             std::string("_OBJC_CLASS_RO_$_") + className));
    ro->setSection("__DATA, __objc_const");
    ro->setAlignment(MaybeAlign(8));
    
    std::vector<Constant *> clsList;
    clsList.push_back(isa);  // isa
    clsList.push_back(superClass);  // super
    clsList.push_back(cache);
    clsList.push_back(ConstantPointerNull::get(PointerType::getUnqual(PointerType::getUnqual(FunctionType::get(Type::getInt8PtrTy(module->getContext()),
                                                                                                               {Type::getInt8PtrTy(module->getContext()), Type::getInt8PtrTy(module->getContext())},
                                                                                                               false)))));
    clsList.push_back(ro);
    GlobalVariable *cls =  new GlobalVariable(*module,
                                              classType,
                                              false,
                                              GlobalValue::ExternalLinkage,
                                              ConstantStruct::get(classType, clsList),
                                              (meta ? std::string("OBJC_METACLASS_$_") + className :
                                               std::string("OBJC_CLASS_$_") + className));
    cls->setSection("__DATA, __objc_data");
    cls->setAlignment(MaybeAlign(8));
    return cls;
}

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
                                                std::vector<llvm::Constant *> classProps)
{
    getObjcClassType(module);
    GlobalVariable *name = createObjcClassName(module, className);
    GlobalVariable *cache = module->getNamedGlobal("_objc_empty_cache");
    if (nullptr == cache) {
        cache = new GlobalVariable(*module,
                                   getStructType(module, IR_Objc_CacheTypeName),
                                   false,
                                   GlobalValue::ExternalLinkage,
                                   nullptr,
                                   "_objc_empty_cache");
    }
    GlobalVariable *nsobject = module->getNamedGlobal("OBJC_METACLASS_$_NSObject");
    if (nullptr == nsobject) {
        nsobject = new GlobalVariable(*module,
                                      getStructType(module, IR_Objc_ClassTypeName),
                                      false,
                                      GlobalValue::ExternalLinkage,
                                      nullptr,
                                      "OBJC_METACLASS_$_NSObject");
    }
    
    // meta class
    std::vector<llvm::Constant *> classIvars;
    std::vector<llvm::Constant *> classProtocols;
    GlobalVariable *metaCls = _createObjcClass(module,
                                               className,
                                               name,
                                               nsobject,
                                               metaSuperCls,
                                               cache,
                                               classFlags,
                                               40,
                                               40,
                                               classMethods,
                                               classIvars,
                                               classProtocols,
                                               classProps,
                                               true);
    // class
    GlobalVariable *cls = _createObjcClass(module,
                                           className,
                                           name,
                                           metaCls,
                                           superCls,
                                           cache,
                                           flags,
                                           instanceStart,
                                           instanceSize,
                                           methods,
                                           ivars,
                                           protocols,
                                           props,
                                           false);
    // array
    insertValue(ConstantExpr::getBitCast(cast<Constant>(cls), Type::getInt8PtrTy(module->getContext())),
                getLlvmCompilerUsed(module));
    insertValue(module,
                ConstantExpr::getBitCast(cast<Constant>(cls), Type::getInt8PtrTy(module->getContext())),
                "__DATA,__objc_classlist",
                "OBJC_LABEL_CLASS_$");
    return cls;
}

llvm::GlobalVariable * _Nonnull createObjcCategory(llvm::Module * _Nonnull module,
                                                   const char * _Nonnull categoryName,
                                                   llvm::GlobalVariable * _Nonnull cls,
                                                   std::vector<llvm::Constant *> methods,
                                                   std::vector<llvm::Constant *> classMethods,
                                                   std::vector<llvm::Constant *> protocols,
                                                   std::vector<llvm::Constant *> props,
                                                   std::vector<llvm::Constant *> classProps,
                                                   int index)
{
    std::map<const char *, void *> map = getObjcCategoryType(module);
    std::vector<Constant *> datas;
    Constant *zero = ConstantInt::get(Type::getInt32Ty(module->getContext()), 0);
    GlobalVariable *cName = createObjcClassName(module, categoryName);
    datas.push_back(ConstantExpr::getInBoundsGetElementPtr(cName->getInitializer()->getType(), cName, (Constant *[]){zero, zero}));
    datas.push_back(cls);
    StructType *categoryType     = (StructType *)map[IR_Objc_CategoryTypeName];
    StructType *methodListType   = (StructType *)map[IR_Objc_MethodListTypeName];
    StructType *protocolListType = (StructType *)map[IR_Objc_ProtocolListTypeName];
    StructType *propListType     = (StructType *)map[IR_Objc_PropListTypeName];
    std::string n = getObjcClassName(cls);
    if (methods.size() > 0) {
        GlobalVariable *p = createMethodList(module, methods);
        p->setName(std::string("_OBJC_$_CATEGORY_INSTANCE_METHODS_") + n + "_$_" + categoryName);
        datas.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        datas.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    if (classMethods.size() > 0) {
        GlobalVariable *p = createMethodList(module, classMethods);
        p->setName(std::string("_OBJC_$_CATEGORY_CLASS_METHODS_") + n + "_$_" + categoryName);
        datas.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        datas.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    if (protocols.size()) {
        GlobalVariable *p = createProtocolList(module, protocols);
        p->setName(std::string("_OBJC_CATEGORY_PROTOCOLS_$_") + n + "_$_" + categoryName);
        datas.push_back(ConstantExpr::getBitCast(p, protocolListType->getPointerTo()));
    } else {
        datas.push_back(ConstantPointerNull::get(PointerType::getUnqual(protocolListType)));
    }
    if (props.size() > 0) {
        GlobalVariable *p = createPropList(module, props);
        p->setName(std::string("_OBJC_$_PROP_LIST_") + n + "_$_" + categoryName);
        datas.push_back(ConstantExpr::getBitCast(p, propListType->getPointerTo()));
    } else {
        datas.push_back(ConstantPointerNull::get(PointerType::getUnqual(propListType)));
    }
    if (classProps.size() > 0) {
        GlobalVariable *p = createPropList(module, classProps);
        p->setName(std::string("_OBJC_$_PROP_LIST_CLASS_") + n + "_$_" + categoryName);
        datas.push_back(ConstantExpr::getBitCast(p, propListType->getPointerTo()));
    } else {
        datas.push_back(ConstantPointerNull::get(PointerType::getUnqual(propListType)));
    }
    datas.push_back(Constant::getIntegerValue(Type::getInt32Ty(module->getContext()), APInt(32, 64, false)));
    GlobalVariable *ret = new GlobalVariable(*module,
                                             categoryType,
                                             false,
                                             GlobalValue::InternalLinkage,
                                             ConstantStruct::get(categoryType, datas),
                                             std::string("_OBJC_$_CATEGORY_") + n + "_$_" + categoryName);
    ret->setAlignment(MaybeAlign(8));
    ret->setSection("__DATA, __objc_const");
    insertValue(ConstantExpr::getBitCast(cast<Constant>(ret), Type::getInt8PtrTy(module->getContext())),
                getLlvmCompilerUsed(module));
    insertValue(module,
                ConstantExpr::getBitCast(cast<Constant>(ret), Type::getInt8PtrTy(module->getContext())),
                "__DATA,__objc_catlist",
                "OBJC_LABEL_CATEGORY_$");
    return ret;
}
                   
llvm::GlobalVariable * _Nonnull createObjcProtocol(llvm::Module * _Nonnull module,
                                                   const char * _Nonnull protocolName,
                                                   uint32_t flags,
                                                   std::vector<llvm::Constant *> protocols,
                                                   std::vector<llvm::Constant *> methods,
                                                   std::vector<llvm::Constant *> classMethods,
                                                   std::vector<llvm::Constant *> optionalMethods,
                                                   std::vector<llvm::Constant *> optionalClassMethods,
                                                   std::vector<llvm::Constant *> props,
                                                   std::vector<llvm::Constant *> classProps)
{
    std::map<const char *, void *> map = getObjcClassType(module);
    StructType *protocolType     = (StructType *)map[IR_Objc_ProtocolTypeName];
    StructType *methodListType   = (StructType *)map[IR_Objc_MethodListTypeName];
    StructType *protocolListType = (StructType *)map[IR_Objc_ProtocolListTypeName];
    StructType *propListType     = (StructType *)map[IR_Objc_PropListTypeName];
    assert(nullptr != methodListType && nullptr != protocolListType && nullptr != propListType);
    Constant *zero = ConstantInt::get(Type::getInt32Ty(module->getContext()), 0);

    std::vector<Constant *> proList;
    proList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(module->getContext())));
    // mangledName
    GlobalVariable *name = createObjcClassName(module, protocolName);
    proList.push_back(ConstantExpr::getInBoundsGetElementPtr(name->getInitializer()->getType(), name, (Constant *[]){zero, zero}));
    // protocols
    if (protocols.size() > 0) {
        GlobalVariable *p = createProtocolList(module, protocols);
        p->setName(std::string("_OBJC_$_PROTOCOL_REFS_") + protocolName);
        proList.push_back(ConstantExpr::getBitCast(p, protocolListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(protocolListType)));
    }
    // instanceMethods
    if (methods.size() > 0) {
        GlobalVariable *p = createMethodList(module, methods);
        p->setName(std::string("_OBJC_$_PROTOCOL_INSTANCE_METHODS_") + protocolName);
        proList.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    // classMethods
    if (classMethods.size() > 0) {
        GlobalVariable *p = createMethodList(module, classMethods);
        p->setName(std::string("_OBJC_$_PROTOCOL_CLASS_METHODS_") + protocolName);
        proList.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    // optionalInstanceMethods
    if (optionalMethods.size() > 0) {
        GlobalVariable *p = createMethodList(module, optionalMethods);
        p->setName(std::string("_OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_") + protocolName);
        proList.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    // optionalClassMethods
    if (optionalClassMethods.size() > 0) {
        GlobalVariable *p = createMethodList(module, optionalClassMethods);
        p->setName(std::string("_OBJC_$_PROTOCOL_CLASS_METHODS_OPT_") + protocolName);
        proList.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    // instanceProperties
    if (props.size() > 0) {
        GlobalVariable *p = createPropList(module, props);
        p->setName(std::string("_OBJC_$_PROP_LIST_") + protocolName);
        proList.push_back(ConstantExpr::getBitCast(p, propListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(propListType)));
    }
    // size sizeof(protocol_t)
    proList.push_back(ConstantInt::get(Type::getInt32Ty(module->getContext()), 96));
    // flags
    proList.push_back(ConstantInt::get(Type::getInt32Ty(module->getContext()), flags));
    // _extendedMethodTypes
    std::vector<Constant *> types;
    for (Constant *m : methods) {
        types.push_back(ConstantExpr::getBitCast(cast<Constant>(m->getOperand(1)), Type::getInt8PtrTy(module->getContext())));
    }
    for (Constant *m : classMethods) {
        types.push_back(ConstantExpr::getBitCast(cast<Constant>(m->getOperand(1)), Type::getInt8PtrTy(module->getContext())));
    }
    for (Constant *m : optionalMethods) {
        types.push_back(ConstantExpr::getBitCast(cast<Constant>(m->getOperand(1)), Type::getInt8PtrTy(module->getContext())));
    }
    for (Constant *m : optionalClassMethods) {
        types.push_back(ConstantExpr::getBitCast(cast<Constant>(m->getOperand(1)), Type::getInt8PtrTy(module->getContext())));
    }
    GlobalVariable *typeVar = new GlobalVariable(*module,
                                                  ArrayType::get(Type::getInt8PtrTy(module->getContext()), types.size()),
                                                  false,
                                                  GlobalValue::InternalLinkage,
                                                  ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(module->getContext()), types.size()), types),
                                                 std::string("_OBJC_$_PROTOCOL_METHOD_TYPES_") + protocolName);
    typeVar->setSection("__DATA, __objc_const");
    typeVar->setAlignment(MaybeAlign(8));
    insertValue(ConstantExpr::getBitCast(cast<Constant>(typeVar), Type::getInt8PtrTy(module->getContext())),
                getLlvmCompilerUsed(module));
    proList.push_back(ConstantExpr::getBitCast(typeVar, Type::getInt8PtrTy(module->getContext())->getPointerTo()));
    // _demangledName
    proList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(module->getContext())));
    // _classProperties
    if (classProps.size() > 0) {
        GlobalVariable *p = createPropList(module, classProps);
        p->setName(std::string("_OBJC_$_CLASS_PROP_LIST_") + protocolName);
        proList.push_back(ConstantExpr::getBitCast(p, propListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(propListType)));
    }
    GlobalVariable *pro = new GlobalVariable(*module,
                                             protocolType,
                                             false,
                                             GlobalValue::WeakAnyLinkage,
                                             ConstantStruct::get(protocolType, proList),
                                             std::string("_OBJC_PROTOCOL_$_") + protocolName);
    pro->setVisibility(GlobalValue::HiddenVisibility);
    pro->setAlignment(MaybeAlign(8));
    
    GlobalVariable *proLabel = new GlobalVariable(*module,
                                                  protocolType->getPointerTo(),
                                                  false,
                                                  GlobalValue::WeakAnyLinkage,
                                                  pro,
                                                  std::string("_OBJC_LABEL_PROTOCOL_$_") + protocolName);
    proLabel->setVisibility(GlobalValue::HiddenVisibility);
    proLabel->setSection("__DATA,__objc_protolist,coalesced,no_dead_strip");
    proLabel->setAlignment(MaybeAlign(8));
    insertValue(ConstantExpr::getBitCast(cast<Constant>(proLabel), Type::getInt8PtrTy(module->getContext())),
                getLlvmUsed(module));
    insertValue(ConstantExpr::getBitCast(cast<Constant>(pro), Type::getInt8PtrTy(module->getContext())),
                getLlvmUsed(module));
    
    return pro;
}

llvm::GlobalVariable * _Nonnull _createList(llvm::Module * _Nonnull module,
                                            std::vector<llvm::Constant *> list,
                                            llvm::Type * _Nonnull t,
                                            uint32_t elementSize)
{
    std::vector<Type *> types;
    types.push_back(Type::getInt32Ty(module->getContext()));
    types.push_back(Type::getInt32Ty(module->getContext()));
    types.push_back(ArrayType::get(t, list.size()));
    std::vector<Constant *> datas;
    datas.push_back(Constant::getIntegerValue(Type::getInt32Ty(module->getContext()), APInt(32, elementSize, false)));
    datas.push_back(Constant::getIntegerValue(Type::getInt32Ty(module->getContext()), APInt(32, list.size(), false)));
    datas.push_back(ConstantArray::get(ArrayType::get(t, list.size()), list));
    Constant *val = ConstantStruct::get(StructType::get(module->getContext(), types), datas);
    GlobalVariable *ret = new GlobalVariable(*module,
                                             val->getType(),
                                             false,
                                             GlobalValue::InternalLinkage,
                                             val);
    ret->setAlignment(MaybeAlign(8));
    ret->setSection("__DATA, __objc_const");
    insertValue(ConstantExpr::getBitCast(cast<Constant>(ret), Type::getInt8PtrTy(module->getContext())),
                getLlvmCompilerUsed(module));
    return ret;
}

llvm::GlobalVariable * _Nonnull createMethodList(llvm::Module * _Nonnull module, std::vector<llvm::Constant *> list)
{
    return _createList(module, list, getStructType(module, IR_Objc_MethodTypeName), 24);
}

llvm::GlobalVariable * _Nonnull createProtocolList(llvm::Module * _Nonnull module, std::vector<llvm::Constant *> list)
{
    std::vector<Constant *> proList;
    for (Constant *c : list) {
        proList.push_back(c);
    }
    proList.push_back(ConstantPointerNull::get(dyn_cast<PointerType>(list.back()->getType())));
    std::vector<Type *> types;
    types.push_back(Type::getInt64Ty(module->getContext()));
    types.push_back(ArrayType::get(list.back()->getType(), proList.size()));
    std::vector<Constant *> datas;
    datas.push_back(Constant::getIntegerValue(Type::getInt64Ty(module->getContext()), APInt(64, list.size(), false)));
    datas.push_back(ConstantArray::get(ArrayType::get(list.back()->getType(), proList.size()), proList));
    Constant *val = ConstantStruct::get(StructType::get(module->getContext(), types), datas);
    GlobalVariable *ret = new GlobalVariable(*module,
                                             val->getType(),
                                             false,
                                             GlobalValue::InternalLinkage,
                                             val);
    ret->setAlignment(MaybeAlign(8));
    ret->setSection("__DATA, __objc_const");
    insertValue(ConstantExpr::getBitCast(cast<Constant>(ret), Type::getInt8PtrTy(module->getContext())),
                getLlvmCompilerUsed(module));
    return ret;
}

llvm::GlobalVariable * _Nonnull createPropList(llvm::Module * _Nonnull module, std::vector<llvm::Constant *> list)
{
    return _createList(module, list, getStructType(module, IR_Objc_PropTypeName), 16);
}

llvm::GlobalVariable * _Nonnull createIvarList(llvm::Module * _Nonnull module, std::vector<llvm::Constant *> list)
{
    return _createList(module, list, getStructType(module, IR_Objc_IvarTypeName), 32);
}

llvm::GlobalVariable * _Nonnull _createObjcStringVariable(llvm::Module * _Nonnull module,
                                                          const char * _Nonnull str,
                                                          const char * _Nonnull name,
                                                          const char * _Nonnull section)
{
    Constant *zero = ConstantInt::get(Type::getInt32Ty(module->getContext()), 0);
    Constant *strVal = ConstantDataArray::getString(module->getContext(), StringRef(str), true);
    GlobalVariable *ret = new GlobalVariable(*module,
                                             strVal->getType(),
                                             true,
                                             GlobalValue::PrivateLinkage,
                                             strVal,
                                             name);
    ret->setAlignment(MaybeAlign(1));
    ret->setUnnamedAddr(GlobalValue::UnnamedAddr::Global);
    ret->setSection(section);
    insertValue(ConstantExpr::getInBoundsGetElementPtr(ret->getInitializer()->getType(), ret, (Constant *[]){zero, zero}),
                getLlvmCompilerUsed(module));
    return ret;
}

llvm::GlobalVariable * _Nonnull createObjcMethodName(llvm::Module * _Nonnull module, const char * _Nonnull name)
{
    return _createObjcStringVariable(module, name, "OBJC_METH_VAR_NAME_", "__TEXT,__objc_methname,cstring_literals");
}

llvm::GlobalVariable * _Nonnull createObjcVarType(llvm::Module * _Nonnull module, const char * _Nonnull name)
{
    return _createObjcStringVariable(module, name, "OBJC_METH_VAR_TYPE_", "__TEXT,__objc_methtype,cstring_literals");
}

llvm::GlobalVariable * _Nonnull createObjcClassName(llvm::Module * _Nonnull module, const char * _Nonnull name)
{
    return _createObjcStringVariable(module, name, "OBJC_CLASS_NAME_", "__TEXT,__objc_classname,cstring_literals");
}

#pragma mark get or create
llvm::GlobalVariable * _Nonnull getAndCreateClassReference(llvm::GlobalVariable * _Nonnull cls)
{
    GlobalVariable *clsRef = nullptr;
    for (GlobalVariable &v : cls->getParent()->getGlobalList()) {
        if (v.hasInitializer() && v.getInitializer() == cls &&
            v.hasSection() && 0 == strncmp(v.getSection().data(), "__DATA,__objc_classrefs", 23)) {
            clsRef = std::addressof(v);
            break;
        }
    }
    if (nullptr == clsRef) {
        clsRef = new GlobalVariable(*cls->getParent(),
                                    getStructType(cls->getParent(), IR_Objc_ClassTypeName)->getPointerTo(),
                                    true,
                                    GlobalValue::InternalLinkage,
                                    cls,
                                    "OBJC_CLASSLIST_REFERENCES_$_");
        clsRef->setSection("__DATA,__objc_classrefs,regular,no_dead_strip");
        clsRef->setAlignment(MaybeAlign(8));
        insertValue(ConstantExpr::getBitCast(clsRef, Type::getInt8PtrTy(cls->getContext())),
                    getLlvmCompilerUsed(cls->getParent()));
    }
    return clsRef;
}

llvm::GlobalVariable * _Nonnull getAndCreateSelectorReference(const char * _Nonnull selector, llvm::GlobalVariable * _Nonnull cls)
{
    GlobalVariable *selRef = nullptr;
    GlobalVariable *metaCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(0));
    GlobalVariable *metaRo = dyn_cast<GlobalVariable>(metaCls->getInitializer()->getOperand(4));
    ConstantStruct *metaMethodStruct = dyn_cast<ConstantStruct>(getValue(metaRo, 5)->getInitializer());
    uint64_t methodCount = (dyn_cast<ConstantInt>(metaMethodStruct->getOperand(1)))->getZExtValue();
    ConstantArray *methodList = dyn_cast<ConstantArray>(metaMethodStruct->getOperand(2));
    GlobalVariable *methodName = nullptr;
    for (int i = 0; i < methodCount; ++i) {
        GlobalVariable *m = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(methodList->getOperand(i)->getOperand(0))->getOperand(0));
        if (0 == strcmp(selector, stringFromGlobalVariable(m))) {
            methodName = m;
            break;
        }
    }
    for (GlobalVariable &v : cls->getParent()->getGlobalList()) {
        if (v.hasInitializer() && v.getInitializer()->getNumOperands() == 3 && v.getInitializer()->getOperand(0) == cls &&
            v.hasSection() && 0 == strncmp(v.getSection().data(), "__DATA,__objc_selrefs", 21)) {
            selRef = std::addressof(v);
            break;
        }
    }
    if (nullptr == selRef) {
        Constant *zero = ConstantInt::get(Type::getInt32Ty(cls->getContext()), 0);
        selRef = new GlobalVariable(*cls->getParent(),
                                    Type::getInt8PtrTy(cls->getContext()),
                                    false,
                                    GlobalValue::InternalLinkage,
                                    ConstantExpr::getInBoundsGetElementPtr(methodName->getInitializer()->getType(), methodName, (Constant *[]){zero, zero}),
                                    "OBJC_SELECTOR_REFERENCES_");
        selRef->setExternallyInitialized(true);
        selRef->setSection("__DATA,__objc_selrefs,literal_pointers,no_dead_strip");
        selRef->setAlignment(MaybeAlign(8));
        insertValue(ConstantExpr::getBitCast(selRef, Type::getInt8PtrTy(cls->getContext())),
                    getLlvmCompilerUsed(cls->getParent()));
    }
    
    return selRef;
}

#pragma mark get
const char * _Nonnull getObjcClassName(llvm::GlobalVariable * _Nonnull cls)
{
    if (cls->hasInitializer()) {
        GlobalVariable *ro = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(4));
        return stringFromGlobalVariable(dyn_cast<GlobalVariable>(dyn_cast<Constant>(ro->getInitializer()->getOperand(4))->getOperand(0)));
    } else {
        return (const char *)((uintptr_t)cls->getName().data() + strlen("OBJC_CLASS_$_"));
    }
}

const char * _Nonnull getObjcCategoryName(llvm::GlobalVariable * _Nonnull cat)
{
    ConstantStruct *structPtr = dyn_cast<ConstantStruct>(cat->getInitializer());
    assert(nullptr != structPtr && 8 == structPtr->getNumOperands());
    return stringFromGlobalVariable(dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(structPtr->getOperand(0)))->getOperand(0)));
}

const char * _Nonnull getObjcClassNameFromCategory(llvm::GlobalVariable * _Nonnull cat)
{
    ConstantStruct *structPtr = dyn_cast<ConstantStruct>(cat->getInitializer());
    assert(nullptr != structPtr && 8 == structPtr->getNumOperands());
    return getObjcClassName(dyn_cast<GlobalVariable>(structPtr->getOperand(1)));
}

const char * _Nonnull getObjcProcotolName(llvm::GlobalVariable * _Nonnull pro)
{
    ConstantStruct *structPtr = dyn_cast<ConstantStruct>(pro->getInitializer());
    assert(nullptr != structPtr && 13 == structPtr->getNumOperands());
    return stringFromGlobalVariable(dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(structPtr->getOperand(1)))->getOperand(0)));
}

std::map<const char *, void *> getObjcClassType(llvm::Module * _Nonnull module)
{
    std::map<const char *, void *> ret;
    for (StructType *type : module->getIdentifiedStructTypes()) {
        if (0 == strcmp(type->getName().data(), IR_Objc_ClassTypeName)) {
            ret[IR_Objc_ClassTypeName] = type;
        } else if (0 == strcmp(type->getName().data(), IR_Objc_CacheTypeName)) {
            ret[IR_Objc_CacheTypeName] = type;
        } else if (0 == strcmp(type->getName().data(), IR_Objc_RoTypeName)) {
            ret[IR_Objc_RoTypeName] = type;
        } else if (0 == strcmp(type->getName().data(), IR_Objc_MethodListTypeName)) {
            ret[IR_Objc_MethodListTypeName] = type;
        } else if (0 == strcmp(type->getName().data(), IR_Objc_MethodTypeName)) {
            ret[IR_Objc_MethodTypeName] = type;
        } else if (0 == strcmp(type->getName().data(), IR_Objc_ProtocolListTypeName)) {
            ret[IR_Objc_ProtocolListTypeName] = type;
        } else if (0 == strcmp(type->getName().data(), IR_Objc_ProtocolTypeName)) {
            ret[IR_Objc_ProtocolTypeName] = type;
        } else if (0 == strcmp(type->getName().data(), IR_Objc_IvarListTypeName)) {
            ret[IR_Objc_IvarListTypeName] = type;
        } else if (0 == strcmp(type->getName().data(), IR_Objc_IvarTypeName)) {
            ret[IR_Objc_IvarTypeName] = type;
        } else if (0 == strcmp(type->getName().data(), IR_Objc_PropListTypeName)) {
            ret[IR_Objc_PropListTypeName] = type;
        } else if (0 == strcmp(type->getName().data(), IR_Objc_PropTypeName)) {
            ret[IR_Objc_PropTypeName] = type;
        }
    }
    // method
    StructType *methodType = (StructType *)ret[IR_Objc_MethodTypeName];
    if (nullptr == methodType) {
        methodType = StructType::create(module->getContext(), IR_Objc_MethodTypeName);
        methodType->setBody(Type::getInt8PtrTy(module->getContext()),
                            Type::getInt8PtrTy(module->getContext()),
                            Type::getInt8PtrTy(module->getContext()));
        ret[IR_Objc_MethodTypeName] = methodType;
    }
    StructType *methodListType = (StructType *)ret[IR_Objc_MethodListTypeName];
    if (nullptr == methodListType) {
        methodListType = StructType::create(module->getContext(), IR_Objc_MethodListTypeName);
        methodListType->setBody(Type::getInt32Ty(module->getContext()),
                                Type::getInt32Ty(module->getContext()),
                                ArrayType::get(methodType, 0));
        ret[IR_Objc_MethodListTypeName] = methodListType;
    }
    // ivar
    StructType *ivarType = (StructType *)ret[IR_Objc_IvarTypeName];
    if (nullptr == ivarType) {
        ivarType = StructType::create(module->getContext(), IR_Objc_IvarTypeName);
        ivarType->setBody(Type::getInt32PtrTy(module->getContext()),
                          Type::getInt8PtrTy(module->getContext()),
                          Type::getInt8PtrTy(module->getContext()),
                          Type::getInt32Ty(module->getContext()),
                          Type::getInt32Ty(module->getContext()));
        ret[IR_Objc_IvarTypeName] = ivarType;
    }
    StructType *ivarListType = (StructType *)ret[IR_Objc_IvarListTypeName];
    if (nullptr == ivarListType) {
        ivarListType = StructType::create(module->getContext(), IR_Objc_IvarListTypeName);
        ivarListType->setBody(Type::getInt32Ty(module->getContext()),
                              Type::getInt32Ty(module->getContext()),
                              ArrayType::get(ivarType, 0));
        ret[IR_Objc_IvarListTypeName] = ivarListType;
    }
    // prop
    StructType *propType = (StructType *)ret[IR_Objc_PropTypeName];
    if (nullptr == propType) {
        propType = StructType::create(module->getContext(), IR_Objc_PropTypeName);
        propType->setBody(Type::getInt8PtrTy(module->getContext()),
                          Type::getInt8PtrTy(module->getContext()));
        ret[IR_Objc_PropTypeName] = propType;
    }
    StructType *propListType = (StructType *)ret[IR_Objc_PropListTypeName];
    if (nullptr == propListType) {
        propListType = StructType::create(module->getContext(), IR_Objc_PropListTypeName);
        propListType->setBody(Type::getInt32Ty(module->getContext()),
                              Type::getInt32Ty(module->getContext()),
                              ArrayType::get(propType, 0));
        ret[IR_Objc_PropListTypeName] = propListType;
    }
    // protocol
    StructType *protocolType = (StructType *)ret[IR_Objc_ProtocolTypeName];
    if (nullptr == protocolType) {
        protocolType = StructType::create(module->getContext(), IR_Objc_ProtocolTypeName);
    }
    StructType *protocolListType = (StructType *)ret[IR_Objc_ProtocolListTypeName];
    if (nullptr == protocolListType) {
        protocolListType = StructType::create(module->getContext(), IR_Objc_ProtocolListTypeName);
    }
    if (nullptr == ret[IR_Objc_ProtocolListTypeName]) {
        protocolListType->setBody(Type::getInt64Ty(module->getContext()),
                                  ArrayType::get(PointerType::getUnqual(protocolType), 0));
        ret[IR_Objc_ProtocolListTypeName] = protocolListType;
    }
    if (nullptr == ret[IR_Objc_ProtocolTypeName]) {
        protocolType->setBody(Type::getInt8PtrTy(module->getContext()),
                              Type::getInt8PtrTy(module->getContext()),
                              PointerType::getUnqual(protocolListType),
                              PointerType::getUnqual(methodListType),
                              PointerType::getUnqual(methodListType),
                              PointerType::getUnqual(methodListType),
                              PointerType::getUnqual(methodListType),
                              PointerType::getUnqual(propListType),
                              Type::getInt32Ty(module->getContext()),
                              Type::getInt32Ty(module->getContext()),
                              PointerType::getUnqual(Type::getInt8PtrTy(module->getContext())),
                              Type::getInt8PtrTy(module->getContext()),
                              PointerType::getUnqual(propListType));
        ret[IR_Objc_ProtocolTypeName] = protocolType;
    }
    // ro
    StructType *roType = (StructType *)ret[IR_Objc_RoTypeName];
    if (NULL == roType) {
        roType = StructType::create(module->getContext(), IR_Objc_RoTypeName);
        roType->setBody(Type::getInt32Ty(module->getContext()),
                        Type::getInt32Ty(module->getContext()),
                        Type::getInt32Ty(module->getContext()),
                        Type::getInt8PtrTy(module->getContext()),
                        Type::getInt8PtrTy(module->getContext()),
                        PointerType::getUnqual(methodListType),
                        PointerType::getUnqual(protocolListType),
                        PointerType::getUnqual(ivarListType),
                        Type::getInt8PtrTy(module->getContext()),
                        PointerType::getUnqual(propListType));
        ret[IR_Objc_RoTypeName] = roType;
    }

    // cache
    StructType *cacheType = (StructType *)ret[IR_Objc_CacheTypeName];
    if (NULL == cacheType) {
        cacheType = StructType::create(module->getContext(), IR_Objc_CacheTypeName);
        ret[IR_Objc_CacheTypeName] = cacheType;
    }
    // class
    StructType *classType = (StructType *)ret[IR_Objc_ClassTypeName];
    if (NULL == classType) {
        classType = StructType::create(module->getContext(), IR_Objc_ClassTypeName);
        classType->setBody(PointerType::getUnqual(classType),
                           PointerType::getUnqual(classType),
                           PointerType::getUnqual(cacheType),
                           PointerType::getUnqual(PointerType::getUnqual(FunctionType::get(Type::getInt8PtrTy(module->getContext()), {Type::getInt8PtrTy(module->getContext()), Type::getInt8PtrTy(module->getContext())}, false))),
                           PointerType::getUnqual(roType));
        ret[IR_Objc_ClassTypeName] = classType;
    }
    return ret;
}

std::map<const char *, void *> getObjcCategoryType(llvm::Module * _Nonnull module)
{
    std::map<const char *, void *> ret(getObjcClassType(module));
    for (StructType *type : module->getIdentifiedStructTypes()) {
        const char *name = type->getName().data();
        if (0 == strcmp(name, IR_Objc_CategoryTypeName)) {
            ret[IR_Objc_CategoryTypeName] = type;
            break;
        }
    }
    StructType *categoryType = (StructType *)ret[IR_Objc_CategoryTypeName];
    if (NULL == categoryType) {
        categoryType = StructType::create(module->getContext(), IR_Objc_CategoryTypeName);
        categoryType->setBody(Type::getInt8PtrTy(module->getContext()),
                              PointerType::getUnqual((Type *)ret[IR_Objc_ClassTypeName]),
                              PointerType::getUnqual((Type *)ret[IR_Objc_MethodListTypeName]),
                              PointerType::getUnqual((Type *)ret[IR_Objc_MethodListTypeName]),
                              PointerType::getUnqual((Type *)ret[IR_Objc_ProtocolListTypeName]),
                              PointerType::getUnqual((Type *)ret[IR_Objc_PropListTypeName]),
                              PointerType::getUnqual((Type *)ret[IR_Objc_PropListTypeName]),
                              Type::getInt32Ty(module->getContext()));
        ret[IR_Objc_CategoryTypeName] = categoryType;
    }
    return ret;
}

llvm::GlobalVariable * _Nullable getObjcClass(llvm::Module * _Nonnull module, const char * _Nonnull className)
{
    for (GlobalVariable &v : module->getGlobalList()) {
        if (v.hasSection()) {
            if (0 == strncmp(v.getSection().data(), "__DATA,__objc_classlist", 23)) {
                ConstantArray *arr = dyn_cast<ConstantArray>(v.getInitializer());
                for (int i = 0; i < arr->getNumOperands(); ++i) {
                    GlobalVariable *c = dyn_cast<GlobalVariable>(arr->getOperand(i)->getOperand(0));
                    if (c->hasInitializer()) {
                        ConstantStruct *structPtr = dyn_cast<ConstantStruct>(c->getInitializer());
                        GlobalVariable *ro = dyn_cast<GlobalVariable>(structPtr->getOperand(4));
                        if (isNullValue(ro, 4)) {
                            if (0 == strcmp(className, stringFromGlobalVariable(getValue(ro, 4)))) {
                                return c;
                            }
                        }
                    }
                }
            }
        }
    }
    return module->getNamedGlobal(std::string("OBJC_CLASS_$_") + className);
}

llvm::GlobalVariable * _Nullable getCategory(llvm::Module * _Nonnull module, const char * _Nonnull categoryName, const char * _Nonnull className)
{
    Module::GlobalListType &globallist = module->getGlobalList();
    for (GlobalVariable &variable : globallist) {
        if (variable.hasSection()) {
            if (0 == strncmp(variable.getSection().data(), "__DATA,__objc_catlist", 21)) {
                ConstantArray *arr = dyn_cast<ConstantArray>(variable.getInitializer());
                for (int i = 0; i < arr->getNumOperands(); ++i) {
                    GlobalVariable *categoryVariable = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0));
                    ConstantStruct *category = dyn_cast<ConstantStruct>(categoryVariable->getInitializer());
                    assert(NULL != category && 8 == category->getNumOperands());
                    if (0 == strcmp(stringFromGlobalVariable(dyn_cast<GlobalVariable>(category->getOperand(0)->getOperand(0))), categoryName)) {
                        if (0 == strcmp(getObjcClassName(dyn_cast<GlobalVariable>(category->getOperand(1))), className)) {
                            return categoryVariable;
                        }
                    }
                }
                break;
            }
        }
    }
    return nullptr;
}

llvm::GlobalVariable * _Nullable getObjcProtocolLabel(llvm::Module * _Nonnull module, const char * _Nonnull protocolName)
{
    for (GlobalVariable &v : module->getGlobalList()) {
        if (v.hasSection()) {
            if (0 == strncmp(v.getSection().data(), "__DATA,__objc_protolist", 23)) {
                GlobalVariable *var = dyn_cast<GlobalVariable>(v.getInitializer());
                const char *name = getObjcProcotolName(var);
                if (0 == strcmp(protocolName, name)) {
                    return std::addressof(v);
                }
            }
        }
    }
    return nullptr;
}
