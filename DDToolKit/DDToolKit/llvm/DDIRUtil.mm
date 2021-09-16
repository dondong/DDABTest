//
//  DDIRUtil.m
//  DDToolKit
//
//  Created by dondong on 2021/9/15.
//

#import "DDIRUtil.h"

const char *IR_Ojbc_ClassTypeName        = "struct._class_t";
const char *IR_Ojbc_CacheTypeName        = "struct._objc_cache";
const char *IR_Ojbc_RoTypeName           = "struct._class_ro_t";
const char *IR_Ojbc_MethodListTypeName   = "struct.__method_list_t";
const char *IR_Ojbc_MethodTypeName       = "struct._objc_method";
const char *IR_Ojbc_ProtocolListTypeName = "struct._objc_protocol_list";
const char *IR_Ojbc_ProtocolTypeName     = "struct._protocol_t";
const char *IR_Ojbc_IvarListTypeName     = "struct._ivar_list_t";
const char *IR_Ojbc_IvarTypeName         = "struct._ivar_t";
const char *IR_Ojbc_PropListTypeName     = "struct._prop_list_t";
const char *IR_Ojbc_PropTypeName         = "struct._prop_t";
const char *IR_Ojbc_CategoryTypeName     = "struct._category_t";

#define checkValue(ptr, index) (NULL != dyn_cast<ConstantExpr>(ptr->getOperand(index)))
#define getGlobalVariable(ptr, index) (dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(ptr->getOperand(index)))->getOperand(0)))
#define getValue(ptr, index) ((dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(ptr->getOperand(index)))->getOperand(0)))->getInitializer())
using namespace llvm;

