//
//  DDIRUtil.m
//  DDToolKit
//
//  Created by dondong on 2021/9/15.
//

#import "DDIRUtil.h"
#include <llvm/IR/Module.h>
#include <llvm/IR/ValueHandle.h>

using namespace llvm;

@implementation DDIRUtil
#pragma mark check
bool isNullValue(llvm::GlobalVariable * _Nonnull var, int index)
{
    return (nullptr != dyn_cast<ConstantExpr>(var->getInitializer()->getOperand(index)));
}

llvm::GlobalVariable *getValue(llvm::GlobalVariable * _Nonnull var, int index)
{
    return dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(var->getInitializer()->getOperand(index)))->getOperand(0));
}

#pragma mark get
+ (llvm::GlobalVariable * _Nonnull)getLlvmCompilerUsedInModule:(llvm::Module * _Nonnull)module
{
    GlobalVariable *used = module->getNamedGlobal("llvm.compiler.used");
    if (nullptr == used) {
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

+ (llvm::GlobalVariable * _Nonnull)getLlvmUsedInModule:(llvm::Module * _Nonnull)module
{
    GlobalVariable *used = module->getNamedGlobal("llvm.used");
    if (nullptr == used) {
        std::vector<Constant *> list;
        Constant *val = ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(module->getContext()), 0), list);
        used = new GlobalVariable(*module,
                                  val->getType(),
                                  false,
                                  GlobalValue::AppendingLinkage,
                                  val,
                                  "llvm.used");
        used->setSection("llvm.metadata");
    }
    return used;
}

+ (llvm::StructType * _Nullable)getStructType:(const char * _Nonnull)name inModule:(llvm::Module * _Nonnull)module
{
    for (StructType *type : module->getIdentifiedStructTypes()) {
        if (0 == strcmp(type->getName().data(), name)) {
            return type;
        }
    }
    return nullptr;
}

#pragma mark create
+ (llvm::GlobalVariable * _Nonnull)createGlobalVariableName:(const char * _Nonnull)name
                                         fromGlobalVariable:(llvm::GlobalVariable * _Nonnull)other
                                                       type:(llvm::Type * _Nullable)type
                                                initializer:(llvm::Constant * _Nullable)initializer
                                                   inModule:(llvm::Module * _Nonnull)module
{
    GlobalVariable *ret = new GlobalVariable(*module,
                                             nullptr != type ? type : (nullptr != initializer ? initializer->getType() : other->getType()),
                                             other->isConstant(),
                                             other->getLinkage(),
                                             initializer,
                                             name,
                                             other,
                                             other->getThreadLocalMode(),
                                             other->getType()->getAddressSpace());
    ret->copyAttributesFrom(other);
    return ret;
}

