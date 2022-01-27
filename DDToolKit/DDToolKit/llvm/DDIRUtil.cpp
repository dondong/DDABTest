//
//  DDIRUtil.cpp
//  DDToolKit
//
//  Created by dondong on 2022/1/26.
//

#include "DDIRUtil.hpp"
#include <map>
#include <llvm/IR/Module.h>
#include <llvm/IR/ValueHandle.h>

using namespace llvm;
#pragma mark check
bool isNullValue(llvm::GlobalVariable * _Nonnull var, int index)
{
    return (nullptr != dyn_cast<ConstantExpr>(var->getInitializer()->getOperand(index)));
}

llvm::GlobalVariable * _Nullable getValue(llvm::GlobalVariable * _Nonnull var, int index)
{
    return dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(var->getInitializer()->getOperand(index)))->getOperand(0));
}

#pragma mark get
llvm::GlobalVariable * _Nonnull getLlvmCompilerUsed(llvm::Module * _Nonnull module)
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

llvm::GlobalVariable * _Nonnull getLlvmUsed(llvm::Module * _Nonnull module)
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

llvm::GlobalVariable * _Nullable getGlabalArray(llvm::Module * _Nonnull module, const char * _Nonnull sectionName)
{
    GlobalVariable *label = nullptr;
    for (GlobalVariable &v : module->getGlobalList()) {
        if (v.GlobalValue::hasSection()) {
            if (0 == strncmp(v.getSection().data(), sectionName, strlen(sectionName))) {
                label = std::addressof(v);
                break;
            }
        }
    }
    return label;
}

llvm::StructType * _Nullable getStructType(llvm::Module * _Nonnull module, const char * _Nonnull name)
{
    for (StructType *type : module->getIdentifiedStructTypes()) {
        if (0 == strcmp(type->getName().data(), name)) {
            return type;
        }
    }
    return nullptr;
}

bool isExternalStaticVariable(llvm::GlobalVariable * _Nonnull var)
{
    return (GlobalValue::ExternalLinkage == var->getLinkage() &&
//            true == var->isConstant() &&
            true == var->hasInitializer() &&
            false == var->hasSection());
}

bool isExternalStaticVariableDeclaration(llvm::GlobalVariable * _Nonnull var)
{
    return (GlobalValue::ExternalLinkage == var->getLinkage() &&
//            true == var->isConstant() &&
            false == var->hasSection());
}

bool isOnlyUsedByLLVM(llvm::GlobalValue * _Nonnull var)
{
    if (var->getNumUses() == 1) {
        if (auto e = dyn_cast<ConstantExpr>(var->user_back())) {
            e->removeDeadConstantUsers();
            if (e->getNumUses() == 1) {
                if (auto c = dyn_cast<Constant>(e->user_back())) {
                    c->removeDeadConstantUsers();
                    if (c->getNumUses() == 1) {
                        if (auto *u = dyn_cast<GlobalVariable>(c->user_back())) {
                            if (0 == strcmp(u->getName().data(), "llvm.compiler.used") ||
                                0 == strcmp(u->getName().data(), "llvm.used")) {
                                return true;
                            }
                        }
                    }
                }
            }
        }
    }
    return false;
}

#pragma mark create
llvm::GlobalVariable * _Nonnull createGlobalVariable(llvm::GlobalVariable * _Nonnull copyVariable,
                                                     const char * _Nonnull name,
                                                     llvm::Type * _Nullable type,
                                                     llvm::Constant * _Nullable initializer)
{
    GlobalVariable *ret = new GlobalVariable(*copyVariable->getParent(),
                                             nullptr != type ? type : (nullptr != initializer ? initializer->getType() : copyVariable->getType()),
                                             copyVariable->isConstant(),
                                             copyVariable->getLinkage(),
                                             initializer,
                                             name,
                                             copyVariable,
                                             copyVariable->getThreadLocalMode(),
                                             copyVariable->getType()->getAddressSpace());
    ret->copyAttributesFrom(copyVariable);
    return ret;
}


