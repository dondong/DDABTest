//
//  DDIRUtil+Objc.m
//  DDToolKit
//
//  Created by dondong on 2021/10/18.
//

#import "DDIRUtil+Objc.h"
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


@implementation DDIRUtil(Objc)
#pragma mark create
+ (llvm::GlobalVariable * _Nonnull)createObjcClass:(const char * _Nonnull)className
                                         withSuper:(llvm::GlobalVariable * _Nonnull)superCls
                                         metaSuper:(llvm::GlobalVariable * _Nonnull)metaSuperCls
                                             flags:(uint32_t)flags
                                        classFlags:(uint32_t)classFlags
                                     instanceStart:(uint32_t)instanceStart
                                      instanceSize:(uint32_t)instanceSize
                                        methodList:(std::vector<llvm::Constant *>)methods
                                   classMethodList:(std::vector<llvm::Constant *>)classMethods
                                          ivarList:(std::vector<llvm::Constant *>)ivars
                                      protocolList:(std::vector<llvm::Constant *>)protocols
                                          propList:(std::vector<llvm::Constant *>)props
                                     classPropList:(std::vector<llvm::Constant *>)classProps
                                          inModule:(llvm::Module * _Nonnull)module
{
    [self getObjcClassTypeInModule:module];
    GlobalVariable *name = [self createObjcClassName:className inModule:module];
    GlobalVariable *cache = module->getNamedGlobal("_objc_empty_cache");
    if (nullptr == cache) {
        cache = new GlobalVariable(*module,
                                   [self getStructType:IR_Objc_CacheTypeName inModule:module],
                                   false,
                                   GlobalValue::ExternalLinkage,
                                   nullptr,
                                   "_objc_empty_cache");
    }
    GlobalVariable *nsobject = module->getNamedGlobal("OBJC_METACLASS_$_NSObject");
    if (nullptr == nsobject) {
        nsobject = new GlobalVariable(*module,
                                      [self getStructType:IR_Objc_ClassTypeName inModule:module],
                                      false,
                                      GlobalValue::ExternalLinkage,
                                      nullptr,
                                      "OBJC_METACLASS_$_NSObject");
    }
    
    // meta class
    std::vector<llvm::Constant *> classIvars;
    std::vector<llvm::Constant *> classProtocols;
    GlobalVariable *metaCls = [self _createObjcClass:className
                                                name:name
                                             withIsa:nsobject
                                          superClass:metaSuperCls
                                               cache:cache
                                               flags:classFlags
                                       instanceStart:40
                                        instanceSize:40
                                          methodList:classMethods
                                            ivarList:classIvars
                                        protocolList:classProtocols
                                            propList:classProps
                                              isMeta:true
                                            inModule:module];
    // class
    GlobalVariable *cls = [self _createObjcClass:className
                                            name:name
                                         withIsa:metaCls
                                      superClass:superCls
                                           cache:cache
                                           flags:flags
                                   instanceStart:instanceStart
                                    instanceSize:instanceSize
                                      methodList:methods
                                        ivarList:ivars
                                    protocolList:protocols
                                        propList:props
                                          isMeta:false
                                        inModule:module];
    // array
    [self insertValue:ConstantExpr::getBitCast(cast<Constant>(cls), Type::getInt8PtrTy(module->getContext()))
        toGlobalArray:[self getLlvmCompilerUsedInModule:module]
                   at:0
             inModule:module];
    [self insertValue:ConstantExpr::getBitCast(cast<Constant>(cls), Type::getInt8PtrTy(module->getContext()))
toGlobalArrayWithSection:"__DATA,__objc_classlist"
          defaultName:"OBJC_LABEL_CLASS_$"
             inModule:module];
    return cls;
}