@implementation DDIRUtil
+ (nonnull NSDictionary<NSString *, NSValue *> *)getObjcClassTypeInModule:(llvm::Module * _Nonnull)module
{
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    for (StructType *type : module->getIdentifiedStructTypes()) {
        if (0 == strcmp(type->getName().data(), IR_Ojbc_ClassTypeName) ||
            0 == strcmp(type->getName().data(), IR_Ojbc_CacheTypeName) ||
            0 == strcmp(type->getName().data(), IR_Ojbc_RoTypeName) ||
            0 == strcmp(type->getName().data(), IR_Ojbc_MethodListTypeName) ||
            0 == strcmp(type->getName().data(), IR_Ojbc_MethodTypeName) ||
            0 == strcmp(type->getName().data(), IR_Ojbc_ProtocolListTypeName) ||
            0 == strcmp(type->getName().data(), IR_Ojbc_ProtocolTypeName) ||
            0 == strcmp(type->getName().data(), IR_Ojbc_IvarListTypeName) ||
            0 == strcmp(type->getName().data(), IR_Ojbc_IvarTypeName) ||
            0 == strcmp(type->getName().data(), IR_Ojbc_PropListTypeName) ||
            0 == strcmp(type->getName().data(), IR_Ojbc_PropTypeName)) {
            [ret setObject:[NSValue valueWithPointer:type] forKey:[NSString stringWithCString:type->getName().data() encoding:NSUTF8StringEncoding]];
        }
    }
    // method
    StructType *methodType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_MethodTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == methodType) {
        methodType = StructType::create(module->getContext(), IR_Ojbc_MethodTypeName);
        methodType->setBody(Type::getInt8PtrTy(module->getContext()),
                            Type::getInt8PtrTy(module->getContext()),
                            Type::getInt8PtrTy(module->getContext()));
        [ret setObject:[NSValue valueWithPointer:methodType] forKey:[NSString stringWithCString:IR_Ojbc_MethodTypeName encoding:NSUTF8StringEncoding]];
    }
    StructType *methodListType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_MethodListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == methodListType) {
        methodListType = StructType::create(module->getContext(), IR_Ojbc_MethodListTypeName);
        methodListType->setBody(Type::getInt32Ty(module->getContext()),
                                Type::getInt32Ty(module->getContext()),
                                ArrayType::get(methodType, 0));
        [ret setObject:[NSValue valueWithPointer:methodListType] forKey:[NSString stringWithCString:IR_Ojbc_MethodListTypeName encoding:NSUTF8StringEncoding]];
    }
    // ivar
    StructType *ivarType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_IvarTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == ivarType) {
        ivarType = StructType::create(module->getContext(), IR_Ojbc_IvarTypeName);
        ivarType->setBody(Type::getInt32PtrTy(module->getContext()),
                          Type::getInt8PtrTy(module->getContext()),
                          Type::getInt8PtrTy(module->getContext()),
                          Type::getInt32Ty(module->getContext()),
                          Type::getInt32Ty(module->getContext()));
        [ret setObject:[NSValue valueWithPointer:ivarType] forKey:[NSString stringWithCString:IR_Ojbc_IvarTypeName encoding:NSUTF8StringEncoding]];
    }
    StructType *ivarListType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_IvarListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == ivarListType) {
        ivarListType = StructType::create(module->getContext(), IR_Ojbc_IvarListTypeName);
        ivarListType->setBody(Type::getInt32Ty(module->getContext()),
                              Type::getInt32Ty(module->getContext()),
                              ArrayType::get(ivarType, 0));
        [ret setObject:[NSValue valueWithPointer:ivarListType] forKey:[NSString stringWithCString:IR_Ojbc_IvarListTypeName encoding:NSUTF8StringEncoding]];
    }
    // prop
    StructType *propType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_PropTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == propType) {
        propType = StructType::create(module->getContext(), IR_Ojbc_PropTypeName);
        propType->setBody(Type::getInt8PtrTy(module->getContext()),
                          Type::getInt8PtrTy(module->getContext()));
        [ret setObject:[NSValue valueWithPointer:propType] forKey:[NSString stringWithCString:IR_Ojbc_PropTypeName encoding:NSUTF8StringEncoding]];
    }
    StructType *propListType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_PropListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == propListType) {
        propListType = StructType::create(module->getContext(), IR_Ojbc_PropListTypeName);
        propListType->setBody(Type::getInt32Ty(module->getContext()),
                              Type::getInt32Ty(module->getContext()),
                              ArrayType::get(propType, 0));
        [ret setObject:[NSValue valueWithPointer:propListType] forKey:[NSString stringWithCString:IR_Ojbc_PropListTypeName encoding:NSUTF8StringEncoding]];
    }
    // protocol
    StructType *protocolType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_ProtocolTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == protocolType) {
        protocolType = StructType::create(module->getContext(), IR_Ojbc_ProtocolTypeName);
    }
    StructType *protocolListType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_ProtocolListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == protocolListType) {
        protocolListType = StructType::create(module->getContext(), IR_Ojbc_ProtocolListTypeName);
    }
    if (nil == [ret objectForKey:[NSString stringWithCString:IR_Ojbc_ProtocolListTypeName encoding:NSUTF8StringEncoding]]) {
        protocolListType->setBody(Type::getInt64Ty(module->getContext()),
                                  ArrayType::get(PointerType::getUnqual(protocolType), 0));
        [ret setObject:[NSValue valueWithPointer:protocolListType] forKey:[NSString stringWithCString:IR_Ojbc_ProtocolListTypeName encoding:NSUTF8StringEncoding]];
    }
    if (nil == [ret objectForKey:[NSString stringWithCString:IR_Ojbc_ProtocolTypeName encoding:NSUTF8StringEncoding]]) {
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
        [ret setObject:[NSValue valueWithPointer:protocolType] forKey:[NSString stringWithCString:IR_Ojbc_ProtocolTypeName encoding:NSUTF8StringEncoding]];
    }
    // ro
    StructType *roType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_RoTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == roType) {
        roType = StructType::create(module->getContext(), IR_Ojbc_RoTypeName);
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
        [ret setObject:[NSValue valueWithPointer:roType] forKey:[NSString stringWithCString:IR_Ojbc_RoTypeName encoding:NSUTF8StringEncoding]];
    }

    // cache
    StructType *cacheType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_CacheTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == cacheType) {
        cacheType = StructType::create(module->getContext(), IR_Ojbc_CacheTypeName);
        [ret setObject:[NSValue valueWithPointer:cacheType] forKey:[NSString stringWithCString:IR_Ojbc_CacheTypeName encoding:NSUTF8StringEncoding]];
    }
    // class
    StructType *classType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_ClassTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == classType) {
        classType = StructType::create(module->getContext(), IR_Ojbc_ClassTypeName);
        classType->setBody(PointerType::getUnqual(classType),
                           PointerType::getUnqual(classType),
                           PointerType::getUnqual(cacheType),
                           PointerType::getUnqual(PointerType::getUnqual(FunctionType::get(Type::getInt8PtrTy(module->getContext()), {Type::getInt8PtrTy(module->getContext()), Type::getInt8PtrTy(module->getContext())}, false))),
                           PointerType::getUnqual(roType));
        [ret setObject:[NSValue valueWithPointer:classType] forKey:[NSString stringWithCString:IR_Ojbc_ClassTypeName encoding:NSUTF8StringEncoding]];
    }
    return [NSDictionary dictionaryWithDictionary:ret];
}