#pragma mark remove
void _setGlobalVariableInConstant(Constant *constant, bool ignoreFunction, std::vector<GlobalValue *> &list)
{
    for (GlobalValue *g : list) {
        if (g == constant) {
            return;
        }
    }
    if (auto a = dyn_cast<ConstantAggregate>(constant)) {
        for (int i = 0; i < a->getNumOperands(); ++i) {
            _setGlobalVariableInConstant(a->getOperand(i), ignoreFunction, list);
        }
    } else if (auto e = dyn_cast<ConstantExpr>(constant)) {
        if (e->getNumOperands() > 0) {
            _setGlobalVariableInConstant(e->getOperand(0), ignoreFunction, list);
        }
    } else if (auto g = dyn_cast<GlobalVariable>(constant)) {
        list.push_back(g);
    } else if (auto f = dyn_cast<Function>(constant)) {
        if (false == ignoreFunction) {
            list.push_back(f);
        }
    }
}
                       
void _removeGlobalValue(llvm::GlobalValue * _Nonnull var, bool ignoreFunction, std::map<uintptr_t, int> &tempRetainCount)
{
    std::vector<GlobalValue *> list;
    if (auto variable = dyn_cast<GlobalVariable>(var)) {
        if (variable->hasInitializer() && nullptr != variable->getInitializer()) {
            _setGlobalVariableInConstant(variable->getInitializer(), ignoreFunction, list);
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
                            removeValue(var, g);
                            var->removeDeadConstantUsers();
                            e->removeDeadConstantUsers();
                            c->removeDeadConstantUsers();
                            g->removeDeadConstantUsers();
                        } else {
                            assert("unkown");
                        }
                    } else {
                        assert("unkown");
                    }
                } else {
                    assert("unkown");
                }
            } else {
                assert("unkown");
            }
        } else {
            assert("unkown");
        }
    }
    var->eraseFromParent();
    for (GlobalValue *g : list) {
        tempRetainCount[(uintptr_t)g] = tempRetainCount[(uintptr_t)g] + 1;
    }
    for (GlobalValue *g : list) {
        int value = tempRetainCount[(uintptr_t)g];
        if (1 == value) {
            g->removeDeadConstantUsers();
            if (g->use_empty()) {
                _removeGlobalValue(g, ignoreFunction, tempRetainCount);
            } else if (isOnlyUsedByLLVM(g)) {
                _removeGlobalValue(g, ignoreFunction, tempRetainCount);
            }
            tempRetainCount.erase((uintptr_t)g);
        } else {
            tempRetainCount[(uintptr_t)g] = value - 1;
        }
    }
}

void removeGlobalValue(llvm::GlobalValue * _Nonnull var, bool ignoreFunction)
{
    std::map<uintptr_t, int> tempRetainCount;
    _removeGlobalValue(var, ignoreFunction, tempRetainCount);
}

#pragma mark modify
void replaceGlobalVariable(llvm::GlobalVariable * _Nonnull oldVar, llvm::GlobalVariable * _Nonnull newVar)
{
//    if (oldVar->getAlign() || dst->getAlign()) {
//        dst->setAlignment(std::max(oldVar->getAlign().getValueOr(oldVar->getParent()->getDataLayout().getPreferredAlign),
//                                    oldVar->getAlign().getValueOr(dst->getParent()->getDataLayout().getPreferredAlign)));
//    }
    SmallVector<DIGlobalVariableExpression *, 1> mds;
    oldVar->getDebugInfo(mds);
    for (auto md : mds) {
        newVar->addDebugInfo(md);
    }
//    src->replaceAllUsesWith(NewConstant);
    if (oldVar->hasValueHandle()) {
        ValueHandleBase::ValueIsRAUWd(oldVar, newVar);
    }
    if (oldVar->isUsedByMetadata())
      ValueAsMetadata::handleRAUW(oldVar, newVar);

    while (!oldVar->materialized_use_empty()) {
      Use &u = *oldVar->materialized_use_begin();
      if (auto *c = dyn_cast<Constant>(u.getUser())) {
        if (!isa<GlobalValue>(c)) {
          c->handleOperandChange(oldVar, newVar);
          continue;
        }
      }
      u.set(newVar);
    }
}

