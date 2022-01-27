//
//  DDIRChangeItem.m
//  DDToolKit
//
//  Created by dondong on 2021/12/24.
//

#import "DDIRChangeItem.h"
#import "DDIRChangeItem+Perform.h"
#include "DDIRUtil.hpp"

using namespace llvm;

@implementation DDIRChangeItem
+ (nonnull instancetype)globalVariableItemWithTargetName:(nonnull NSString *)targetName
{
    DDIRChangeItem *item = [[self alloc] init];
    item.targetName = targetName;
    item.type = DDIRChangeTypeGlobalVariable;
    return item;
}
+ (nonnull instancetype)functionItemWithTargetName:(nonnull NSString *)targetName
{
    DDIRChangeItem *item = [[self alloc] init];
    item.targetName = targetName;
    item.type = DDIRChangeTypeFunction;
    return item;
}
- (GlobalValue * _Nullable)_getValue:(llvm::Module * _Nonnull)module
{
    GlobalValue *value = nullptr;
    switch (self.type) {
        case 0:
            value = module->getGlobalVariable([self.targetName cStringUsingEncoding:NSUTF8StringEncoding]);
            break;
        case 1:
            value = module->getFunction([self.targetName cStringUsingEncoding:NSUTF8StringEncoding]);
            break;
        default:
            break;
    }
    return value;
}
@end

@implementation DDIRChangeItem(Perform)
- (void)performChange:(llvm::Module * _Nonnull)module
{

}
@end

@implementation DDIRRemoveChangeItem
- (void)performChange:(llvm::Module * _Nonnull)module
{
    GlobalValue *value = [self _getValue:module];
    if (nullptr != value) {
        removeGlobalValue(value);
    }
}
@end

@implementation DDIRNameChangeItem
+ (nonnull instancetype)globalVariableItemWithTargetName:(nonnull NSString *)targetName newName:(nonnull NSString *)newName
{
    DDIRNameChangeItem *item = [self globalVariableItemWithTargetName:targetName];
    item.name = newName;
    return item;
}
+ (nonnull instancetype)functionItemWithTargetName:(nonnull NSString *)targetName newName:(nonnull NSString *)newName
{
    DDIRNameChangeItem *item = [self functionItemWithTargetName:targetName];
    item.name = newName;
    return item;
}
- (void)performChange:(llvm::Module * _Nonnull)module
{
    GlobalValue *value = [self _getValue:module];
    if (nullptr != value) {
        value->setName([self.name cStringUsingEncoding:NSUTF8StringEncoding]);
    }
}
@end

@implementation DDIRLinkageChangeItem
- (void)performChange:(llvm::Module * _Nonnull)module
{
    GlobalValue *value = [self _getValue:module];
    if (nullptr != value) {
        value->setLinkage((GlobalValue::LinkageTypes)self.newLinkage);
    }
}
@end

@implementation DDIRRemoveDefineChangeItem
- (void)performChange:(llvm::Module * _Nonnull)module
{
    switch (self.type) {
        case 0:
        {
            GlobalVariable *var = module->getGlobalVariable([self.targetName cStringUsingEncoding:NSUTF8StringEncoding]);
            if (nullptr == var || false == var->hasInitializer()) return;
            var->setName("temp_var");
            GlobalVariable *newVar = new GlobalVariable(*module,
                                                        var->getInitializer()->getType(),
                                                        var->isConstant(),
                                                        GlobalValue::ExternalLinkage,
                                                        nullptr,
                                                        [self.targetName cStringUsingEncoding:NSUTF8StringEncoding]);
            replaceGlobalVariable(var, newVar);
            var->eraseFromParent();
        }
            break;
        case 1:
        {
            Function *fun = module->getFunction([self.targetName cStringUsingEncoding:NSUTF8StringEncoding]);
            if (nullptr == fun || 0 == fun->size()) return;
            fun->setName("temp_function");
            Function *newFun = Function::Create(fun->getFunctionType(), GlobalValue::ExternalLinkage, [self.targetName cStringUsingEncoding:NSUTF8StringEncoding], module);
            replaceFuction(fun, newFun);
            fun->eraseFromParent();
        }
            break;
        default:
            break;
    }
}
@end

@implementation DDIRStaticVariableChangeItem
+ (nonnull instancetype)globalVariableItemWithTargetName:(nonnull NSString *)targetName valueName:(nonnull NSString *)valueName
{
    DDIRStaticVariableChangeItem *item = [self globalVariableItemWithTargetName:targetName];
    item.valueName = valueName;
    return item;
}
- (void)performChange:(llvm::Module * _Nonnull)module
{
    if (DDIRChangeTypeGlobalVariable == self.type) {
        GlobalVariable *var = module->getGlobalVariable([self.targetName cStringUsingEncoding:NSUTF8StringEncoding]);
        if (nullptr != var && var->hasInitializer() && 1 == var->getInitializer()->getNumOperands()) {
            GlobalVariable *v = dyn_cast<GlobalVariable>(var->getInitializer()->getOperand(0));
            v->setName([self.valueName cStringUsingEncoding:NSUTF8StringEncoding]);
            v->setLinkage(GlobalValue::ExternalLinkage);
            v->setDSOLocal(false);
            var->setName("temp_variable");
            GlobalVariable *newVar = new GlobalVariable(*module,
                                                        var->getType()->getElementType(),
                                                        var->isConstant(),
                                                        GlobalValue::ExternalLinkage,
                                                        nullptr,
                                                        [self.targetName cStringUsingEncoding:NSUTF8StringEncoding]);
            replaceGlobalVariable(var, newVar);
            var->eraseFromParent();
        }
    }
}
@end

@implementation DDIRChangeItemSet
+ (nonnull instancetype)itemSetWithItems:(nonnull NSArray<DDIRChangeItem *> *)items
{
    DDIRChangeItemSet *item = [self globalVariableItemWithTargetName:@""];
    item.items = items;
    return item;
}

- (void)performChange:(llvm::Module * _Nonnull)module
{
    for (DDIRChangeItem *it in self.items) {
        [it performChange:module];
    }
}
@end