+ (nonnull NSDictionary<NSString *, NSValue *> *)getObjcCategoryTypeInModule:(llvm::Module * _Nonnull)module
{
    NSMutableDictionary *ret = [NSMutableDictionary dictionaryWithDictionary:[self getObjcClassTypeInModule:module]];
    for (StructType *type : module->getIdentifiedStructTypes()) {
        const char *name = type->getName().data();
        if (0 == strcmp(name, IR_Ojbc_CategoryTypeName)) {
            [ret setObject:[NSValue valueWithPointer:type] forKey:[NSString stringWithCString:IR_Ojbc_CategoryTypeName encoding:NSUTF8StringEncoding]];
            break;
        }
    }
    StructType *categoryType = (StructType *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_CategoryTypeName encoding:NSUTF8StringEncoding]] pointerValue];
    if (NULL == categoryType) {
        categoryType = StructType::create(module->getContext(), IR_Ojbc_CategoryTypeName);
        categoryType->setBody(Type::getInt8PtrTy(module->getContext()),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_ClassTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_MethodListTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_MethodListTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_ProtocolListTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_PropListTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              PointerType::getUnqual((Type *)[[ret objectForKey:[NSString stringWithCString:IR_Ojbc_PropListTypeName encoding:NSUTF8StringEncoding]] pointerValue]),
                              Type::getInt32Ty(module->getContext()));
        [ret setObject:[NSValue valueWithPointer:categoryType] forKey:[NSString stringWithCString:IR_Ojbc_CategoryTypeName encoding:NSUTF8StringEncoding]];
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
                        ConstantStruct *roPtr = dyn_cast<ConstantStruct>(dyn_cast<GlobalVariable>(structPtr->getOperand(4))->getInitializer());
                        if (checkValue(roPtr, 4)) {
                            if ([className isEqualToString:[self stringFromArray:dyn_cast<ConstantDataArray>(getValue(roPtr, 4))]]) {
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

+ (llvm::GlobalVariable * _Nonnull)getLlvmCompilerUsedInModule:(llvm::Module * _Nonnull)module
{
    GlobalVariable *used = module->getNamedGlobal("llvm.compiler.used");
    if (NULL == used) {
        std::vector<Constant *> list;
        Constant *val = ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(module->getContext()), 0), list);
        used = new GlobalVariable(*module,
                                  val->getType(),
                                  false,
                                  GlobalValue::AppendingLinkage,
                                  val,
                                  "llvm.compiler.used");
        used->setSection("llvm.metadata");
    }
    return used;
}

+ (llvm::StructType * _Nullable)getStructType:(const char *)name inModule:(llvm::Module * _Nonnull)module
{
    for (StructType *type : module->getIdentifiedStructTypes()) {
        if (0 == strcmp(type->getName().data(), name)) {
            return type;
        }
    }
    return NULL;
}

+ (nonnull NSString *)changeGlobalValueName:(llvm::GlobalValue * _Nonnull)variable from:(nonnull NSString *)oldName to:(nonnull NSString *)newName
{
    assert(NULL != variable);
    NSString *n = nil;
    NSString *o = [NSString stringWithCString:variable->getName().data() encoding:NSUTF8StringEncoding];
    if ([o hasSuffix:[@"_" stringByAppendingString:oldName]]) {
        n = [o stringByReplacingOccurrencesOfString:oldName withString:newName options:0 range:NSMakeRange(o.length - oldName.length, oldName.length)];
    } else if ([o containsString:[NSString stringWithFormat:@"$_%@.", oldName]]) {
        n = [o stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"$_%@.", oldName] withString:[NSString stringWithFormat:@"$_%@.", newName]];
    } else if ([o containsString:[NSString stringWithFormat:@"[%@ ", oldName]]) {
        n = [o stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"[%@ ", oldName] withString:[NSString stringWithFormat:@"[%@ ", newName]];
    }
    if (nil != n) {
        variable->setName(Twine([n cStringUsingEncoding:NSUTF8StringEncoding]));
        return n;
    } else {
        return o;
    }
}