+ (llvm::GlobalVariable * _Nonnull)_createObjcClass:(const char * _Nonnull)className
                                               name:(llvm::GlobalVariable * _Nonnull)name
                                            withIsa:(llvm::GlobalVariable * _Nonnull)isa
                                         superClass:(llvm::GlobalVariable * _Nonnull)superClass
                                              cache:(llvm::GlobalVariable * _Nonnull)cache
                                              flags:(uint32_t)flags
                                      instanceStart:(uint32_t)instanceStart
                                       instanceSize:(uint32_t)instanceSize
                                         methodList:(std::vector<llvm::Constant *>)methods
                                           ivarList:(std::vector<llvm::Constant *>)ivars
                                       protocolList:(std::vector<llvm::Constant *>)protocols
                                           propList:(std::vector<llvm::Constant *>)props
                                             isMeta:(bool)meta
                                           inModule:(llvm::Module * _Nonnull)module
{
    NSDictionary *dic = [self getObjcClassTypeInModule:module];
    StructType *classType        = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_ClassTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    StructType *roType           = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_RoTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    StructType *methodListType   = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_MethodListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    StructType *protocolListType = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_ProtocolListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    StructType *ivarListType     = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_IvarListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    StructType *propListType     = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_PropListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    assert(nullptr != classType && nullptr != roType && nullptr != methodListType && nullptr != protocolListType && nullptr != ivarListType && nullptr != propListType);
    Constant *zero = ConstantInt::get(Type::getInt32Ty(module->getContext()), 0);

    std::vector<Constant *> roList;
    roList.push_back(ConstantInt::get(Type::getInt32Ty(module->getContext()), flags));
    roList.push_back(ConstantInt::get(Type::getInt32Ty(module->getContext()), instanceStart));
    roList.push_back(ConstantInt::get(Type::getInt32Ty(module->getContext()), instanceSize));
    roList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(module->getContext())));
    roList.push_back(ConstantExpr::getInBoundsGetElementPtr(name->getInitializer()->getType(), name, (Constant *[]){zero, zero}));
    if (methods.size() > 0) {
        GlobalVariable *p = [self createMethodList:methods inModule:module];
        if (meta) {
            p->setName([[NSString stringWithFormat:@"_OBJC_$_CLASS_METHODS_%s", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        } else {
            p->setName([[NSString stringWithFormat:@"_OBJC_$_INSTANCE_METHODS_%s", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        roList.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        roList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    if (protocols.size() > 0) {
        GlobalVariable *p = [self createProtocolList:protocols inModule:module];
        if (meta) {
            p->setName([[NSString stringWithFormat:@"_OBJC_METACLASS_PROTOCOLS_$_%s", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        } else {
            p->setName([[NSString stringWithFormat:@"_OBJC_CLASS_PROTOCOLS_$_%s", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        roList.push_back(ConstantExpr::getBitCast(p, protocolListType->getPointerTo()));
    } else {
        roList.push_back(ConstantPointerNull::get(PointerType::getUnqual(protocolListType)));
    }
    if (ivars.size() > 0) {
        GlobalVariable *p = [self createIvarList:ivars inModule:module];
        if (meta) {
            p->setName([[NSString stringWithFormat:@"_OBJC_$_CLASS_VARIABLES_%s", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        } else {
            p->setName([[NSString stringWithFormat:@"_OBJC_$_INSTANCE_VARIABLES_%s", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        roList.push_back(ConstantExpr::getBitCast(p, ivarListType->getPointerTo()));
    } else {
        roList.push_back(ConstantPointerNull::get(PointerType::getUnqual(ivarListType)));
    }
    roList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(module->getContext())));
    if (props.size() > 0) {
        GlobalVariable *p = [self createPropList:props inModule:module];
        if (meta) {
            p->setName([[NSString stringWithFormat:@"_OBJC_$_CLASS_PROP_LIST_%s", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        } else {
            p->setName([[NSString stringWithFormat:@"_OBJC_$_PROP_LIST_%s", className] cStringUsingEncoding:NSUTF8StringEncoding]);
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
                                            (meta ? [[NSString stringWithFormat:@"_OBJC_METACLASS_RO_$_%s", className] cStringUsingEncoding:NSUTF8StringEncoding] :
                                             [[NSString stringWithFormat:@"_OBJC_CLASS_RO_$_%s", className] cStringUsingEncoding:NSUTF8StringEncoding]));
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
                                              (meta ? [[NSString stringWithFormat:@"OBJC_METACLASS_$_%s", className] cStringUsingEncoding:NSUTF8StringEncoding] :
                                               [[NSString stringWithFormat:@"OBJC_CLASS_$_%s", className] cStringUsingEncoding:NSUTF8StringEncoding]));
    cls->setSection("__DATA, __objc_data");
    cls->setAlignment(MaybeAlign(8));
    return cls;
}

+ (llvm::GlobalVariable * _Nonnull)createObjcCategory:(const char * _Nonnull)categoryName
                                                  cls:(llvm::GlobalVariable * _Nonnull)cls
                                       withMethodList:(std::vector<llvm::Constant *>)methods
                                      classMethodList:(std::vector<llvm::Constant *>)classMethods
                                         protocolList:(std::vector<llvm::Constant *>)protocols
                                             propList:(std::vector<llvm::Constant *>)props
                                        classPropList:(std::vector<llvm::Constant *>)classProps
                                             inModule:(llvm::Module * _Nonnull)module
{
    return [self createObjcCategory:categoryName cls:cls withMethodList:methods classMethodList:classMethods protocolList:protocols propList:props classPropList:classProps labelAtIndex:0 inModule:module];
}

+ (llvm::GlobalVariable * _Nonnull)createObjcCategory:(const char * _Nonnull)categoryName
                                                  cls:(llvm::GlobalVariable * _Nonnull)cls
                                       withMethodList:(std::vector<llvm::Constant *>)methods
                                      classMethodList:(std::vector<llvm::Constant *>)classMethods
                                         protocolList:(std::vector<llvm::Constant *>)protocols
                                             propList:(std::vector<llvm::Constant *>)props
                                        classPropList:(std::vector<llvm::Constant *>)classProps
                                         labelAtIndex:(NSUInteger)index
                                             inModule:(llvm::Module * _Nonnull)module
{
    NSDictionary *dic = [self getObjcCategoryTypeInModule:module];
    std::vector<Constant *> datas;
    Constant *zero = ConstantInt::get(Type::getInt32Ty(module->getContext()), 0);
    GlobalVariable *cName = [self createObjcClassName:categoryName inModule:module];
    datas.push_back(ConstantExpr::getInBoundsGetElementPtr(cName->getInitializer()->getType(), cName, (Constant *[]){zero, zero}));
    datas.push_back(cls);
    StructType *categoryType     = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_CategoryTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    StructType *methodListType   = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_MethodListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    StructType *protocolListType = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_ProtocolListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    StructType *propListType     = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_PropListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    NSString *n = [self getObjcClassName:cls];
    if (methods.size() > 0) {
        GlobalVariable *p = [self createMethodList:methods inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_$_CATEGORY_INSTANCE_METHODS_%@_$_%s", n, categoryName] cStringUsingEncoding:NSUTF8StringEncoding]);
        datas.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        datas.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    if (classMethods.size() > 0) {
        GlobalVariable *p = [self createMethodList:classMethods inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_$_CATEGORY_CLASS_METHODS_%@_$_%s", n, categoryName] cStringUsingEncoding:NSUTF8StringEncoding]);
        datas.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        datas.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    if (protocols.size()) {
        GlobalVariable *p = [self createProtocolList:protocols inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_CATEGORY_PROTOCOLS_$_%@_$_%s", n, categoryName] cStringUsingEncoding:NSUTF8StringEncoding]);
        datas.push_back(ConstantExpr::getBitCast(p, protocolListType->getPointerTo()));
    } else {
        datas.push_back(ConstantPointerNull::get(PointerType::getUnqual(protocolListType)));
    }
    if (props.size() > 0) {
        GlobalVariable *p = [self createPropList:props inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_$_PROP_LIST_%@_$_%s", n, categoryName] cStringUsingEncoding:NSUTF8StringEncoding]);
        datas.push_back(ConstantExpr::getBitCast(p, propListType->getPointerTo()));
    } else {
        datas.push_back(ConstantPointerNull::get(PointerType::getUnqual(propListType)));
    }
    if (classProps.size() > 0) {
        GlobalVariable *p = [self createPropList:classProps inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_$_PROP_LIST_CLASS_%@_$_%s", n, categoryName] cStringUsingEncoding:NSUTF8StringEncoding]);
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
                                             [[NSString stringWithFormat:@"_OBJC_$_CATEGORY_%@_$_%s", n, categoryName] cStringUsingEncoding:NSUTF8StringEncoding]);
    ret->setAlignment(MaybeAlign(8));
    ret->setSection("__DATA, __objc_const");
    [self insertValue:ConstantExpr::getBitCast(cast<Constant>(ret), Type::getInt8PtrTy(module->getContext()))
        toGlobalArray:[self getLlvmCompilerUsedInModule:module]
                   at:0
             inModule:module];
    [self insertValue:ConstantExpr::getBitCast(cast<Constant>(ret), Type::getInt8PtrTy(module->getContext()))
toGlobalArrayWithSection:"__DATA,__objc_catlist"
          defaultName:"OBJC_LABEL_CATEGORY_$"
                   at:index
             inModule:module];
    return ret;
}

+ (llvm::GlobalVariable * _Nonnull)createObjcProtocol:(const char * _Nonnull)protocolName
                                            withFlags:(uint32_t)flags
                                         protocolList:(std::vector<llvm::Constant *>)protocols
                                           methodList:(std::vector<llvm::Constant *>)methods
                                      classMethodList:(std::vector<llvm::Constant *>)classMethods
                                   optionalMethodList:(std::vector<llvm::Constant *>)optionalMethods
                              optionalClassMethodList:(std::vector<llvm::Constant *>)optionalClassMethods
                                             propList:(std::vector<llvm::Constant *>)props
                                        classPropList:(std::vector<llvm::Constant *>)classProps
                                             inModule:(llvm::Module * _Nonnull)module
{
    NSDictionary *dic = [self getObjcClassTypeInModule:module];
    StructType *protocolType     = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_ProtocolTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    StructType *methodListType   = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_MethodListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    StructType *protocolListType = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_ProtocolListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    StructType *propListType     = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_PropListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    assert(nullptr != methodListType && nullptr != protocolListType && nullptr != propListType);
    Constant *zero = ConstantInt::get(Type::getInt32Ty(module->getContext()), 0);

    std::vector<Constant *> proList;
    proList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(module->getContext())));
    // mangledName
    GlobalVariable *name = [self createObjcClassName:protocolName inModule:module];
    proList.push_back(ConstantExpr::getInBoundsGetElementPtr(name->getInitializer()->getType(), name, (Constant *[]){zero, zero}));
    // protocols
    if (protocols.size() > 0) {
        GlobalVariable *p = [self createProtocolList:protocols inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_$_PROTOCOL_REFS_%s", protocolName] cStringUsingEncoding:NSUTF8StringEncoding]);
        proList.push_back(ConstantExpr::getBitCast(p, protocolListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(protocolListType)));
    }
    // instanceMethods
    if (methods.size() > 0) {
        GlobalVariable *p = [self createMethodList:methods inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_$_PROTOCOL_INSTANCE_METHODS_%s", protocolName] cStringUsingEncoding:NSUTF8StringEncoding]);
        proList.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    // classMethods
    if (classMethods.size() > 0) {
        GlobalVariable *p = [self createMethodList:classMethods inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_$_PROTOCOL_CLASS_METHODS_%s", protocolName] cStringUsingEncoding:NSUTF8StringEncoding]);
        proList.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    // optionalInstanceMethods
    if (optionalMethods.size() > 0) {
        GlobalVariable *p = [self createMethodList:optionalMethods inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_$_PROTOCOL_INSTANCE_METHODS_OPT_%s", protocolName] cStringUsingEncoding:NSUTF8StringEncoding]);
        proList.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    // optionalClassMethods
    if (optionalClassMethods.size() > 0) {
        GlobalVariable *p = [self createMethodList:optionalClassMethods inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_$_PROTOCOL_CLASS_METHODS_OPT_%s", protocolName] cStringUsingEncoding:NSUTF8StringEncoding]);
        proList.push_back(ConstantExpr::getBitCast(p, methodListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
    }
    // instanceProperties
    if (props.size() > 0) {
        GlobalVariable *p = [self createPropList:props inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_$_PROP_LIST_%s", protocolName] cStringUsingEncoding:NSUTF8StringEncoding]);
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
                                                  [[NSString stringWithFormat:@"_OBJC_$_PROTOCOL_METHOD_TYPES_%s", protocolName] cStringUsingEncoding:NSUTF8StringEncoding]);
    typeVar->setSection("__DATA, __objc_const");
    typeVar->setAlignment(MaybeAlign(8));
    [self insertValue:ConstantExpr::getBitCast(cast<Constant>(typeVar), Type::getInt8PtrTy(module->getContext()))
        toGlobalArray:[self getLlvmCompilerUsedInModule:module]
                   at:0
             inModule:module];
    proList.push_back(ConstantExpr::getBitCast(typeVar, Type::getInt8PtrTy(module->getContext())->getPointerTo()));
    // _demangledName
    proList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(module->getContext())));
    // _classProperties
    if (classProps.size() > 0) {
        GlobalVariable *p = [self createPropList:classProps inModule:module];
        p->setName([[NSString stringWithFormat:@"_OBJC_$_CLASS_PROP_LIST_%s", protocolName] cStringUsingEncoding:NSUTF8StringEncoding]);
        proList.push_back(ConstantExpr::getBitCast(p, propListType->getPointerTo()));
    } else {
        proList.push_back(ConstantPointerNull::get(PointerType::getUnqual(propListType)));
    }
    GlobalVariable *pro = new GlobalVariable(*module,
                                             protocolType,
                                             false,
                                             GlobalValue::WeakAnyLinkage,
                                             ConstantStruct::get(protocolType, proList),
                                             [[NSString stringWithFormat:@"_OBJC_PROTOCOL_$_%s", protocolName] cStringUsingEncoding:NSUTF8StringEncoding]);
    pro->setVisibility(GlobalValue::HiddenVisibility);
    pro->setAlignment(MaybeAlign(8));
    
    GlobalVariable *proLabel = new GlobalVariable(*module,
                                                  protocolType->getPointerTo(),
                                                  false,
                                                  GlobalValue::WeakAnyLinkage,
                                                  pro,
                                                  [[NSString stringWithFormat:@"_OBJC_LABEL_PROTOCOL_$_%s", protocolName] cStringUsingEncoding:NSUTF8StringEncoding]);
    proLabel->setVisibility(GlobalValue::HiddenVisibility);
    proLabel->setSection("__DATA,__objc_protolist,coalesced,no_dead_strip");
    proLabel->setAlignment(MaybeAlign(8));
    [self insertValue:ConstantExpr::getBitCast(cast<Constant>(proLabel), Type::getInt8PtrTy(module->getContext()))
        toGlobalArray:[self getLlvmUsedInModule:module]
                   at:0
             inModule:module];
    [self insertValue:ConstantExpr::getBitCast(cast<Constant>(pro), Type::getInt8PtrTy(module->getContext()))
        toGlobalArray:[self getLlvmUsedInModule:module]
                   at:0
             inModule:module];
    
    return pro;
}

+ (llvm::GlobalVariable * _Nonnull)createMethodList:(std::vector<llvm::Constant *>)list inModule:(llvm::Module * _Nonnull)module
{
    return [self _createList:list elementType:[self getStructType:IR_Objc_MethodTypeName inModule:module] elementSize:24 inModule:module];
}

+ (llvm::GlobalVariable * _Nonnull)createProtocolList:(std::vector<llvm::Constant *>)list inModule:(llvm::Module * _Nonnull)module
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
    [self insertValue:ConstantExpr::getBitCast(cast<Constant>(ret), Type::getInt8PtrTy(module->getContext()))
        toGlobalArray:[self getLlvmCompilerUsedInModule:module]
                   at:0
             inModule:module];
    return ret;
}

+ (llvm::GlobalVariable * _Nonnull)createPropList:(std::vector<llvm::Constant *>)list inModule:(llvm::Module * _Nonnull)module
{
    return [self _createList:list elementType:[self getStructType:IR_Objc_PropTypeName inModule:module] elementSize:16 inModule:module];
}

+ (llvm::GlobalVariable * _Nonnull)createIvarList:(std::vector<llvm::Constant *>)list inModule:(llvm::Module * _Nonnull)module
{
    return [self _createList:list elementType:[self getStructType:IR_Objc_IvarTypeName inModule:module] elementSize:32 inModule:module];
}

+ (llvm::GlobalVariable * _Nonnull)_createList:(std::vector<llvm::Constant *>)list
                                   elementType:(llvm::Type * _Nonnull)t
                                   elementSize:(uint32_t)size
                                      inModule:(llvm::Module * _Nonnull)module
{
    std::vector<Type *> types;
    types.push_back(Type::getInt32Ty(module->getContext()));
    types.push_back(Type::getInt32Ty(module->getContext()));
    types.push_back(ArrayType::get(t, list.size()));
    std::vector<Constant *> datas;
    datas.push_back(Constant::getIntegerValue(Type::getInt32Ty(module->getContext()), APInt(32, size, false)));
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
    [self insertValue:ConstantExpr::getBitCast(cast<Constant>(ret), Type::getInt8PtrTy(module->getContext()))
        toGlobalArray:[self getLlvmCompilerUsedInModule:module]
                   at:0
             inModule:module];
    return ret;
}

+ (llvm::GlobalVariable * _Nonnull)createObjcMethodName:(const char *)name inModule:(llvm::Module * _Nonnull)module
{
    return [self _createObjcStringVariable:name name:"OBJC_METH_VAR_NAME_" section:"__TEXT,__objc_methname,cstring_literals" inModule:module];
}

+ (llvm::GlobalVariable * _Nonnull)createObjcVarType:(const char *)name inModule:(llvm::Module * _Nonnull)module
{
    return [self _createObjcStringVariable:name name:"OBJC_METH_VAR_TYPE_" section:"__TEXT,__objc_methtype,cstring_literals" inModule:module];
}

+ (llvm::GlobalVariable * _Nonnull)createObjcClassName:(const char *)name inModule:(llvm::Module * _Nonnull)module
{
    return [self _createObjcStringVariable:name name:"OBJC_CLASS_NAME_" section:"__TEXT,__objc_classname,cstring_literals" inModule:module];
}


+ (llvm::GlobalVariable * _Nonnull)_createObjcStringVariable:(const char *)str
                                                        name:(const char *)name
                                                     section:(const char *)section
                                                    inModule:(llvm::Module * _Nonnull)module
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
    [self insertValue:ConstantExpr::getInBoundsGetElementPtr(ret->getInitializer()->getType(), ret, (Constant *[]){zero, zero})
        toGlobalArray:[self getLlvmCompilerUsedInModule:module]
                   at:0
             inModule:module];
    return ret;
}

#pragma mark get or create
+ (llvm::GlobalVariable * _Nonnull)getAndCreateClassReference:(llvm::GlobalVariable * _Nonnull)cls
                                                     inModule:(llvm::Module * _Nonnull)module
{
    GlobalVariable *clsRef = nullptr;
    for (GlobalVariable &v : module->getGlobalList()) {
        if (v.hasInitializer() && v.getInitializer() == cls &&
            v.hasSection() && 0 == strncmp(v.getSection().data(), "__DATA,__objc_classrefs", 23)) {
            clsRef = std::addressof(v);
            break;
        }
    }
    if (nullptr == clsRef) {
        clsRef = new GlobalVariable(*module,
                                    [self getStructType:IR_Objc_ClassTypeName inModule:module]->getPointerTo(),
                                    true,
                                    GlobalValue::InternalLinkage,
                                    cls,
                                    "OBJC_CLASSLIST_REFERENCES_$_");
        clsRef->setSection("__DATA,__objc_classrefs,regular,no_dead_strip");
        clsRef->setAlignment(MaybeAlign(8));
        [self insertValue:ConstantExpr::getBitCast(clsRef, Type::getInt8PtrTy(module->getContext()))
            toGlobalArray:[self getLlvmCompilerUsedInModule:module]
                       at:0
                 inModule:module];
    }
    return clsRef;
}

+ (llvm::GlobalVariable * _Nonnull)getAndCreateSelectorReference:(const char * _Nonnull)selector
                                                         inClass:(llvm::GlobalVariable * _Nonnull)cls
                                                        inModule:(llvm::Module * _Nonnull)module
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
        if (0 == strcmp(selector, [[self stringFromGlobalVariable:m] cStringUsingEncoding:NSUTF8StringEncoding])) {
            methodName = m;
            break;
        }
    }
    for (GlobalVariable &v : module->getGlobalList()) {
        if (v.hasInitializer() && v.getInitializer()->getNumOperands() == 3 && v.getInitializer()->getOperand(0) == cls &&
            v.hasSection() && 0 == strncmp(v.getSection().data(), "__DATA,__objc_selrefs", 21)) {
            selRef = std::addressof(v);
            break;
        }
    }
    if (nullptr == selRef) {
        Constant *zero = ConstantInt::get(Type::getInt32Ty(module->getContext()), 0);
        selRef = new GlobalVariable(*module,
                                    Type::getInt8PtrTy(module->getContext()),
                                    false,
                                    GlobalValue::InternalLinkage,
                                    ConstantExpr::getInBoundsGetElementPtr(methodName->getInitializer()->getType(), methodName, (Constant *[]){zero, zero}),
                                    "OBJC_SELECTOR_REFERENCES_");
        selRef->setExternallyInitialized(true);
        selRef->setSection("__DATA,__objc_selrefs,literal_pointers,no_dead_strip");
        selRef->setAlignment(MaybeAlign(8));
        [self insertValue:ConstantExpr::getBitCast(selRef, Type::getInt8PtrTy(module->getContext()))
            toGlobalArray:[self getLlvmCompilerUsedInModule:module]
                       at:0
                 inModule:module];
    }
    
    return selRef;
}

#pragma mark get
+ (nullable NSString *)getObjcClassName:(llvm::GlobalVariable * _Nonnull)cls
{
    if (cls->hasInitializer()) {
        GlobalVariable *ro = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(4));
        return [self stringFromGlobalVariable:dyn_cast<GlobalVariable>(dyn_cast<Constant>(ro->getInitializer()->getOperand(4))->getOperand(0))];
    } else {
        return [[NSString stringWithCString:cls->getName().data() encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"OBJC_CLASS_$_" withString:@""];
    }
}

+ (nullable NSString *)getObjcCategoryName:(llvm::GlobalVariable * _Nonnull)cat
{
    ConstantStruct *structPtr = dyn_cast<ConstantStruct>(cat->getInitializer());
    assert(nullptr != structPtr && 8 == structPtr->getNumOperands());
    return [self stringFromGlobalVariable:dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(structPtr->getOperand(0)))->getOperand(0))];
}

+ (nullable NSString *)getObjcClassNameFromCategory:(llvm::GlobalVariable * _Nonnull)cat
{
    ConstantStruct *structPtr = dyn_cast<ConstantStruct>(cat->getInitializer());
    assert(nullptr != structPtr && 8 == structPtr->getNumOperands());
    return [self getObjcClassName:dyn_cast<GlobalVariable>(structPtr->getOperand(1))];
}

+ (nullable NSString *)getObjcProcotolName:(llvm::GlobalVariable * _Nonnull)pro
{
    ConstantStruct *structPtr = dyn_cast<ConstantStruct>(pro->getInitializer());
    assert(nullptr != structPtr && 13 == structPtr->getNumOperands());
    return [self stringFromGlobalVariable:dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(structPtr->getOperand(1)))->getOperand(0))];
}

+ (nonnull NSDictionary<NSString *, NSValue *> *)getObjcClassTypeInModule:(llvm::Module * _Nonnull)module
{
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    for (StructType *type : module->getIdentifiedStructTypes()) {
        if (0 == strcmp(type->getName().data(), IR_Objc_ClassTypeName) ||
            0 == strcmp(type->getName().data(), IR_Objc_CacheTypeName) ||
            0 == strcmp(type->getName().data(), IR_Objc_RoTypeName) ||
            0 == strcmp(type->getName().data(), IR_Objc_MethodListTypeName) ||
            0 == strcmp(type->getName().data(), IR_Objc_MethodTypeName) ||
            0 == strcmp(type->getName().data(), IR_Objc_ProtocolListTypeName) ||
            0 == strcmp(type->getName().data(), IR_Objc_ProtocolTypeName) ||
            0 == strcmp(type->getName().data(), IR_Objc_IvarListTypeName) ||
            0 == strcmp(type->getName().data(), IR_Objc_IvarTypeName) ||
            0 == strcmp(type->getName().data(), IR_Objc_PropListTypeName) ||
            0 == strcmp(type->getName().data(), IR_Objc_PropTypeName)) {
            [ret setObject:[NSValue valueWithPointer:type] forKey:[NSString stringWithCString:type->getName().data() encoding:NSUTF8StringEncoding]];
        }
    }
    // method
    StructType *methodType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_MethodTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == methodType) {
        methodType = StructType::create(module->getContext(), IR_Objc_MethodTypeName);
        methodType->setBody(Type::getInt8PtrTy(module->getContext()),
                            Type::getInt8PtrTy(module->getContext()),
                            Type::getInt8PtrTy(module->getContext()));
        [ret setObject:[NSValue valueWithPointer:methodType] forKey:[NSString stringWithCString:IR_Objc_MethodTypeName encoding:NSUTF8StringEncoding]];
    }
    StructType *methodListType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_MethodListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == methodListType) {
        methodListType = StructType::create(module->getContext(), IR_Objc_MethodListTypeName);
        methodListType->setBody(Type::getInt32Ty(module->getContext()),
                                Type::getInt32Ty(module->getContext()),
                                ArrayType::get(methodType, 0));
        [ret setObject:[NSValue valueWithPointer:methodListType] forKey:[NSString stringWithCString:IR_Objc_MethodListTypeName encoding:NSUTF8StringEncoding]];
    }
    // ivar
    StructType *ivarType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_IvarTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == ivarType) {
        ivarType = StructType::create(module->getContext(), IR_Objc_IvarTypeName);
        ivarType->setBody(Type::getInt32PtrTy(module->getContext()),
                          Type::getInt8PtrTy(module->getContext()),
                          Type::getInt8PtrTy(module->getContext()),
                          Type::getInt32Ty(module->getContext()),
                          Type::getInt32Ty(module->getContext()));
        [ret setObject:[NSValue valueWithPointer:ivarType] forKey:[NSString stringWithCString:IR_Objc_IvarTypeName encoding:NSUTF8StringEncoding]];
    }
    StructType *ivarListType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_IvarListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == ivarListType) {
        ivarListType = StructType::create(module->getContext(), IR_Objc_IvarListTypeName);
        ivarListType->setBody(Type::getInt32Ty(module->getContext()),
                              Type::getInt32Ty(module->getContext()),
                              ArrayType::get(ivarType, 0));
        [ret setObject:[NSValue valueWithPointer:ivarListType] forKey:[NSString stringWithCString:IR_Objc_IvarListTypeName encoding:NSUTF8StringEncoding]];
    }
    // prop
    StructType *propType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_PropTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == propType) {
        propType = StructType::create(module->getContext(), IR_Objc_PropTypeName);
        propType->setBody(Type::getInt8PtrTy(module->getContext()),
                          Type::getInt8PtrTy(module->getContext()));
        [ret setObject:[NSValue valueWithPointer:propType] forKey:[NSString stringWithCString:IR_Objc_PropTypeName encoding:NSUTF8StringEncoding]];
    }
    StructType *propListType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_PropListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == propListType) {
        propListType = StructType::create(module->getContext(), IR_Objc_PropListTypeName);
        propListType->setBody(Type::getInt32Ty(module->getContext()),
                              Type::getInt32Ty(module->getContext()),
                              ArrayType::get(propType, 0));
        [ret setObject:[NSValue valueWithPointer:propListType] forKey:[NSString stringWithCString:IR_Objc_PropListTypeName encoding:NSUTF8StringEncoding]];
    }
    // protocol
    StructType *protocolType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_ProtocolTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == protocolType) {
        protocolType = StructType::create(module->getContext(), IR_Objc_ProtocolTypeName);
    }
    StructType *protocolListType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_ProtocolListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == protocolListType) {
        protocolListType = StructType::create(module->getContext(), IR_Objc_ProtocolListTypeName);
    }
    if (nil == [ret objectForKey:[NSString stringWithCString:IR_Objc_ProtocolListTypeName encoding:NSUTF8StringEncoding]]) {
        protocolListType->setBody(Type::getInt64Ty(module->getContext()),
                                  ArrayType::get(PointerType::getUnqual(protocolType), 0));
        [ret setObject:[NSValue valueWithPointer:protocolListType] forKey:[NSString stringWithCString:IR_Objc_ProtocolListTypeName encoding:NSUTF8StringEncoding]];
    }
    if (nil == [ret objectForKey:[NSString stringWithCString:IR_Objc_ProtocolTypeName encoding:NSUTF8StringEncoding]]) {
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
        [ret setObject:[NSValue valueWithPointer:protocolType] forKey:[NSString stringWithCString:IR_Objc_ProtocolTypeName encoding:NSUTF8StringEncoding]];
    }
    // ro
    StructType *roType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_RoTypeName encoding:NSUTF8StringEncoding]] pointerValue];
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
        [ret setObject:[NSValue valueWithPointer:roType] forKey:[NSString stringWithCString:IR_Objc_RoTypeName encoding:NSUTF8StringEncoding]];
    }

    // cache
    StructType *cacheType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_CacheTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == cacheType) {
        cacheType = StructType::create(module->getContext(), IR_Objc_CacheTypeName);
        [ret setObject:[NSValue valueWithPointer:cacheType] forKey:[NSString stringWithCString:IR_Objc_CacheTypeName encoding:NSUTF8StringEncoding]];
    }
    // class
    StructType *classType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_ClassTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == classType) {
        classType = StructType::create(module->getContext(), IR_Objc_ClassTypeName);
        classType->setBody(PointerType::getUnqual(classType),
                           PointerType::getUnqual(classType),
                           PointerType::getUnqual(cacheType),
                           PointerType::getUnqual(PointerType::getUnqual(FunctionType::get(Type::getInt8PtrTy(module->getContext()), {Type::getInt8PtrTy(module->getContext()), Type::getInt8PtrTy(module->getContext())}, false))),
                           PointerType::getUnqual(roType));
        [ret setObject:[NSValue valueWithPointer:classType] forKey:[NSString stringWithCString:IR_Objc_ClassTypeName encoding:NSUTF8StringEncoding]];
    }
    return [NSDictionary dictionaryWithDictionary:ret];
}

+ (nonnull NSDictionary<NSString *, NSValue *> *)getObjcCategoryTypeInModule:(llvm::Module * _Nonnull)module
{
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:[self getObjcClassTypeInModule:module]];
    for (StructType *type : module->getIdentifiedStructTypes()) {
        const char *name = type->getName().data();
        if (0 == strcmp(name, IR_Objc_CategoryTypeName)) {
            [ret setObject:[NSValue valueWithPointer:type] forKey:[NSString stringWithCString:IR_Objc_CategoryTypeName encoding:NSUTF8StringEncoding]];
            break;
        }
    }
    StructType *categoryType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_CategoryTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == categoryType) {
        categoryType = StructType::create(module->getContext(), IR_Objc_CategoryTypeName);
        categoryType->setBody(Type::getInt8PtrTy(module->getContext()),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_ClassTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_MethodListTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_MethodListTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_ProtocolListTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_PropListTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Objc_PropListTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              Type::getInt32Ty(module->getContext()));
        [ret setObject:[NSValue valueWithPointer:categoryType] forKey:[NSString stringWithCString:IR_Objc_CategoryTypeName encoding:NSUTF8StringEncoding]];
    }
    return [NSDictionary dictionaryWithDictionary:ret];
}

+ (llvm::GlobalVariable * _Nullable)getObjcClass:(nonnull NSString *)className inModule:(llvm::Module * _Nonnull)module
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
                            if ([className isEqualToString:[self stringFromGlobalVariable:getValue(ro, 4)]]) {
                                return c;
                            }
                        }
                    }
                }
            }
        }
    }
    return module->getNamedGlobal([[NSString stringWithFormat:@"OBJC_CLASS_$_%@", className] cStringUsingEncoding:NSUTF8StringEncoding]);
}

+ (llvm:: GlobalVariable * _Nullable)getCategory:(nonnull NSString *)categoryName forObjcClass:(nonnull NSString *)className inModule:(llvm::Module * _Nonnull)module
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
                    if ([[self stringFromGlobalVariable:dyn_cast<GlobalVariable>(category->getOperand(0)->getOperand(0))] isEqualToString:categoryName]) {
                        if ([[self getObjcClassName:dyn_cast<GlobalVariable>(category->getOperand(1))] isEqualToString:className]) {
                            return categoryVariable;
                        }
                    }
                }
                break;
            }
        }
    }
    return nil;
}

+ (llvm::GlobalVariable * _Nullable)getObjcProtocolLabel:(nonnull NSString *)protocolName
        inModule:(llvm::Module * _Nonnull)module
{
    for (GlobalVariable &v : module->getGlobalList()) {
        if (v.hasSection()) {
            if (0 == strncmp(v.getSection().data(), "__DATA,__objc_protolist", 23)) {
                GlobalVariable *var = dyn_cast<GlobalVariable>(v.getInitializer());
                NSString *name = [self getObjcProcotolName:var];
                if ([protocolName isEqualToString:name]) {
                    return std::addressof(v);
                }
            }
        }
    }
    return nullptr;
}
@end