void replaceFuction(llvm::Function * _Nonnull oldFun, llvm::Function * _Nonnull newFun)
{
    if (oldFun->hasValueHandle()) {
        ValueHandleBase::ValueIsRAUWd(oldFun, newFun);
    }
    if (oldFun->isUsedByMetadata())
      ValueAsMetadata::handleRAUW(oldFun, newFun);

    while (!oldFun->materialized_use_empty()) {
      Use &u = *oldFun->materialized_use_begin();
      if (auto *c = dyn_cast<Constant>(u.getUser())) {
        if (!isa<GlobalValue>(c)) {
          c->handleOperandChange(oldFun, newFun);
          continue;
        }
      }
      u.set(newFun);
    }
}


std::string changeGlobalValueName(llvm::GlobalValue * _Nonnull variable, const char * _Nonnull oldName, const char * _Nonnull newName)
{
    assert(nullptr != variable);
    std::string n(variable->getName().data());
    std::string o(variable->getName().data());
    size_t vl = o.length();
    size_t ol = strlen(oldName);
    if (vl > ol + 1 &&
        0 == o.compare(vl - ol - 1, ol + 1, std::string("_") + oldName, 0, ol + 1)) {   // xx_oldName
        n = o.replace(vl - ol, ol, newName);
    } else if (vl > ol + 3 &&
               std::string::npos != o.find(std::string("$_") + oldName + ".")) {   // xx$_oldName.xx
        n.replace(o.find(std::string("$_") + oldName + ".") + 2, ol, newName);
    } else if (vl > ol + 2 &&
               std::string::npos != o.find(std::string("[") + oldName + " ")) {   // xx[oldName xx
        n.replace(o.find(std::string("[") + oldName + " ") + 1, ol, newName);
    } else if (vl > ol + 2 &&
               std::string::npos != o.find(std::string("[") + oldName + "(")) {   // xx[oldName(xx
        n.replace(o.find(std::string("[") + oldName + "(") + 1, ol, newName);
    } else if (vl > ol + 3 &&
               std::string::npos != o.find(std::string("(") + oldName + ") ")) {   // xx(oldName) xx
        n.replace(o.find(std::string("(") + oldName + ") ") + 1, ol, newName);
    }
    variable->setName(n);
    return n;
}


void changeStringValue(llvm::Module * _Nonnull module, llvm::ConstantStruct * _Nonnull var, int index, const char * _Nonnull newString)
{
    ConstantExpr *ptr = dyn_cast<ConstantExpr>(var->getOperand(index));
    if (nullptr != ptr) {
        GlobalVariable *oldVariable = dyn_cast<GlobalVariable>(ptr->getOperand(0));
        std::string oldName(oldVariable->getName().data());
        oldVariable->setName("dd_tmp_variable");
        Constant *val = ConstantDataArray::getString(var->getContext(), StringRef(newString), true);
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
                       Constant *zero = ConstantInt::get(Type::getInt32Ty(var->getContext()), 0);
                       g->handleOperandChange(exp, ConstantExpr::getInBoundsGetElementPtr(newVariable->getInitializer()->getType(), newVariable, (Constant *[]){zero, zero}));
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
        oldVariable->eraseFromParent();
    }
}