+ (void)changeStringValue:(llvm::ConstantStruct * _Nonnull)target atOperand:(NSUInteger)index to:(nonnull NSString *)newValue inModule:(llvm::Module * _Nonnull)module
{
    ConstantExpr *ptr = dyn_cast<ConstantExpr>(target->getOperand((int)index));
    if (NULL != ptr) {
        GlobalVariable *oldVariable = dyn_cast<GlobalVariable>(ptr->getOperand(0));
        StringRef oldName = oldVariable->getName();
        oldVariable->setName(Twine([[NSString stringWithFormat:@"%s..", oldName.data()] cStringUsingEncoding:NSUTF8StringEncoding]));
        Constant *val = ConstantDataArray::getString(target->getContext(), StringRef([newValue cStringUsingEncoding:NSUTF8StringEncoding]), true);
        GlobalVariable *newVariable = new GlobalVariable(*module, val->getType(), oldVariable->isConstant(), oldVariable->getLinkage(), val, oldName, oldVariable, oldVariable->getThreadLocalMode(), oldVariable->getAddressSpace(), oldVariable->isExternallyInitialized());
        newVariable->setAlignment(oldVariable->getAlign());
        newVariable->setUnnamedAddr(oldVariable->getUnnamedAddr());
        if (oldVariable->hasSection()) {
            newVariable->setSection(oldVariable->getSection());
        }
        if (oldVariable->hasComdat()) {
            newVariable->setComdat(oldVariable->getComdat());
        }
        while (!oldVariable->materialized_use_empty()) {
            if (auto *exp = dyn_cast<ConstantExpr>(oldVariable->user_back())) {
                if (!exp->materialized_use_empty()) {
                    if (auto *g = dyn_cast<Constant>(exp->user_back())) {
                        Constant *zero = ConstantInt::get(Type::getInt32Ty(target->getContext()), 0);
                        g->handleOperandChange(exp, ConstantExpr::getInBoundsGetElementPtr(newVariable->getInitializer()->getType(), newVariable, (Constant *[]){zero, zero}));
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            } else {
                break;;
            }
        }
        oldVariable->eraseFromParent();
    }
}

+ (llvm::GlobalVariable * _Nonnull)insertValue:(llvm::Constant * _Nonnull)value toConstantArray:(llvm::GlobalVariable * _Nonnull)variable at:(NSUInteger)index inModule:(llvm::Module * _Nonnull)module
{
    Constant *arr = dyn_cast<Constant>(variable->getInitializer());
    if (0 <= index && index <= arr->getNumOperands()) {
        StringRef oldName = variable->getName();
        variable->setName(Twine([[NSString stringWithFormat:@"%s..", oldName.data()] cStringUsingEncoding:NSUTF8StringEncoding]));
        std::vector<Constant *> list;
        for (int i = 0; i <= arr->getNumOperands(); ++i) {
            if (i == index) {
                list.push_back(value);
            } else {
                list.push_back((dyn_cast<ConstantArray>(arr))->getOperand(i < index ? i : i - 1));
            }
        }
        Constant *val = ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(module->getContext()), arr->getNumOperands() + 1), list);
        GlobalVariable *newVariable = new GlobalVariable(*module, val->getType(), variable->isConstant(), variable->getLinkage(), val, oldName, variable, variable->getThreadLocalMode(), variable->getAddressSpace(), variable->isExternallyInitialized());
        newVariable->setAlignment(variable->getAlign());
        newVariable->setUnnamedAddr(variable->getUnnamedAddr());
        if (variable->hasSection()) {
            newVariable->setSection(variable->getSection());
        }
        if (variable->hasComdat()) {
            newVariable->setComdat(variable->getComdat());
        }
        while (!variable->materialized_use_empty()) {
            if (auto *exp = dyn_cast<ConstantExpr>(variable->user_back())) {
                if (!exp->materialized_use_empty()) {
                    if (auto *g = dyn_cast<Constant>(exp->user_back())) {
                        g->handleOperandChange(exp, ConstantExpr::getBitCast(cast<Constant>(newVariable), Type::getInt8PtrTy(module->getContext())));
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            } else {
                break;;
            }
        }
        variable->eraseFromParent();
        return newVariable;
    }
    return variable;
}

+ (llvm::GlobalVariable *_Nonnull)removeValueFromConstantArray:(llvm::GlobalVariable *_Nonnull)variable at:(NSUInteger)index inModule:(llvm::Module * _Nonnull)module
{
    Constant *arr = dyn_cast<Constant>(variable->getInitializer());
    if (0 <= index && index < arr->getNumOperands()) {
        StringRef oldName = variable->getName();
        variable->setName(Twine([[NSString stringWithFormat:@"%s..", oldName.data()] cStringUsingEncoding:NSUTF8StringEncoding]));
        std::vector<Constant *> list;
        for (int i = 0; i < arr->getNumOperands(); ++i) {
            if (i != index) {
                list.push_back((dyn_cast<ConstantArray>(arr))->getOperand(i));
            }
        }
        Constant *val = ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(module->getContext()), arr->getNumOperands() - 1), list);
        GlobalVariable *newVariable = new GlobalVariable(*module, val->getType(), variable->isConstant(), variable->getLinkage(), val, oldName, variable, variable->getThreadLocalMode(), variable->getAddressSpace(), variable->isExternallyInitialized());
        newVariable->setAlignment(variable->getAlign());
        newVariable->setUnnamedAddr(variable->getUnnamedAddr());
        if (variable->hasSection()) {
            newVariable->setSection(variable->getSection());
        }
        if (variable->hasComdat()) {
            newVariable->setComdat(variable->getComdat());
        }
        while (!variable->materialized_use_empty()) {
            if (auto *exp = dyn_cast<ConstantExpr>(variable->user_back())) {
                if (!exp->materialized_use_empty()) {
                    if (auto *g = dyn_cast<Constant>(exp->user_back())) {
                        g->handleOperandChange(exp, ConstantExpr::getBitCast(cast<Constant>(newVariable), Type::getInt8PtrTy(module->getContext())));
                    } else {
                        break;
                    }
                } else {
                    break;
                }
            } else {
                break;
            }
        }
        variable->eraseFromParent();
        return newVariable;
    }
    return variable;
}

+ (nonnull NSString *)stringFromArray:(llvm::ConstantDataArray * _Nonnull)array
{
    NSMutableString *str = [[NSMutableString alloc] init];
    for (int i = 0; i < array->getType()->getArrayNumElements() - 1; ++i) {
        [str appendFormat:@"%c", (char)array->getElementAsInteger(i)];
    }
    return [NSString stringWithString:str];
}
@end