+ (void)removeGlobalValue:(llvm::GlobalValue * _Nonnull)var inModule:(llvm::Module * _Nonnull)module
{
    std::vector<GlobalValue *> list;
    if (auto variable = dyn_cast<GlobalVariable>(var)) {
        if (variable->hasInitializer() && nullptr != variable->getInitializer()) {
            [self _setGlobalVariableInConstant:variable->getInitializer() toList:list];
        }
    } else if (auto fun = dyn_cast<Function>(var)) {
        
    }
    var->removeDeadConstantUsers();
    while (!var->materialized_use_empty()) {
        if (auto e = dyn_cast<ConstantExpr>(var->user_back())) {
            if (!e->materialized_use_empty()) {
                if (auto c = dyn_cast<Constant>(e->user_back())) {
                    if (auto *g = dyn_cast<GlobalVariable>(c->user_back())) {
                        if (g->getInitializer()->getType()->getTypeID() == Type::ArrayTyID) {
                            [self removeValue:var fromGlobalArray:g inModule:module];
                            var->removeDeadConstantUsers();
                            e->removeDeadConstantUsers();
                            c->removeDeadConstantUsers();
                            g->removeDeadConstantUsers();
                        } else {
                            NSAssert(false, @"unkown");
                        }
                    } else {
                        NSAssert(false, @"unkown");
                    }
                } else {
                    NSAssert(false, @"unkown");
                }
            } else {
                NSAssert(false, @"unkown");
            }
        } else {
            NSAssert(false, @"unkown");
        }
    }
    var->eraseFromParent();
    for (GlobalValue *g : list) {
        g->removeDeadConstantUsers();
        if (g->use_empty()) {
            [self removeGlobalValue:g inModule:module];
        } else if (g->getNumUses() == 1) {
            if (auto e = dyn_cast<ConstantExpr>(g->user_back())) {
                e->removeDeadConstantUsers();
                if (e->getNumUses() == 1) {
                    if (auto c = dyn_cast<Constant>(e->user_back())) {
                        c->removeDeadConstantUsers();
                        if (c->getNumUses() == 1) {
                            if (auto *u = dyn_cast<GlobalVariable>(c->user_back())) {
                                if (0 == strcmp(u->getName().data(), "llvm.compiler.used") ||
                                    0 == strcmp(u->getName().data(), "llvm.used")) {
                                    [self removeGlobalValue:g inModule:module];
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

+ (void)_setGlobalVariableInConstant:(Constant *)c toList:(std::vector<GlobalValue *> &)l
{
    for (GlobalValue *g : l) {
        if (g == c) {
            return;
        }
    }
    if (auto a = dyn_cast<ConstantAggregate>(c)) {
        for (int i = 0; i < a->getNumOperands(); ++i) {
            [self _setGlobalVariableInConstant:a->getOperand(i) toList:l];
        }
    } else if (auto e = dyn_cast<ConstantExpr>(c)) {
        if (e->getNumOperands() > 0) {
            [self _setGlobalVariableInConstant:e->getOperand(0) toList:l];
        }
    } else if (auto g = dyn_cast<GlobalVariable>(c)) {
        l.push_back(g);
    } else if (auto f = dyn_cast<Function>(c)) {
        l.push_back(f);
    }
}

#pragma mark modify
+ (void)replaceGlobalVariable:(llvm::GlobalVariable * _Nonnull)var1
                         with:(llvm::GlobalVariable * _Nonnull)var2
{
//    if (var1->getAlign() || var2->getAlign()) {
//        var2->setAlignment(std::max(var1->getAlign().getValueOr(var1->getParent()->getDataLayout().getPreferredAlignvar1),
//                                    var2->getAlign().getValueOr(var2->getParent()->getDataLayout().getPreferredAlignvar1)));
//    }
    SmallVector<DIGlobalVariableExpression *, 1> mds;
    var1->getDebugInfo(mds);
    for (auto md : mds) {
        var2->addDebugInfo(md);
    }
//    var1->replaceAllUsesWith(NewConstant);
    if (var1->hasValueHandle()) {
        ValueHandleBase::ValueIsRAUWd(var1, var2);
    }
    if (var1->isUsedByMetadata())
      ValueAsMetadata::handleRAUW(var1, var2);

    while (!var1->materialized_use_empty()) {
      Use &u = *var1->materialized_use_begin();
      if (auto *c = dyn_cast<Constant>(u.getUser())) {
        if (!isa<GlobalValue>(c)) {
          c->handleOperandChange(var1, var2);
          continue;
        }
      }
      u.set(var2);
    }
}

+ (nonnull NSString *)changeGlobalValueName:(llvm::GlobalValue * _Nonnull)variable from:(nonnull NSString *)oldName to:(nonnull NSString *)newName
{
    assert(nullptr != variable);
    NSString *n = nil;
    NSString *o = [NSString stringWithCString:variable->getName().data() encoding:NSUTF8StringEncoding];
    if ([o hasSuffix:[@"_" stringByAppendingString:oldName]]) {   // xx_oldName
        n = [o stringByReplacingOccurrencesOfString:oldName withString:newName options:0 range:NSMakeRange(o.length - oldName.length, oldName.length)];
    } else if ([o containsString:[NSString stringWithFormat:@"$_%@.", oldName]]) {   // xx$_oldName.xx
        n = [o stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"$_%@.", oldName] withString:[NSString stringWithFormat:@"$_%@.", newName]];
    } else if ([o containsString:[NSString stringWithFormat:@"[%@ ", oldName]]) {   // xx[oldName xx
        n = [o stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"[%@ ", oldName] withString:[NSString stringWithFormat:@"[%@ ", newName]];
    } else if ([o containsString:[NSString stringWithFormat:@"(%@) ", oldName]]) {   // xx(oldName) xx
        n = [o stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"(%@) ", oldName] withString:[NSString stringWithFormat:@"(%@) ", newName]];
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
    if (nullptr != ptr) {
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

+ (llvm::GlobalVariable * _Nonnull)insertValue:(llvm::Constant * _Nonnull)value toGlobalArray:(llvm::GlobalVariable * _Nonnull)variable at:(NSUInteger)index inModule:(llvm::Module * _Nonnull)module
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

+ (llvm::GlobalVariable *_Nonnull)removeValue:(llvm::Constant *_Nonnull)var fromGlobalArray:(llvm::GlobalVariable *_Nonnull)variable inModule:(llvm::Module * _Nonnull)module
{
    ConstantArray *arr = dyn_cast<ConstantArray>(variable->getInitializer());
    int index = -1;
    for (int i = 0; i < arr->getNumOperands(); ++i) {
        if (var == arr->getOperand(i)->getOperand(0)) {
            index = i;
            break;
        }
    }
    if (index != -1) {
        return [self removeValueAtIndex:index fromGlobalArray:variable inModule:module];
    } else {
        return variable;
    }
}

+ (llvm::GlobalVariable *_Nonnull)removeValueAtIndex:(NSUInteger)index fromGlobalArray:(llvm::GlobalVariable *_Nonnull)variable  inModule:(llvm::Module * _Nonnull)module
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

+ (nonnull NSString *)stringFromGlobalVariable:(llvm::GlobalVariable * _Nonnull)var
{
    ConstantDataArray *array = dyn_cast<ConstantDataArray>(var->getInitializer());
    NSMutableString *str = [[NSMutableString alloc] init];
    for (int i = 0; i < array->getType()->getArrayNumElements() - 1; ++i) {
        [str appendFormat:@"%c", (char)array->getElementAsInteger(i)];
    }
    return [NSString stringWithString:str];
}
@end