llvm::GlobalVariable * _Nonnull insertValue(llvm::Constant * _Nonnull value, llvm::GlobalVariable * _Nonnull array, int index)
{
    Constant *arr = dyn_cast<Constant>(array->getInitializer());
    if (0 <= index && index <= arr->getNumOperands()) {
        std::string oldName(array->getName().data());
        array->setName("dd_tmp_array");
        std::vector<Constant *> list;
        for (int i = 0; i <= arr->getNumOperands(); ++i) {
            if (i == index) {
                list.push_back(value);
            } else {
                list.push_back((dyn_cast<ConstantArray>(arr))->getOperand(i < index ? i : i - 1));
            }
        }
        Constant *val = ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(array->getContext()), arr->getNumOperands() + 1), list);
        GlobalVariable *newArray = new GlobalVariable(*array->getParent(),
                                                         val->getType(),
                                                         array->isConstant(),
                                                         array->getLinkage(),
                                                         val,
                                                         oldName,
                                                      array,
                                                         array->getThreadLocalMode(),
                                                         array->getAddressSpace(),
                                                         array->isExternallyInitialized());
        newArray->setAlignment(array->getAlign());
        newArray->setUnnamedAddr(array->getUnnamedAddr());
        if (array->hasSection()) {
            newArray->setSection(array->getSection());
        }
        if (array->hasComdat()) {
            newArray->setComdat(array->getComdat());
        }
        while (!array->materialized_use_empty()) {
            if (auto *exp = dyn_cast<ConstantExpr>(array->user_back())) {
                if (!exp->materialized_use_empty()) {
                    if (auto *g = dyn_cast<Constant>(exp->user_back())) {
                        g->handleOperandChange(exp, ConstantExpr::getBitCast(cast<Constant>(newArray), Type::getInt8PtrTy(array->getContext())));
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
        array->eraseFromParent();
        return newArray;
    }
    return array;
}

llvm::GlobalVariable * _Nonnull insertValue(llvm::Module * _Nonnull module, llvm::Constant * _Nonnull value, const char * _Nonnull arraySectionName, const char * _Nonnull defaultName, int index)
{
    GlobalVariable *label = getGlabalArray(module, arraySectionName);
    if (nullptr == label) {
        std::vector<Constant *> list;
        Constant *val = ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(module->getContext()), 0), list);
        label = new GlobalVariable(*module,
                                   val->getType(),
                                   false,
                                   GlobalValue::PrivateLinkage,
                                   val,
                                   defaultName);
        label->setSection(std::string(arraySectionName).append(",regular,no_dead_strip"));
        label->setAlignment(MaybeAlign(8));
        insertValue(ConstantExpr::getBitCast(cast<Constant>(label), Type::getInt8PtrTy(module->getContext())), getLlvmCompilerUsed(module), 0);
    }
    return insertValue(value, label, 0);
}

llvm::GlobalVariable * _Nonnull removeValue(llvm::GlobalVariable * _Nonnull array, int index)
{
    Constant *arr = dyn_cast<Constant>(array->getInitializer());
    if (0 <= index && index < arr->getNumOperands()) {
        std::string oldName(array->getName().data());
        array->setName("dd_tmp_array");
        std::vector<Constant *> list;
        for (int i = 0; i < arr->getNumOperands(); ++i) {
            if (i != index) {
                list.push_back((dyn_cast<ConstantArray>(arr))->getOperand(i));
            }
        }
        Constant *val = ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(array->getContext()), arr->getNumOperands() - 1), list);
        GlobalVariable *newArray = new GlobalVariable(*array->getParent(),
                                                      val->getType(),
                                                      array->isConstant(),
                                                      array->getLinkage(),
                                                      val,
                                                      oldName,
                                                      array,
                                                      array->getThreadLocalMode(),
                                                      array->getAddressSpace(),
                                                      array->isExternallyInitialized());
        newArray->setAlignment(array->getAlign());
        newArray->setUnnamedAddr(array->getUnnamedAddr());
        if (array->hasSection()) {
            newArray->setSection(array->getSection());
        }
        if (array->hasComdat()) {
            newArray->setComdat(array->getComdat());
        }
        while (!array->materialized_use_empty()) {
            if (auto *exp = dyn_cast<ConstantExpr>(array->user_back())) {
                if (!exp->materialized_use_empty()) {
                    if (auto *g = dyn_cast<Constant>(exp->user_back())) {
                        g->handleOperandChange(exp, ConstantExpr::getBitCast(cast<Constant>(newArray), Type::getInt8PtrTy(array->getContext())));
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
        array->eraseFromParent();
        return newArray;
    }
    return array;
}

llvm::GlobalVariable * _Nonnull removeValue(llvm::Constant * _Nonnull value, llvm::GlobalVariable * _Nonnull array)
{
    ConstantArray *arr = dyn_cast<ConstantArray>(array->getInitializer());
    int index = -1;
    for (int i = 0; i < arr->getNumOperands(); ++i) {
        if (value == arr->getOperand(i)->getOperand(0)) {
            index = i;
            break;
        }
    }
    if (index != -1) {
        return removeValue(array, index);
    } else {
        return array;
    }
}

#pragma mark atributes
const char * _Nonnull stringFromGlobalVariable(llvm::GlobalVariable * _Nonnull var)
{
    ConstantDataArray *array = dyn_cast<ConstantDataArray>(var->getInitializer());
    return array->getRawDataValues().data();
}
