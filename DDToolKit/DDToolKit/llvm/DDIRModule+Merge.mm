//
//  DDIRModule+Merge.m
//  DDToolKit
//
//  Created by dondong on 2021/10/21.
//

#import "DDIRModule+Merge.h"
#import "DDIRModule+Private.h"
#import "DDIRChangeItem+Perform.h"
#import "DDCommonDefine.h"
#import "DDIRUtil.h"
#import "DDIRUtil+Objc.h"
#import <objc/runtime.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/Transforms/Utils/Cloning.h>
#include <llvm/IR/Constants.h>
#include <llvm/Linker/Linker.h>
#include <llvm/Transforms/IPO/Internalize.h>

using namespace llvm;
#define ConfigurationKey_ControlId    @"control_id"
#define ConfigurationKey_ChangeRecord @"change_record"
#define ConfigurationKey_LoadFuction  @"load_fun"
#define ConfigurationKey_InitFuction  @"init_fun"
#define ConfigurationKey_Class(index)    ([NSString stringWithFormat:@"class_%d", (int)index])
#define ConfigurationKey_Category(index) ([NSString stringWithFormat:@"category_%d", (int)index])

#define ModuleReferenceFunctions "reference.functions"
#define ModuleReferenceVarables  "reference.varables"
#define GetAppendValue(str) ((unsigned long)str.hash % 10000)

@interface DDIRModuleMergeInfo()
@property(nonatomic,strong,readwrite,nonnull) NSString *target;
@end

@implementation DDIRModule(Merge)
+ (nonnull DDIRChangeReplaceRecord *)mergeIRFiles:(nonnull NSArray<NSString *> *)pathes withControlId:(UInt32)controlId toIRFile:(nonnull NSString *)outputPath
{
    NSMutableArray *array = [NSMutableArray array];
    for (NSString *path in pathes) {
        DDIRModulePath *p = [[DDIRModulePath alloc] init];
        p.path = path;
        [array addObject:p];
    }
    return [self mergeIRModules:array withControlId:controlId toIRFile:outputPath];
}

+ (nonnull DDIRChangeReplaceRecord *)mergeIRModules:(nonnull NSArray<DDIRModulePath *> *)moudules withControlId:(UInt32)controlId toIRFile:(nonnull NSString *)outputPath
{
    NSMutableDictionary *changeRecords = [NSMutableDictionary dictionary];
    NSMutableArray<DDIRModule *> *moduleList = [NSMutableArray array];
    for (DDIRModulePath *m in moudules) {
        [moduleList addObject:[DDIRModule moduleFromModulePath:m]];
    }
    NSMutableDictionary *mergeConfiguration = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeClassList     = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeCategoryList  = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeProtocolList  = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeProtocolMap   = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeFunctionList  = [NSMutableDictionary dictionary];
    NSMutableDictionary *initFuncList       = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeStaticVarList = [NSMutableDictionary dictionary];
    [mergeConfiguration setObject:@(controlId) forKey:ConfigurationKey_ControlId];
    [mergeConfiguration setObject:initFuncList forKey:ConfigurationKey_InitFuction];
    [mergeConfiguration setObject:changeRecords forKey:ConfigurationKey_ChangeRecord];
    for (int i = 0; i < moduleList.count; ++i) {
        DDIRModule *module = moduleList[i];
        NSMutableArray *changeitems = [NSMutableArray array];
        [changeRecords setObject:changeitems forKey:module.path];
        [mergeConfiguration setObject:module.path forKey:@(i)];
        [mergeConfiguration setObject:[NSMutableArray array] forKey:ConfigurationKey_Class(i)];
        [mergeConfiguration setObject:[NSMutableArray array] forKey:ConfigurationKey_Category(i)];
        [initFuncList setObject:[NSMutableArray array] forKey:@(i)];
        NSString *appendStr = [NSString stringWithFormat:@"%lu", GetAppendValue(module.path)];
        NSMutableArray<NSArray<NSString *> *> *classChangeList     = [NSMutableArray array];
        NSMutableArray<NSArray<NSString *> *> *categoryChangeList  = [NSMutableArray array];
        NSMutableArray<NSArray<NSString *> *> *protocolChangeList  = [NSMutableArray array];
        NSMutableArray<NSArray<NSString *> *> *functionChangeList  = [NSMutableArray array];
        NSMutableArray<NSArray<NSString *> *> *staticVarChangeList = [NSMutableArray array];
        DDIRModuleData *data = [module getData];
        for (DDIRObjCClass *c in data.objcClassList) {
            if (nil == [mergeClassList objectForKey:c.className]) {
                [mergeClassList setObject:@[[DDIRModuleMergeInfo infoWithTarget:c.className index:i]].mutableCopy forKey:c.className];
                [mergeConfiguration setObject:module.path forKey:c.className];   // record module of base class
            } else {
                NSString *newName = [c.className stringByAppendingString:appendStr];
                [classChangeList addObject:@[c.className, newName]];
                [[mergeClassList objectForKey:c.className] addObject:[DDIRModuleMergeInfo infoWithTarget:newName index:i]];
            }
        }
        for (DDIRObjCCategory *c in data.objcCategoryList) {
            if (nil == [mergeCategoryList objectForKey:c.cls.className]) {
                [mergeCategoryList setObject:@[[DDIRModuleMergeInfo infoWithTarget:c.categoryName index:i]].mutableCopy forKey:c.cls.className];
                [mergeConfiguration setObject:module.path forKey:c.categoryName];   // record module of base category
            } else {
                NSString *newName = [c.categoryName stringByAppendingString:appendStr];
                [categoryChangeList addObject:@[c.cls.className, c.categoryName, newName]];
                [[mergeCategoryList objectForKey:c.cls.className] addObject:[DDIRModuleMergeInfo infoWithTarget:newName index:i]];
            }
        }
        for (DDIRObjCProtocol *p in data.objcProtocolList) {
            if (nil == [mergeProtocolList objectForKey:p.protocolName]) {
                [mergeProtocolList setObject:@[p.protocolName].mutableCopy forKey:p.protocolName];
                [mergeProtocolMap setObject:p.protocolName forKey:p.protocolName];
                [mergeConfiguration setObject:module.path forKey:p.protocolName];   // record module of base protocol
            } else {
                NSString *newName = [p.protocolName stringByAppendingString:appendStr];
                [protocolChangeList addObject:@[p.protocolName, newName]];
                [[mergeProtocolList objectForKey:p.protocolName] addObject:newName];
                [mergeProtocolMap setObject:p.protocolName forKey:newName];
            }
        }
        for (DDIRFunction *f in data.ctorFunctionList) {
            [[initFuncList objectForKey:@(i)] addObject:f.name];
        }
        for (DDIRFunction *f in data.functionList) {
            if (nil == [mergeFunctionList objectForKey:f.name]) {
                [mergeFunctionList setObject:@[[DDIRModuleMergeInfo infoWithTarget:f.name index:i]].mutableCopy forKey:f.name];
                [mergeConfiguration setObject:module.path forKey:f.name];   // record module of base function
            } else {
                NSString *newName = [f.name stringByAppendingString:appendStr];
                [[mergeFunctionList objectForKey:f.name] addObject:[DDIRModuleMergeInfo infoWithTarget:newName index:i]];
                [functionChangeList addObject:@[f.name, newName]];
            }
        }
        for (DDIRGlobalVariable *v in data.staticVariableList) {
            if (nil == [mergeStaticVarList objectForKey:v.name]) {
                [mergeStaticVarList setObject:@[[DDIRModuleMergeInfo infoWithTarget:v.name index:i]].mutableCopy forKey:v.name];
                [mergeConfiguration setObject:module.path forKey:v.name];   // record module of base variable
            } else {
                NSString *newName = [v.name stringByAppendingString:appendStr];
                [[mergeStaticVarList objectForKey:v.name] addObject:[DDIRModuleMergeInfo infoWithTarget:newName index:i]];
                [staticVarChangeList addObject:@[v.name, newName]];
            }
        }
        [module executeChangesWithBlock:^(DDIRModule * _Nullable m) {
            for (NSArray *arr in protocolChangeList) {
                [m replaceObjcProtocol:arr[0] withNewComponentName:arr[1]];
            }
            for (NSArray *arr in categoryChangeList) {
                NSArray *r = [m replaceCategory:arr[1] forObjcClass:arr[0] withNewComponentName:arr[2]];
                [changeitems addObjectsFromArray:r];
            }
            for (NSArray *arr in classChangeList) {
                NSArray *r = [m replaceObjcClass:arr[0] withNewComponentName:arr[1]];
                [changeitems addObjectsFromArray:r];
            }
            // keep all function, avoid not referenced declare function be deleted
            std::vector<Constant *> functionList;
            for (DDIRFunction *function in data.functionList) {
                Function *fun = m.module->getFunction([function.name cStringUsingEncoding:NSUTF8StringEncoding]);
                functionList.push_back(ConstantExpr::getBitCast(fun, Type::getInt8PtrTy(m.module->getContext())));
            }
            new GlobalVariable(*m.module,
                               ArrayType::get(Type::getInt8PtrTy(m.module->getContext()), functionList.size()),
                               false,
                               GlobalValue::AppendingLinkage,
                               ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(m.module->getContext()), functionList.size()), functionList),
                               ModuleReferenceFunctions);
            for (NSArray *arr in functionChangeList) {
                [m replaceFunction:arr[0] withNewComponentName:arr[1]];
                [changeitems addObject:[DDIRNameChangeItem functionItemWithTargetName:arr[0] newName:arr[1]]];
            }
            // keep all static variable, avoid not referenced external variable be deleted
            std::vector<Constant *> staticVarList;
            for (DDIRGlobalVariable *variable in data.staticVariableList) {
                GlobalVariable *var = m.module->getGlobalVariable([variable.name cStringUsingEncoding:NSUTF8StringEncoding]);
//                staticVarList.push_back(ConstantExpr::getBitCast(var, Type::getInt8PtrTy(m.module->getContext())));
                if ([DDIRUtil isExternalStaticVariable:var]) {
//                    if (var->getInitializer()->getType()->isPointerTy()) {
//                        GlobalVariable *valueVar = dyn_cast<GlobalVariable>(var->getInitializer()->getOperand(0));
//                        NSString *valueName = [NSString stringWithFormat:@"%s", valueVar->getName().data()];
//                        if (false == [self _isSpecailName:valueName]) {
//                            NSString * specialName = [self _getSpecialName];
//                            GlobalVariable *newValueVar = new GlobalVariable(*m.module,
//                                                                             valueVar->getInitializer()->getType(),
//                                                                             valueVar->isConstant(),
//                                                                             GlobalValue::ExternalLinkage,
//                                                                             nullptr,
//                                                                             [specialName cStringUsingEncoding:NSUTF8StringEncoding]);
//                            [DDIRUtil replaceGlobalVariable:valueVar with:newValueVar];
//                            [DDIRUtil removeGlobalValue:valueVar inModule:m.module];
//                            [changeitems addObject:[DDIRStaticVariableChangeItem globalVariableItemWithTargetName:variable.name valueName:specialName]];
//                        } else {
//                            [changeitems addObject:[DDIRRemoveDefineChangeItem globalVariableItemWithTargetName:variable.name]];
//                        }
//                    } else {
//                        [changeitems addObject:[DDIRRemoveDefineChangeItem globalVariableItemWithTargetName:variable.name]];
//                    }
                    [changeitems addObject:[DDIRRemoveDefineChangeItem globalVariableItemWithTargetName:variable.name]];
                }
            }
//            new GlobalVariable(*m.module,
//                               ArrayType::get(Type::getInt8PtrTy(m.module->getContext()), staticVarList.size()),
//                               false,
//                               GlobalValue::AppendingLinkage,
//                               ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(m.module->getContext()), staticVarList.size()), staticVarList),
//                               ModuleReferenceVarables);
            for (NSArray *arr in staticVarChangeList) {
                GlobalVariable *var = m.module->getGlobalVariable([arr[0] cStringUsingEncoding:NSUTF8StringEncoding]);
                var->setName([arr[1] cStringUsingEncoding:NSUTF8StringEncoding]);
                if ([DDIRUtil isExternalStaticVariable:var]) {
                    [changeitems addObject:[DDIRNameChangeItem globalVariableItemWithTargetName:arr[0] newName:arr[1]]];
                }
            }
        }];
    }
    
    NSMutableArray *pathes = [NSMutableArray array];
    for (DDIRModulePath *m in moudules) {
        [pathes addObject:m.path];
    }
    [DDIRModule linkIRFiles:pathes toIRFile:outputPath];
    DDIRModule *module = [DDIRModule moduleFromPath:outputPath];
    
    [module executeChangesWithBlock:^(DDIRModule * _Nullable m) {
        GlobalVariable *funVar =  m.module->getGlobalVariable(ModuleReferenceFunctions);
        if (nullptr != funVar) {
            funVar->eraseFromParent();
        }
//        m.module->getGlobalVariable(ModuleReferenceFunctions)->eraseFromParent();
//        m.module->getGlobalVariable(ModuleReferenceVarables)->eraseFromParent();
        // protocol
        for (NSString *name in mergeProtocolList.allKeys) {
            NSArray *nameList = [mergeProtocolList objectForKey:name];
            [m _mergeProtocols:nameList withMap:mergeProtocolMap];
        }
        // class
        for (NSString *name in mergeClassList.allKeys) {
            NSArray *clss = [mergeClassList objectForKey:name];
            [m _mergeClassInfos:clss configuration:mergeConfiguration];
        }
        for (int i = 0; i < moduleList.count; ++i) {
            NSString *key = ConfigurationKey_Class(i);
            NSMutableArray *arr = [mergeConfiguration objectForKey:key];
            if (arr.count == 0) {
                continue;
            }
            std::vector<Constant *> list;
            for (NSValue *val in arr) {
                GlobalVariable *v = (GlobalVariable *)[val pointerValue];
                list.push_back(v->getInitializer());
            }
            std::vector<Type *> types;
            StructType *mapType = [m _getClassMapType];
            types.push_back(Type::getInt32Ty(m.module->getContext()));
            types.push_back(Type::getInt32Ty(m.module->getContext()));
            types.push_back(Type::getInt32Ty(m.module->getContext()));
            types.push_back(ArrayType::get(mapType, list.size()));
            std::vector<Constant *> datas;
            datas.push_back(ConstantInt::get(Type::getInt32Ty(m.module->getContext()), controlId));
            datas.push_back(ConstantInt::get(Type::getInt32Ty(m.module->getContext()), i));
            datas.push_back(ConstantInt::get(Type::getInt32Ty(m.module->getContext()), list.size()));
            datas.push_back(ConstantArray::get(ArrayType::get(mapType, list.size()), list));
            Constant *value = ConstantStruct::get(StructType::get(m.module->getContext(), types), datas);
            GlobalVariable *item = new GlobalVariable(*m.module,
                                                      value->getType(),
                                                      false,
                                                      GlobalValue::InternalLinkage,
                                                      value,
                                                      [[NSString stringWithFormat:@"_DD_OBJC_Class_MAP_$_%d", controlId] cStringUsingEncoding:NSUTF8StringEncoding]);
            item->setSection("__DATA, __objc_const");
            item->setAlignment(MaybeAlign(8));
            [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(item), Type::getInt8PtrTy(m.module->getContext()))
                    toGlobalArray:[DDIRUtil getLlvmCompilerUsedInModule:m.module]
                               at:0
                         inModule:m.module];
            [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(item), Type::getInt8PtrTy(m.module->getContext()))
         toGlobalArrayWithSection:[[NSString stringWithFormat:@"__DATA,%@", DDDefaultClsMapSection] cStringUsingEncoding:NSUTF8StringEncoding]
                      defaultName:"OBJC_LABEL_CLASS_MAP_$"
                         inModule:m.module];
            
            for (NSValue *val in arr) {
                GlobalVariable *v = (GlobalVariable *)[val pointerValue];
                v->eraseFromParent();
            }
        }
        GlobalVariable *control = [m _addControlVariable:[NSString stringWithFormat:@"Control_$_dd_%d", controlId] controlId:controlId section:[NSString stringWithFormat:@"__DATA,%@", DDControlSection]];
        // load
        [m _handleLoadFunctionWithControlVariable:control configuration:mergeConfiguration];
        // category
        for (NSString *name in mergeCategoryList.allKeys) {
            NSArray *cats = [mergeCategoryList objectForKey:name];
            if (cats.count > 0) {
                [m _mergeCategoryInfos:cats forClass:name withSize:pathes.count controlVariable:control configuration:mergeConfiguration];
            }
        }
        // function
        for (NSString *name in mergeFunctionList.allKeys) {
            NSArray *funs = [mergeFunctionList objectForKey:name];
            if (funs.count > 0) {
                [m _mergeFunctions:funs withControl:control configuration:mergeConfiguration];
            }
        }
        [m _handleInitFunctionWithControlVariable:control configuration:mergeConfiguration];
        // static variable
        Function *varFun = [m _mergeStaticVariables:mergeStaticVarList withControl:control count:pathes.count configuration:mergeConfiguration];
        std::vector<Constant *> varFunList;
        varFunList.push_back(ConstantExpr::getBitCast(varFun, Type::getInt8PtrTy(m.module->getContext())));
        GlobalVariable *varFunLabel = new GlobalVariable(*m.module,
                                                         ArrayType::get(Type::getInt8PtrTy(m.module->getContext()), 1),
                                                         false,
                                                         GlobalValue::InternalLinkage,
                                                         ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(m.module->getContext()), 1), varFunList),
                                                         "dd_init_function_label");
        varFunLabel->setSection([[NSString stringWithFormat:@"__DATA,%@,regular,no_dead_strip", DDInitFunctionSection] cStringUsingEncoding:NSUTF8StringEncoding]);
        varFunLabel->setAlignment(MaybeAlign(8));
        [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(varFunLabel), Type::getInt8PtrTy(m.module->getContext()))
            toGlobalArray:[DDIRUtil getLlvmCompilerUsedInModule:m.module]
                       at:0
                 inModule:m.module];
    }];
    return changeRecords;
}

#pragma mark change
- (nonnull DDIRChangeDeclareRecord *)extractObjcDataAndFunctionDeclaration
{
    NSMutableDictionary *changeRecords = [NSMutableDictionary dictionary];std::vector<Function *> defineFunctionList;
    std::vector<Function *> declareFunctionList;
    for (Function &fun : self.module->getFunctionList()) {
        if (fun.getBasicBlockList().size() > 0) {
            defineFunctionList.push_back(std::addressof(fun));
        } else {
            declareFunctionList.push_back(std::addressof(fun));
        }
    }
    NSMutableArray *changeFunctionList = [NSMutableArray array];
    [changeRecords setObject:changeFunctionList forKey:DDIRReplaceResultFunctionKey];
    for (Function *fun : defineFunctionList) {
        NSString *name = [NSString stringWithFormat:@"%s", fun->getName().data()];
        fun->setName("temp_function");
        Function *newFun = Function::Create(fun->getFunctionType(), GlobalValue::ExternalLinkage, [name cStringUsingEncoding:NSUTF8StringEncoding], self.module);
        [DDIRUtil replaceFuction:fun with:newFun];
        fun->eraseFromParent();
        [changeFunctionList addObject:name];
    }
    for (Function *fun : declareFunctionList) {
        fun->eraseFromParent();
    }
    bool shouldContinue = true;
    while(shouldContinue) {
        shouldContinue = false;
        for (GlobalVariable &var : self.module->getGlobalList()) {
            if (false == var.hasSection() ||
                (0 != strncmp(var.getSection().data(), "llvm.", 5) &&
                 0 != strncmp(var.getSection().data(), "__DATA,__objc_classlist", 23) &&
                 0 != strncmp(var.getSection().data(), "__DATA,__objc_catlist", 21) &&
                 0 != strncmp(var.getSection().data(), "__DATA,__objc_nlclslist", 23) &&
                 0 != strncmp(var.getSection().data(), "__DATA,__objc_nlcatlist", 23) &&
                 0 != strncmp(var.getSection().data(), "__DATA,__objc_protolist", 23))) {
                if (0 != strcmp(var.getName().data(), "llvm.global_ctors")) {
                    var.removeDeadConstantUsers();
                    if ((var.getNumUses() == 0 || [DDIRUtil onlyUsedByLLVM:std::addressof(var)]) /* no used by code */ &&
                        false == [DDIRUtil isExternalStaticVariableDeclaration:std::addressof(var)]/* staitc variable may not be used, but it should be remained */) {
                        [DDIRUtil removeGlobalValue:std::addressof(var) ignoreFunction:true inModule:self.module];
                        shouldContinue = true;
                        break;
                    }
                }
            }
        }
    }
//    std::vector<GlobalVariable *> staticVariableList;
//    for (GlobalVariable &var : self.module->getGlobalList()) {
//        if (true == [DDIRUtil isExternalStaticVariable:std::addressof(var)]) {
//            staticVariableList.push_back(std::addressof(var));
//        }
//    }
//    NSMutableArray *changeVariableList = [NSMutableArray array];
//    [changeRecords setObject:changeVariableList forKey:DDIRReplaceResultGlobalVariableKey];
//    for (GlobalVariable *var : staticVariableList) {
//        NSString *name = [NSString stringWithFormat:@"%s", var->getName().data()];
//        var->setName("temp_var");
//        GlobalVariable *newVar = new GlobalVariable(*self.module,
//                                                    var->getInitializer()->getType(),
//                                                    true,
//                                                    GlobalValue::ExternalLinkage,
//                                                    nullptr,
//                                                    [name cStringUsingEncoding:NSUTF8StringEncoding]);
//        [DDIRUtil replaceGlobalVariable:var with:newVar];
//        var->eraseFromParent();
//        [changeVariableList addObject:name];
//    }
    while (self.module->named_metadata_begin() != self.module->named_metadata_end()) {
        auto node = self.module->named_metadata_begin();
        self.module->eraseNamedMetadata(std::addressof(*node));
    }
    [self mergeObjcData];
    return [NSDictionary dictionaryWithDictionary:changeRecords];
}

- (void)remeveObjcData
{
    bool should = true;
    std::vector<GlobalVariable *> referenceList;
    std::vector<GlobalVariable *> varList;
    for (GlobalVariable &var : self.module->getGlobalList()) {
        if (var.hasSection() &&
            (0 == strncmp(var.getSection().data(), "__DATA,__objc_classrefs", 23) ||
             0 == strncmp(var.getSection().data(), "__DATA,__objc_superrefs", 23))) {
            referenceList.push_back(std::addressof(var));
        }
        if (var.hasSection() &&
             0 == strncmp(var.getSection().data(), "__DATA, __objc_ivar", 19)) {
            varList.push_back(std::addressof(var));
        }
    }
    NSMutableDictionary *remap = [NSMutableDictionary dictionary];
    for (GlobalVariable *var : referenceList) {
        if (var->hasInitializer()) {
            if (auto cls = dyn_cast<GlobalVariable>(var->getInitializer())) {
                if (cls->hasInitializer()) {
                    NSValue *key = [NSValue valueWithPointer:cls];
                    if (nil == [remap objectForKey:key]) {
                        NSString *oldName = [NSString stringWithFormat:@"%s", cls->getName().data()];
                        cls->setName([[NSString stringWithFormat:@"%@.tmp", oldName] cStringUsingEncoding:NSUTF8StringEncoding]);
                        GlobalVariable *newCls = new GlobalVariable(*self.module,
                                                                    [DDIRUtil getStructType:IR_Objc_ClassTypeName inModule:self.module],
                                                                    false,
                                                                    GlobalValue::ExternalLinkage,
                                                                    nullptr,
                                                                    [oldName cStringUsingEncoding:NSUTF8StringEncoding]);
                        var->setInitializer(newCls);
                        [remap setObject:[NSValue valueWithPointer:newCls] forKey:[NSValue valueWithPointer:cls]];
                    } else {
                        GlobalVariable *newCls = (GlobalVariable *)[[remap objectForKey:key] pointerValue];
                        var->setInitializer(newCls);
                    }
                }
            }
        }
    }
    for (GlobalVariable *var : varList) {
        if (var->hasInitializer()) {
            if (auto constant = dyn_cast<Constant>(var->getInitializer())) {
                NSString *oldName = [NSString stringWithFormat:@"%s", var->getName().data()];
                var->setName([[NSString stringWithFormat:@"%@.tmp", oldName] cStringUsingEncoding:NSUTF8StringEncoding]);
                GlobalVariable *newVar = new GlobalVariable(*self.module,
                                                            constant->getType(),
                                                            false,
                                                            GlobalValue::ExternalLinkage,
                                                            nullptr,
                                                            [oldName cStringUsingEncoding:NSUTF8StringEncoding]);
                [DDIRUtil replaceGlobalVariable:var with:newVar];
                var->eraseFromParent();
            }
        }
    }
    while(should) {
        should = false;
        for (GlobalVariable &var : self.module->getGlobalList()) {
            if ((var.hasSection() &&
                (0 == strncmp(var.getSection().data(), "__DATA,__objc_classlist", 23) ||
                 0 == strncmp(var.getSection().data(), "__DATA,__objc_catlist", 21) ||
                 0 == strncmp(var.getSection().data(), "__DATA,__objc_nlclslist", 23) ||
                 0 == strncmp(var.getSection().data(), "__DATA,__objc_nlcatlist", 23) ||
                 0 == strncmp(var.getSection().data(), "__DATA,__objc_protolist", 23))) ||
                0 == strcmp(var.getName().data(), "llvm.global_ctors")) {
                [DDIRUtil removeGlobalValue:std::addressof(var) ignoreFunction:true inModule:self.module];
                should = true;
                break;
            }
        }
    }
    std::vector<GlobalVariable *> llvmList;
    for (GlobalVariable &var : self.module->getGlobalList()) {
        if (var.hasSection() &&
            0 == strncmp(var.getSection().data(), "llvm.", 5)) {
            if (var.hasInitializer() && 0 == var.getInitializer()->getNumOperands()) {
                llvmList.push_back(std::addressof(var));
            }
        }
    }
    for (GlobalVariable *var : llvmList) {
        var->eraseFromParent();
    }
    for (Function &fun : self.module->getFunctionList()) {
        if (0 == strcmp(fun.getName().data(), "__Block_byref_object_copy_") ||
            0 == strcmp(fun.getName().data(), "__Block_byref_object_dispose_")) {
            continue;
        }
        if (fun.getLinkage() == GlobalValue::InternalLinkage) {
            fun.setLinkage(GlobalValue::ExternalLinkage);
        }
    }
}

- (void)mergeObjcData
{
    NSMutableDictionary<NSString *, NSValue *> *clsDic = [NSMutableDictionary dictionary];
    Module::GlobalListType &globallist = self.module->getGlobalList();
    for (GlobalVariable &v : globallist) {
        if (v.hasSection()) {
            if (0 == strncmp(v.getSection().data(), "__DATA,__objc_classlist", 23)) {
                ConstantArray *arr = dyn_cast<ConstantArray>(v.getInitializer());
                for (int i = 0; i < arr->getNumOperands(); ++i) {
                    GlobalVariable *cls = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0));
                    [clsDic setObject:[NSValue valueWithPointer:cls] forKey:[DDIRUtil getObjcClassName:cls]];
                }
            }
        }
    }
    GlobalVariable *catSection = [DDIRUtil getGlabalArrayWithSection:"__DATA,__objc_catlist" inModule:self.module];
    if (nullptr != catSection) {
        int currentIndex = 0;
        NSMutableDictionary<NSString *, NSValue *> *catDic = [NSMutableDictionary dictionary];
        do {
            catSection = [DDIRUtil getGlabalArrayWithSection:"__DATA,__objc_catlist" inModule:self.module];
            ConstantArray *arr = dyn_cast<ConstantArray>(catSection->getInitializer());
            if (currentIndex < arr->getNumOperands()) {
                GlobalVariable *cat = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(currentIndex))->getOperand(0));
                NSString *clsName = [DDIRUtil getObjcClassNameFromCategory:cat];
                if (nil != [clsDic objectForKey:clsName]) {
                    GlobalVariable *cls = (GlobalVariable *)[[clsDic objectForKey:clsName] pointerValue];
                    bool hasClsLoad = _isObjcClassHasLoad(cls);
                    bool hasCatLoad = _isObjcCategoryHasLoad(cat);
                    _addObjcCategoryToClass(cat, cls, (hasClsLoad && hasCatLoad));
                    catSection = [DDIRUtil removeValueAtIndex:currentIndex
                                              fromGlobalArray:catSection
                                                     inModule:self.module];
                    _clearObjcCategory(cat);
                    if (true == hasCatLoad) {
                        [DDIRUtil insertValue:ConstantExpr::getBitCast(cls, Type::getInt8PtrTy(cls->getContext()))
                     toGlobalArrayWithSection:"__DATA,__objc_nlclslist"
                                  defaultName:"OBJC_LABEL_NONLAZY_CLASS_$"
                                     inModule:cls->getParent()];
                    }
                    
                } else if (nil != [catDic objectForKey:clsName]) {
                    GlobalVariable *baseCat = (GlobalVariable *)[[catDic objectForKey:clsName] pointerValue];
                    bool hasBaseCatLoad = _isObjcCategoryHasLoad(baseCat);
                    bool hasCatLoad     = _isObjcCategoryHasLoad(cat);
                    baseCat = _addObjcCategoryToCategory(cat, baseCat, (hasBaseCatLoad && hasCatLoad));
                    catSection = [DDIRUtil removeValueAtIndex:currentIndex
                                              fromGlobalArray:catSection
                                                     inModule:self.module];
                    [catDic setObject:[NSValue valueWithPointer:baseCat] forKey:clsName];
                    _clearObjcCategory(cat);
                    if (true == hasCatLoad) {
                        [DDIRUtil insertValue:ConstantExpr::getBitCast(baseCat, Type::getInt8PtrTy(baseCat->getContext()))
                     toGlobalArrayWithSection:"__DATA,__objc_nlcatlist"
                                  defaultName:"OBJC_LABEL_NONLAZY_CATEGORY_$"
                                     inModule:baseCat->getParent()];
                    }
                    
                } else {
                    [catDic setObject:[NSValue valueWithPointer:cat] forKey:clsName];
                    currentIndex++;
                }
            } else {
                break;
            }
        } while (true);
    }
}

- (GlobalVariable * _Nonnull)_addControlVariable:(nonnull NSString *)name controlId:(UInt32)controlId section:(nonnull NSString *)section
{
    std::vector<Type *> typeList;
    typeList.push_back(Type::getInt32Ty(self.module->getContext()));
    typeList.push_back(Type::getInt32Ty(self.module->getContext()));
    StructType *type = StructType::get(self.module->getContext(), typeList);
    std::vector<Constant *> data;
    data.push_back(Constant::getIntegerValue(Type::getInt32Ty(self.module->getContext()), APInt(32, controlId, false)));
    data.push_back(Constant::getIntegerValue(Type::getInt32Ty(self.module->getContext()), APInt(32, 0, false)));
    GlobalVariable *ret = new GlobalVariable(*self.module,
                                             type,
                                             false,
                                             GlobalValue::InternalLinkage,
                                             ConstantStruct::get(type, data),
                                             [name cStringUsingEncoding:NSUTF8StringEncoding]);
    ret->setAlignment(MaybeAlign(8));
    ret->setSection([section cStringUsingEncoding:NSUTF8StringEncoding]);
    [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(ret), Type::getInt8PtrTy(self.module->getContext()))
            toGlobalArray:[DDIRUtil getLlvmCompilerUsedInModule:self.module]
                       at:0
                 inModule:self.module];
    return ret;
}

- (void)synchronzieChangees:(nonnull NSArray<DDIRChangeItem *> *)items
{
    for (DDIRChangeItem *it in items) {
        [it performChange:self.module];
    }
//    NSDictionary *funRecord = [result objectForKey:DDIRReplaceResultFunctionKey];
//    NSDictionary *varRecord = [result objectForKey:DDIRReplaceResultGlobalVariableKey];
//    for (GlobalVariable &var : self.module->getGlobalList()) {
//        NSString *name = [NSString stringWithFormat:@"%s", var.getName().data()];
//        NSString *newName = [varRecord objectForKey:name];
//        if (nil != newName && !([name hasPrefix:@"OBJC_CLASS_$_"] || [name hasPrefix:@"OBJC_METACLASS_$_"])) {
//            var.setName([newName cStringUsingEncoding:NSUTF8StringEncoding]);
//        }
//    }
//    for (Function &fun : self.module->getFunctionList()) {
//        NSString *name = [NSString stringWithFormat:@"%s", fun.getName().data()];
//        NSString *newName = [funRecord objectForKey:name];
//        if (nil != newName) {
//            fun.setName([newName cStringUsingEncoding:NSUTF8StringEncoding]);
//        }
//    }
}

#pragma mark private

- (void)_mergeClassInfos:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos configuration:(nonnull NSMutableDictionary *)configuration
{
    // add load function to configuration
    for (int i = 0; i < infos.count; ++i) {
        GlobalVariable *cls = [DDIRUtil getObjcClass:infos[i].target inModule:self.module];
        assert(nullptr != cls);
        GlobalVariable *metaCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(0));
        assert(nullptr != metaCls);
        GlobalVariable *metaRo = dyn_cast<GlobalVariable>(metaCls->getInitializer()->getOperand(4));
        assert(nullptr != metaRo);
        if (isNullValue(metaRo, 5)) {
            GlobalVariable *val = getValue(metaRo, 5);
            uint32_t count = (uint32_t)dyn_cast<ConstantInt>(val->getInitializer()->getOperand(1))->getZExtValue();
            ConstantArray *arr = dyn_cast<ConstantArray>(val->getInitializer()->getOperand(2));
            for (int j = 0; j < count; ++j) {
                if ([[DDIRUtil stringFromGlobalVariable:dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(j)->getOperand(0))->getOperand(0))] isEqualToString:@"load"]) {
                    NSMutableDictionary *loadDic = [configuration objectForKey:ConfigurationKey_LoadFuction];
                    if (nil == loadDic) {
                        loadDic = [NSMutableDictionary dictionary];
                        [configuration setObject:loadDic forKey:ConfigurationKey_LoadFuction];
                    }
                    NSMutableArray *clsArray = [loadDic objectForKey:@(infos[i].index)];
                    if (nil == clsArray) {
                        clsArray = [NSMutableArray array];
                        [loadDic setObject:clsArray forKey:@(infos[i].index)];
                    }
                    Function *fun = dyn_cast<Function>(dyn_cast<ConstantExpr>(arr->getOperand(j)->getOperand(2))->getOperand(0));
                    [clsArray addObject:@[infos[0].target, [NSValue valueWithPointer:fun]]];
                    
                }
            }
        }
    }
    if (infos.count <= 1) {
        return;
    }
    // insert empty data if count not equal
    GlobalVariable *(^getRoBlock)(int, bool) = ^(int index, bool isMeta) {
        GlobalVariable *cls = [DDIRUtil getObjcClass:infos[index].target inModule:self.module];
        assert(nullptr != cls);
        if (isMeta) {
            GlobalVariable *metaCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(0));
            assert(nullptr != metaCls);
            GlobalVariable *metaRo = dyn_cast<GlobalVariable>(metaCls->getInitializer()->getOperand(4));
            assert(nullptr != metaRo);
            return metaRo;
        } else {
            GlobalVariable *ro = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(4));
            assert(nullptr != ro);
            return ro;
        }
    };
    void (^insetDataBlock)(bool) = ^(bool isMeta) {
        uint32_t methodCount   = 0;
        uint32_t protocolCount = 0;
        uint32_t propertyCount = 0;
        for (int i = 0; i < infos.count; ++i) {
            GlobalVariable *ro = getRoBlock(i, isMeta);
            if (isNullValue(ro, 5)) {
                methodCount = MAX(methodCount, (uint32_t)dyn_cast<ConstantInt>(getValue(ro, 5)->getInitializer()->getOperand(1))->getZExtValue());
            }
            if (isNullValue(ro, 6)) {
                protocolCount = MAX(protocolCount, (uint32_t)dyn_cast<ConstantInt>(getValue(ro, 6)->getInitializer()->getOperand(0))->getZExtValue());
            }
            if (isNullValue(ro, 9)) {
                propertyCount = MAX(propertyCount, (uint32_t)dyn_cast<ConstantInt>(getValue(ro, 9)->getInitializer()->getOperand(1))->getZExtValue());
            }
        }
        for (int i = 0; i < infos.count; ++i) {
            GlobalVariable *ro = getRoBlock(i, isMeta);
            typedef GlobalVariable *(^GetGlobalListBlock)(std::vector<Constant *>&);
            void (^updateList)(int,int,Type*,Constant*,GetGlobalListBlock,NSString*,int) = ^(int count, int index, Type *type, Constant *emptyValue, GetGlobalListBlock getBlock, NSString *defaultName, int offset) {
                if (count <= 0) {
                    return;
                }
                if (!isNullValue(ro, index) || count != dyn_cast<ConstantInt>(getValue(ro, index)->getInitializer()->getOperand(offset))->getZExtValue()) {
                    std::vector<Constant *> list;
                    GlobalVariable *v = nullptr;
                    if (isNullValue(ro, index)) {
                        v = getValue(ro, index);
                        uint32_t n = (uint32_t)dyn_cast<ConstantInt>(v->getInitializer()->getOperand(offset))->getZExtValue();
                        ConstantArray *arr = dyn_cast<ConstantArray>(v->getInitializer()->getOperand(1 + offset));
                        for (int i = 0; i < n; ++i) {
                            list.push_back(arr->getOperand(i));
                        }
                    }
                    while (list.size() < count) {
                        list.push_back(emptyValue);
                    }
                    NSString *name = defaultName;
                    if (nullptr != v) {
                        GlobalVariable *v = getValue(ro, index);
                        name = [NSString stringWithFormat:@"%s", v->getName().data()];
                        v->setName("");
                    }
                    GlobalVariable *nv = getBlock(list);
                    nv->setName([name cStringUsingEncoding:NSUTF8StringEncoding]);
                    ro->getInitializer()->handleOperandChange(ro->getInitializer()->getOperand(index),
                                                              ConstantExpr::getBitCast(nv, type->getPointerTo()));
                    if (nullptr != v) {
                        [DDIRUtil removeGlobalValue:v inModule:self.module];
                    }
                }
            };
            updateList(methodCount,
                       5,
                       [DDIRUtil getStructType:IR_Objc_MethodListTypeName inModule:self.module],
                       [self _getDefaultEmptyFunctionWithConfiguration:configuration],
                       ^(std::vector<Constant *>& l) {
                            return [DDIRUtil createMethodList:l inModule:self.module];
                        },
                       [NSString stringWithFormat:(isMeta ? @"_OBJC_$_CLASS_METHODS_%@" : @"_OBJC_$_INSTANCE_METHODS_%@"), infos[i].target],
                       1);
            updateList(protocolCount,
                       6,
                       [DDIRUtil getStructType:IR_Objc_ProtocolListTypeName inModule:self.module],
                       [self _getDefaultEmptyProtocolWithConfiguration:configuration],
                       ^(std::vector<Constant *>& l) {
                            return [DDIRUtil createProtocolList:l inModule:self.module];
                        },
                       [NSString stringWithFormat:(isMeta ? @"_OBJC_METACLASS_PROTOCOLS_$_%@" : @"_OBJC_CLASS_PROTOCOLS_$_%@"), infos[i].target],
                       0);
            updateList(propertyCount,
                       9,
                       [DDIRUtil getStructType:IR_Objc_PropListTypeName inModule:self.module],
                       [self _getDefaultEmptyPropertyWithConfiguration:configuration],
                       ^(std::vector<Constant *>& l) {
                            return [DDIRUtil createPropList:l inModule:self.module];
                        },
                       [NSString stringWithFormat:(isMeta ? @"_OBJC_$_CLASS_PROP_LIST_%@" : @"_OBJC_$_PROP_LIST_%@"), infos[i].target],
                       1);
        }
    };
    insetDataBlock(false);
    insetDataBlock(true);
    // record super and class ro
    std::vector<GlobalVariable *> dropClsArray;
    GlobalVariable *defautCls = [DDIRUtil getObjcClass:infos[0].target inModule:self.module];
    assert(nullptr != defautCls);
    GlobalVariable *metaDefaultCls = dyn_cast<GlobalVariable>(defautCls->getInitializer()->getOperand(0));
    assert(nullptr != metaDefaultCls);
    GlobalVariable *defaultRo = dyn_cast<GlobalVariable>(defautCls->getInitializer()->getOperand(4));
    assert(nullptr != defaultRo);
    GlobalVariable *metaDefaultRo = dyn_cast<GlobalVariable>(metaDefaultCls->getInitializer()->getOperand(4));
    assert(nullptr != metaDefaultRo);
    Constant *defaultName = dyn_cast<Constant>(defaultRo->getInitializer()->getOperand(4));
    StructType *mapType      = [self _getClassMapType];
    StructType *protocolType = [DDIRUtil getStructType:IR_Objc_ProtocolTypeName inModule:self.module];
    for (int i = 1; i < infos.count; ++i) {
        GlobalVariable *cls = [DDIRUtil getObjcClass:infos[i].target inModule:self.module];
        GlobalVariable *metaCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(0));
        GlobalVariable *ro = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(4));
        GlobalVariable *metaRo = dyn_cast<GlobalVariable>(metaCls->getInitializer()->getOperand(4));
        GlobalVariable *superCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(1));
        assert(nullptr != superCls);
        ro->getInitializer()->handleOperandChange(ro->getInitializer()->getOperand(4), defaultName);
        metaRo->getInitializer()->handleOperandChange(metaRo->getInitializer()->getOperand(4), defaultName);
        dropClsArray.push_back(cls);
        std::vector<Constant *> datas;
        datas.push_back(defautCls);
        datas.push_back(superCls);
        datas.push_back(ro);
        datas.push_back(metaRo);
        if (isNullValue(defaultRo, 5)) {
            datas.push_back(dyn_cast<ConstantStruct>(dyn_cast<ConstantArray>(getValue(defaultRo, 5)->getInitializer()->getOperand(2))->getOperand(0))->getOperand(0));
        } else {
            datas.push_back(Constant::getNullValue(Type::getInt8PtrTy(self.module->getContext())));
        }
        if (isNullValue(defaultRo, 9)) {
            datas.push_back(dyn_cast<ConstantStruct>(dyn_cast<ConstantArray>(getValue(defaultRo, 9)->getInitializer()->getOperand(2))->getOperand(0))->getOperand(0));
        } else {
            datas.push_back(Constant::getNullValue(Type::getInt8PtrTy(self.module->getContext())));
        }
        if (isNullValue(defaultRo, 6)) {
            datas.push_back(dyn_cast<ConstantArray>(getValue(defaultRo, 6)->getInitializer()->getOperand(1))->getOperand(0));
        } else {
            datas.push_back(Constant::getNullValue(protocolType->getPointerTo()));
        }
        if (isNullValue(metaDefaultRo, 5)) {
            datas.push_back(dyn_cast<ConstantStruct>(dyn_cast<ConstantArray>(getValue(metaDefaultRo, 5)->getInitializer()->getOperand(2))->getOperand(0))->getOperand(0));
        } else {
            datas.push_back(Constant::getNullValue(Type::getInt8PtrTy(self.module->getContext())));
        }
        if (isNullValue(metaDefaultRo, 9)) {
            datas.push_back(dyn_cast<ConstantStruct>(dyn_cast<ConstantArray>(getValue(metaDefaultRo, 9)->getInitializer()->getOperand(2))->getOperand(0))->getOperand(0));
        } else {
            datas.push_back(Constant::getNullValue(Type::getInt8PtrTy(self.module->getContext())));
        }
        if (isNullValue(metaDefaultRo, 6)) {
            datas.push_back(dyn_cast<ConstantArray>(getValue(metaDefaultRo, 6)->getInitializer()->getOperand(1))->getOperand(0));
        } else {
            datas.push_back(Constant::getNullValue(protocolType->getPointerTo()));
        }
        NSMutableArray *arr = [configuration objectForKey:ConfigurationKey_Class(infos[i].index)];
        GlobalVariable *item = new GlobalVariable(*self.module,
                                                  mapType,
                                                  false,
                                                  GlobalValue::InternalLinkage,
                                                  ConstantStruct::get(mapType, datas),
                                                  "_DD_OBJC_Class_MAP_$_tmp");
        [arr addObject:[NSValue valueWithPointer:item]];
    }
    // remove other classes
    for (GlobalVariable *cls : dropClsArray) {
        std::vector<GlobalVariable *> globalList;
        std::vector<ConstantStruct *> structList;
        for (User *user : cls->users()) {
            if (nullptr != dyn_cast<GlobalVariable>(user)) {
                globalList.push_back(dyn_cast<GlobalVariable>(user));
            } else if (nullptr != dyn_cast<ConstantStruct>(user)) {
                structList.push_back(dyn_cast<ConstantStruct>(user));
            }
        }
        for (GlobalVariable *val : globalList) {
            GlobalVariable *name = [DDIRUtil createGlobalVariableName:val->getName().data()
                                                   fromGlobalVariable:val
                                                                 type:nullptr
                                                          initializer:defautCls
                                                             inModule:self.module];
            [DDIRUtil replaceGlobalVariable:val with:name];
            val->eraseFromParent();
        }
        for (ConstantStruct *str : structList) {
            str->handleOperandChange(cls, defautCls);
        }
        GlobalVariable *metaCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(0));
        std::vector<GlobalVariable *> metaGolbalList;
        std::vector<ConstantStruct *> metaStructList;
        for (User *user : metaCls->users()) {
            if (nullptr != dyn_cast<GlobalVariable>(user)) {
                metaGolbalList.push_back(dyn_cast<GlobalVariable>(user));
            } else if (nullptr != dyn_cast<ConstantStruct>(user)) {
                ConstantStruct *str = dyn_cast<ConstantStruct>(user);
                if (str != cls->getInitializer()) {
                    metaStructList.push_back(dyn_cast<ConstantStruct>(user));
                }
            }
        }
        for (GlobalVariable *val : metaGolbalList) {
            GlobalVariable *name = [DDIRUtil createGlobalVariableName:val->getName().data()
                                                   fromGlobalVariable:val
                                                                 type:nullptr
                                                          initializer:metaDefaultCls
                                                             inModule:self.module];
            [DDIRUtil replaceGlobalVariable:val with:name];
            val->eraseFromParent();
        }
        for (ConstantStruct *str : metaStructList) {
            str->handleOperandChange(metaCls, metaDefaultCls);
        }
        cls->removeDeadConstantUsers();
        metaCls->removeDeadConstantUsers();
        [DDIRUtil removeGlobalValue:cls inModule:self.module];
    }
}

- (void)_mergeCategoryInfos:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos
                   forClass:(nonnull NSString *)clsName
                   withSize:(NSUInteger)size
              configuration:(nonnull NSMutableDictionary *)configuration
{
    uint32_t instanceMethodCount   = 0;
    uint32_t classMethodCount      = 0;
    uint32_t protocolCount         = 0;
    uint32_t instancePropertyCount = 0;
    uint32_t classPropertyCount    = 0;
    for (DDIRModuleMergeInfo *info in infos) {
        GlobalVariable *category = [DDIRUtil getCategory:info.target forObjcClass:clsName inModule:self.module];
        if (isNullValue(category, 2)) {
            instanceMethodCount = MAX(instanceMethodCount, (uint32_t)dyn_cast<ConstantInt>(getValue(category, 2)->getInitializer()->getOperand(1))->getZExtValue());
        }
        if (isNullValue(category, 3)) {
            classMethodCount = MAX(classMethodCount, (uint32_t)dyn_cast<ConstantInt>(getValue(category, 3)->getInitializer()->getOperand(1))->getZExtValue());
        }
        if (isNullValue(category, 4)) {
            protocolCount = MAX(protocolCount, (uint32_t)dyn_cast<ConstantInt>(getValue(category, 4)->getInitializer()->getOperand(0))->getZExtValue());
        }
        if (isNullValue(category, 5)) {
            instancePropertyCount = MAX(instancePropertyCount, (uint32_t)dyn_cast<ConstantInt>(getValue(category, 5)->getInitializer()->getOperand(1))->getZExtValue());
        }
        if (isNullValue(category, 6)) {
            classPropertyCount = MAX(classPropertyCount, (uint32_t)dyn_cast<ConstantInt>(getValue(category, 6)->getInitializer()->getOperand(1))->getZExtValue());
        }
    }
    GlobalVariable *defaultCategory = nullptr;
    GlobalVariable *emptyCategory   = nullptr;
    StructType *mapType      = [self _getCategoryMapType];
    StructType *protocolType = [DDIRUtil getStructType:IR_Objc_ProtocolTypeName inModule:self.module];
    for (int i = 0; i < size; ++i) {
        GlobalVariable *category = nullptr;
        for (DDIRModuleMergeInfo *info in infos) {
            if (i == info.index) {
                category = [DDIRUtil getCategory:info.target forObjcClass:clsName inModule:self.module];
                break;
            }
        }
        if (nullptr != category) {
            typedef GlobalVariable *(^GetGlobalListBlock)(std::vector<Constant *>&);
            void (^updateList)(int,int,Type*,Constant*,GetGlobalListBlock,NSString*,int) = ^(int count, int index, Type *type, Constant *emptyValue, GetGlobalListBlock getBlock, NSString *defaultName, int offset) {
                if (count <= 0) {
                    return;
                }
                if (!isNullValue(category, index) || count != dyn_cast<ConstantInt>(getValue(category, index)->getInitializer()->getOperand(offset))->getZExtValue()) {
                    std::vector<Constant *> list;
                    GlobalVariable *v = nullptr;
                    if (isNullValue(category, index)) {
                        v = getValue(category, index);
                        uint32_t n = (uint32_t)dyn_cast<ConstantInt>(v->getInitializer()->getOperand(offset))->getZExtValue();
                        ConstantArray *arr = dyn_cast<ConstantArray>(v->getInitializer()->getOperand(1 + offset));
                        for (int i = 0; i < n; ++i) {
                            list.push_back(arr->getOperand(i));
                        }
                    }
                    while (list.size() < count) {
                        list.push_back(emptyValue);
                    }
                    NSString *name = defaultName;
                    if (nullptr != v) {
                        GlobalVariable *v = getValue(category, index);
                        name = [NSString stringWithFormat:@"%s", v->getName().data()];
                        v->setName("");
                    }
                    GlobalVariable *nv = getBlock(list);
                    nv->setName([name cStringUsingEncoding:NSUTF8StringEncoding]);
                    category->getInitializer()->handleOperandChange(category->getInitializer()->getOperand(index),
                                                                    ConstantExpr::getBitCast(nv, type->getPointerTo()));
                    if (nullptr != v) {
                        [DDIRUtil removeGlobalValue:v inModule:self.module];
                    }
                }
            };
            updateList(instanceMethodCount,
                       2,
                       [DDIRUtil getStructType:IR_Objc_MethodListTypeName inModule:self.module],
                       [self _getDefaultEmptyFunctionWithConfiguration:configuration],
                       ^(std::vector<Constant *>& l) {
                            return [DDIRUtil createMethodList:l inModule:self.module];
                        },
                       [NSString stringWithFormat:@"_OBJC_$_CATEGORY_INSTANCE_METHODS_%@_$_%@", clsName, infos[i].target],
                       1);
            updateList(classMethodCount,
                       3,
                       [DDIRUtil getStructType:IR_Objc_MethodListTypeName inModule:self.module],
                       [self _getDefaultEmptyFunctionWithConfiguration:configuration],
                       ^(std::vector<Constant *>& l) {
                            return [DDIRUtil createMethodList:l inModule:self.module];
                        },
                       [NSString stringWithFormat:@"_OBJC_$_CATEGORY_CLASS_METHODS_%@_$_%@", clsName, infos[i].target],
                       1);
            updateList(protocolCount,
                       4,
                       [DDIRUtil getStructType:IR_Objc_ProtocolListTypeName inModule:self.module],
                       [self _getDefaultEmptyProtocolWithConfiguration:configuration],
                       ^(std::vector<Constant *>& l) {
                            return [DDIRUtil createProtocolList:l inModule:self.module];
                        },
                       [NSString stringWithFormat:@"_OBJC_CATEGORY_PROTOCOLS_$_%@_$_%@", clsName, infos[i].target],
                       0);
            updateList(instancePropertyCount,
                       5,
                       [DDIRUtil getStructType:IR_Objc_PropListTypeName inModule:self.module],
                       [self _getDefaultEmptyPropertyWithConfiguration:configuration],
                       ^(std::vector<Constant *>& l) {
                            return [DDIRUtil createPropList:l inModule:self.module];
                        },
                       [NSString stringWithFormat:@"_OBJC_$_PROP_LIST_%@_$_%@", clsName, infos[i].target],
                       1);
            updateList(classPropertyCount,
                       6,
                       [DDIRUtil getStructType:IR_Objc_PropListTypeName inModule:self.module],
                       [self _getDefaultEmptyPropertyWithConfiguration:configuration],
                       ^(std::vector<Constant *>& l) {
                            return [DDIRUtil createPropList:l inModule:self.module];
                        },
                       [NSString stringWithFormat:@"_OBJC_$_PROP_LIST_CLASS_%@_$_%@", clsName, infos[i].target],
                       1);
        } else {
            if (nullptr == emptyCategory || emptyCategory == defaultCategory) {
                std::vector<Constant *> instanceMethods;
                std::vector<Constant *> classMethods;
                std::vector<Constant *> protocols;
                std::vector<Constant *> instanceProperties;
                std::vector<Constant *> classProperties;
                for (int j = 0; j < instanceMethodCount; ++j) {
                    instanceMethods.push_back([self _getDefaultEmptyFunctionWithConfiguration:configuration]);
                }
                for (int j = 0; j < classMethodCount; ++j) {
                    classMethods.push_back([self _getDefaultEmptyFunctionWithConfiguration:configuration]);
                }
                for (int j = 0; j < protocolCount; ++j) {
                    protocols.push_back([self _getDefaultEmptyProtocolWithConfiguration:configuration]);
                }
                for (int j = 0; j < instancePropertyCount; ++j) {
                    instanceProperties.push_back([self _getDefaultEmptyPropertyWithConfiguration:configuration]);
                }
                for (int j = 0; j < classPropertyCount; ++j) {
                    classProperties.push_back([self _getDefaultEmptyPropertyWithConfiguration:configuration]);
                }
                emptyCategory = [DDIRUtil createObjcCategory:"dd_empty"
                                                         cls:[DDIRUtil getObjcClass:clsName inModule:self.module]
                                              withMethodList:instanceMethods
                                             classMethodList:classMethods
                                                protocolList:protocols
                                                    propList:instanceProperties
                                               classPropList:classProperties
                                                    inModule:self.module];
            }
            category = emptyCategory;
        }
        if (nullptr == defaultCategory) {
            defaultCategory = category;
        } else if (defaultCategory != category) {
            std::vector<Constant *> datas;
            datas.push_back(dyn_cast<Constant>(category->getInitializer()->getOperand(1)));
            datas.push_back(category);
            if (isNullValue(defaultCategory, 2)) {
                datas.push_back(dyn_cast<ConstantStruct>(dyn_cast<ConstantArray>(getValue(defaultCategory, 2)->getInitializer()->getOperand(2))->getOperand(0))->getOperand(0));
            } else {
                datas.push_back(Constant::getNullValue(Type::getInt8PtrTy(self.module->getContext())));
            }
            if (isNullValue(defaultCategory, 3)) {
                datas.push_back(dyn_cast<ConstantStruct>(dyn_cast<ConstantArray>(getValue(defaultCategory, 3)->getInitializer()->getOperand(2))->getOperand(0))->getOperand(0));
            } else {
                datas.push_back(Constant::getNullValue(Type::getInt8PtrTy(self.module->getContext())));
            }
            if (isNullValue(defaultCategory, 4)) {
                datas.push_back(dyn_cast<ConstantArray>(getValue(defaultCategory, 4)->getInitializer()->getOperand(1))->getOperand(0));
            } else {
                datas.push_back(Constant::getNullValue(protocolType->getPointerTo()));
            }
            if (isNullValue(defaultCategory, 5)) {
                datas.push_back(dyn_cast<ConstantStruct>(dyn_cast<ConstantArray>(getValue(defaultCategory, 5)->getInitializer()->getOperand(2))->getOperand(0))->getOperand(0));
            } else {
                datas.push_back(Constant::getNullValue(Type::getInt8PtrTy(self.module->getContext())));
            }
            if (isNullValue(defaultCategory, 6)) {
                datas.push_back(dyn_cast<ConstantStruct>(dyn_cast<ConstantArray>(getValue(defaultCategory, 6)->getInitializer()->getOperand(2))->getOperand(0))->getOperand(0));
            } else {
                datas.push_back(Constant::getNullValue(Type::getInt8PtrTy(self.module->getContext())));
            }
            NSMutableArray *arr = [configuration objectForKey:ConfigurationKey_Category(infos[i].index)];
            GlobalVariable *item = new GlobalVariable(*self.module,
                                                      mapType,
                                                      false,
                                                      GlobalValue::InternalLinkage,
                                                      ConstantStruct::get(mapType, datas),
                                                      "_DD_OBJC_Category_MAP_$_tmp");
            [arr addObject:[NSValue valueWithPointer:item]];
            
            [DDIRUtil removeValue:category
                  fromGlobalArray:[DDIRUtil getGlabalArrayWithSection:"__DATA,__objc_catlist" inModule:self.module]
                         inModule:self.module];
            [DDIRUtil removeValue:category
                  fromGlobalArray:[DDIRUtil getGlabalArrayWithSection:"__DATA,__objc_nlcatlist" inModule:self.module]
                         inModule:self.module];
        }
    }
}

- (void)_mergeCategoryInfos:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos
                   forClass:(nonnull NSString *)clsName
                   withSize:(NSUInteger)size
            controlVariable:(GlobalVariable * _Nonnull)control
              configuration:(nonnull NSMutableDictionary *)configuration
{
    if (infos.count <= 1) {
        return;
    }
    std::vector<Constant *> instMethodList;
    std::vector<Constant *> classMethodList;
    std::vector<Constant *> procotolList;
    std::vector<Constant *> instPropList;
    std::vector<Constant *> classPropList;

    NSMutableDictionary *instMethodDic  = [NSMutableDictionary dictionary];
    NSMutableDictionary *classMethodDic = [NSMutableDictionary dictionary];
    NSMutableDictionary *procotolDic    = [NSMutableDictionary dictionary];
    NSMutableDictionary *instPropDic    = [NSMutableDictionary dictionary];
    NSMutableDictionary *classPropDic   = [NSMutableDictionary dictionary];
    for (int i = 0; i < infos.count; ++i) {
        GlobalVariable *cat = [DDIRUtil getCategory:infos[i].target forObjcClass:clsName inModule:self.module];
        assert(nullptr != cat);
        // method
        void (^funBlock)(NSMutableDictionary *, int) = ^(NSMutableDictionary *dic, int index) {
            if (isNullValue(cat, index)) {
                ConstantStruct *s = dyn_cast<ConstantStruct>(getValue(cat, index)->getInitializer());
                uint64_t count = (dyn_cast<ConstantInt>(s->getOperand(1)))->getZExtValue();
                ConstantArray *list = dyn_cast<ConstantArray>(s->getOperand(2));
                for (int j = 0; j < count; ++j) {
                    ConstantStruct *m = dyn_cast<ConstantStruct>(list->getOperand(j));
                    NSString *name = [DDIRUtil stringFromGlobalVariable:dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(m->getOperand(0)))->getOperand(0))];
                    NSMutableArray *a = [dic objectForKey:name];
                    if (nil == a) {
                        a = [NSMutableArray array];
                        [dic setObject:a forKey:name];
                    }
                    [a addObject:@[[NSValue valueWithPointer:m], @(infos[i].index)]];
                }
            }
        };
        funBlock(instMethodDic, 2);
        funBlock(classMethodDic, 3);
        // protocol
        if (isNullValue(cat, 4)) {
            ConstantStruct *s = dyn_cast<ConstantStruct>(getValue(cat, 4)->getInitializer());
            uint64_t count = (dyn_cast<ConstantInt>(s->getOperand(0)))->getZExtValue();
            ConstantArray *list = dyn_cast<ConstantArray>(s->getOperand(1));
            for (int j = 0; j < count; ++j) {
                GlobalVariable *pro = dyn_cast<GlobalVariable>(list->getOperand(j));
                NSString *name = [DDIRUtil getObjcProcotolName:pro];
                NSNumber *b = [procotolDic objectForKey:name];
                if (nil == b) {
                    procotolList.push_back(pro);
                    [procotolDic setObject:@(YES) forKey:name];
                }

            }
        }
        // prop
        void (^propBlock)(NSMutableDictionary *, std::vector<Constant *>&, int) = ^(NSMutableDictionary *dic, std::vector<Constant *>& l, int index) {
            if (isNullValue(cat, index)) {
                ConstantStruct *s = dyn_cast<ConstantStruct>(getValue(cat, index)->getInitializer());
                uint64_t count = (dyn_cast<ConstantInt>(s->getOperand(1)))->getZExtValue();
                ConstantArray *list = dyn_cast<ConstantArray>(s->getOperand(2));
                for (int j = 0; j < count; ++j) {
                    ConstantStruct *m = dyn_cast<ConstantStruct>(list->getOperand(j));
                    NSString *name = [DDIRUtil stringFromGlobalVariable:dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(m->getOperand(0)))->getOperand(0))];
                    NSNumber *b = [dic objectForKey:name];
                    if (nil == b) {
                        l.push_back(m);
                        [dic setObject:@(YES) forKey:name];
                    }

                }
            }
        };
        propBlock(instPropDic, instPropList, 5);
        propBlock(classPropDic, classPropList, 6);
    }

    [self _mergeSameFunctionSets:instMethodDic toList:instMethodList control:control configuration:configuration];
    [self _mergeSameFunctionSets:classMethodDic toList:classMethodList control:control configuration:configuration];

    GlobalVariable *category = [DDIRUtil createObjcCategory:[[infos[0].target stringByAppendingString:@"_dd"] cStringUsingEncoding:NSUTF8StringEncoding]
                                                        cls:[DDIRUtil getObjcClass:clsName inModule:self.module]
                                             withMethodList:instMethodList
                                            classMethodList:classMethodList
                                               protocolList:procotolList
                                                   propList:instPropList
                                              classPropList:classPropList
                                                   inModule:self.module];
    if (nil != [classMethodDic objectForKey:@"load"]) {
        [DDIRUtil insertValue:ConstantExpr::getBitCast(category, Type::getInt8PtrTy(self.module->getContext()))
     toGlobalArrayWithSection:"__DATA,__objc_nlcatlist"
                  defaultName:"OBJC_LABEL_NONLAZY_CATEGORY_$"
                     inModule:self.module];
    }
    for (DDIRModuleMergeInfo *i in infos) {
        GlobalVariable *cat = [DDIRUtil getCategory:i.target forObjcClass:clsName inModule:self.module];
        [DDIRUtil removeGlobalValue:cat inModule:self.module];
    }
}

- (void)_mergeProtocols:(nonnull NSArray<NSString *> *)names withMap:(nonnull NSDictionary<NSString *, NSString *> *)map
{
    if (names.count <= 1) {
        return;
    }
    std::vector<GlobalVariable *> removeList;
    std::vector<GlobalVariable *> proList;
    uint32_t flags = 0;
    std::vector<Constant *> procotolList;
    std::vector<Constant *> instMethodList;
    std::vector<Constant *> classMethodList;
    std::vector<Constant *> instOpMethodList;
    std::vector<Constant *> classOpMethodList;
    std::vector<Constant *> instPropList;
    std::vector<Constant *> classPropList;
    
    NSMutableDictionary *instMethodDic  = [NSMutableDictionary dictionary];
    NSMutableDictionary *classMethodDic = [NSMutableDictionary dictionary];
    NSMutableDictionary *procotolDic    = [NSMutableDictionary dictionary];
    NSMutableDictionary *instPropDic    = [NSMutableDictionary dictionary];
    NSMutableDictionary *classPropDic   = [NSMutableDictionary dictionary];
    for (int i = 0; i < names.count; ++i) {
        GlobalVariable *protocolLabel = [DDIRUtil getObjcProtocolLabel:names[i] inModule:self.module];
        assert(nullptr != protocolLabel);
        GlobalVariable *protocol = dyn_cast<GlobalVariable>(protocolLabel->getInitializer());
        assert(nullptr != protocol);
        removeList.push_back(protocolLabel);
        removeList.push_back(protocol);
        proList.push_back(protocol);
        protocolLabel->setName("");
        protocol->setName("");
        flags |= dyn_cast<ConstantInt>(protocol->getInitializer()->getOperand(9))->getZExtValue();
        // method
        void (^funBlock)(NSMutableDictionary *, std::vector<Constant *>&, int) = ^(NSMutableDictionary *dic, std::vector<Constant *>& l, int index) {
            if (isNullValue(protocol, index)) {
                GlobalVariable *v = getValue(protocol, index);
                v->setName("");
                ConstantStruct *s = dyn_cast<ConstantStruct>(v->getInitializer());
                uint64_t count = (dyn_cast<ConstantInt>(s->getOperand(1)))->getZExtValue();
                ConstantArray *list = dyn_cast<ConstantArray>(s->getOperand(2));
                for (int j = 0; j < count; ++j) {
                    ConstantStruct *m = dyn_cast<ConstantStruct>(list->getOperand(j));
                    NSString *name = [DDIRUtil stringFromGlobalVariable:dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(m->getOperand(0)))->getOperand(0))];
                    NSNumber *b = [dic objectForKey:name];
                    if (nil == b) {
                        l.push_back(m);
                        [dic setObject:@(YES) forKey:name];
                    }
                }
            }
        };
        funBlock(instMethodDic, instMethodList, 3);
        funBlock(instMethodDic, instOpMethodList, 5);
        funBlock(classMethodDic, classMethodList, 4);
        funBlock(classMethodDic, classOpMethodList, 6);
        // prop
        void (^propBlock)(NSMutableDictionary *, std::vector<Constant *>&, int) = ^(NSMutableDictionary *dic, std::vector<Constant *>& l, int index) {
            if (isNullValue(protocol, index)) {
                GlobalVariable *v = getValue(protocol, index);
                v->setName("");
                ConstantStruct *s = dyn_cast<ConstantStruct>(v->getInitializer());
                uint64_t count = (dyn_cast<ConstantInt>(s->getOperand(1)))->getZExtValue();
                ConstantArray *list = dyn_cast<ConstantArray>(s->getOperand(2));
                for (int j = 0; j < count; ++j) {
                    ConstantStruct *m = dyn_cast<ConstantStruct>(list->getOperand(j));
                    NSString *name = [DDIRUtil stringFromGlobalVariable:dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(m->getOperand(0)))->getOperand(0))];
                    NSNumber *b = [dic objectForKey:name];
                    if (nil == b) {
                        l.push_back(m);
                        [dic setObject:@(YES) forKey:name];
                    }

                }
            }
        };
        propBlock(instPropDic, instPropList, 7);
        propBlock(classPropDic, classPropList, 12);
        // protocol
        if (isNullValue(protocol, 2)) {
            GlobalVariable *v = getValue(protocol, 2);
            v->setName("");
            ConstantStruct *s = dyn_cast<ConstantStruct>(v->getInitializer());
            uint64_t count = (dyn_cast<ConstantInt>(s->getOperand(0)))->getZExtValue();
            ConstantArray *list = dyn_cast<ConstantArray>(s->getOperand(1));
            for (int j = 0; j < count; ++j) {
                GlobalVariable *pro = dyn_cast<GlobalVariable>(list->getOperand(j));
                NSString *name = [DDIRUtil getObjcProcotolName:pro];
                NSString *remapName = [map objectForKey:name];
                NSNumber *b = [procotolDic objectForKey:remapName];
                if (nil == b) {
                    procotolList.push_back(pro);
                    [procotolDic setObject:@(YES) forKey:remapName];
                }

            }
        }
        // types
        if (isNullValue(protocol, 10)) {
            getValue(protocol, 10)->setName("");
        }
        [DDIRUtil removeValue:protocol
              fromGlobalArray:[DDIRUtil getLlvmUsedInModule:self.module]
                     inModule:self.module];
        [DDIRUtil removeValue:protocolLabel
              fromGlobalArray:[DDIRUtil getLlvmUsedInModule:self.module]
                     inModule:self.module];
    }
    
    GlobalVariable *var = [DDIRUtil createObjcProtocol:[names[0] cStringUsingEncoding:NSUTF8StringEncoding]
                                             withFlags:flags
                                          protocolList:procotolList
                                            methodList:instMethodList
                                       classMethodList:classMethodList
                                    optionalMethodList:instOpMethodList
                               optionalClassMethodList:classOpMethodList
                                              propList:instPropList
                                         classPropList:classPropList
                                              inModule:self.module];
    for (GlobalVariable *g : proList) {
        [DDIRUtil replaceGlobalVariable:g with:var];
    }
    for (GlobalVariable *g : removeList) {
        [DDIRUtil removeGlobalValue:g inModule:self.module];
    }
}

- (StructType * _Nonnull)_getClassMapType
{
    const char *name = "struct._dd_class_map_t";
    StructType *mapType = [DDIRUtil getStructType:name inModule:self.module];
    if (nullptr == mapType) {
        StructType *classType    = [DDIRUtil getStructType:IR_Objc_ClassTypeName inModule:self.module];
        StructType *roType       = [DDIRUtil getStructType:IR_Objc_RoTypeName inModule:self.module];
        StructType *protocolType = [DDIRUtil getStructType:IR_Objc_ProtocolTypeName inModule:self.module];
        mapType = StructType::create(self.module->getContext(), name);
        mapType->setBody(classType->getPointerTo(),
                         classType->getPointerTo(),
                         roType->getPointerTo(),
                         roType->getPointerTo(),
                         Type::getInt8PtrTy(self.module->getContext()),
                         Type::getInt8PtrTy(self.module->getContext()),
                         protocolType->getPointerTo(),
                         Type::getInt8PtrTy(self.module->getContext()),
                         Type::getInt8PtrTy(self.module->getContext()),
                         protocolType->getPointerTo());
    }
    return mapType;
}


// class is a metaclass
#define RO_META               (1<<0)
// class compiled with ARC
#define RO_IS_ARC             (1<<7)
- (void)_handleLoadFunctionWithControlVariable:(GlobalVariable *)control configuration:(nonnull NSMutableDictionary *)configuration
{
    for (GlobalVariable &v : self.module->getGlobalList()) {
        if (v.hasSection() && 0 == strncmp(v.getSection().data(), "__DATA,__objc_nlclslist", 23)) {
            [DDIRUtil removeGlobalValue:std::addressof(v) inModule:self.module];
            break;
        }
    }
    NSDictionary *loadDic = [configuration objectForKey:ConfigurationKey_LoadFuction];
    if (loadDic.count > 0) {
        uint32_t controlId = (uint32_t)[[configuration objectForKey:ConfigurationKey_ControlId] unsignedIntegerValue];
        std::vector<Constant *> methodList;
        StructType *methodType = [DDIRUtil getStructType:IR_Objc_MethodTypeName inModule:self.module];
        std::vector<Constant *> datas;
        Constant *zero = ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 0);
        // name
        GlobalVariable *methodName = [DDIRUtil createObjcMethodName:"load" inModule:self.module];
        datas.push_back(ConstantExpr::getInBoundsGetElementPtr(methodName->getInitializer()->getType(), methodName, (Constant *[]){zero, zero}));
        // type
        GlobalVariable *varType = [DDIRUtil createObjcVarType:"v16@0:8" inModule:self.module];
        datas.push_back(ConstantExpr::getInBoundsGetElementPtr(varType->getInitializer()->getType(), varType, (Constant *[]){zero, zero}));
        // function
        std::vector<Type *> typeList;
        typeList.push_back(Type::getInt8PtrTy(self.module->getContext()));
        typeList.push_back(Type::getInt8PtrTy(self.module->getContext()));
        FunctionType *type = FunctionType::get(Type::getVoidTy(self.module->getContext()), typeList, false);
        Function *fun = Function::Create(type, GlobalValue::InternalLinkage, [[NSString stringWithFormat:@"+[DDLoad_%u load]", controlId] cStringUsingEncoding:NSUTF8StringEncoding], self.module);
        BasicBlock *switchBlock = BasicBlock::Create(self.module->getContext(), "", fun);
        BasicBlock *defaultBlock = BasicBlock::Create(self.module->getContext(), "", fun);
        IRBuilder<> defaultBuilder(defaultBlock);
        defaultBuilder.CreateRetVoid();
        IRBuilder<> switchBuilder(switchBlock);
        LoadInst *loadInst = switchBuilder.CreateLoad(control->getInitializer()->getType(), control);
        SwitchInst * inst = switchBuilder.CreateSwitch(switchBuilder.CreateExtractValue(loadInst, 1),
                                                 defaultBlock,
                                                 (unsigned int)loadDic.count);
        for (NSNumber *index in loadDic.allKeys) {
            BasicBlock *block = BasicBlock::Create(self.module->getContext(), "", fun);
            IRBuilder<> builder(block);
            for (NSArray *arr in [loadDic objectForKey:index]) {
                GlobalVariable *cls = [DDIRUtil getObjcClass:arr[0] inModule:self.module];
                GlobalVariable *clsRef = [DDIRUtil getAndCreateClassReference:cls inModule:self.module];
                GlobalVariable *selRef = [DDIRUtil getAndCreateSelectorReference:"load" inClass:cls inModule:self.module];
                Function *loadFun = (Function *)[arr[1] pointerValue];
                auto clsLoadInst = builder.CreateLoad([DDIRUtil getStructType:IR_Objc_ClassTypeName inModule:self.module]->getPointerTo(), clsRef);
                auto selLoadInst = builder.CreateLoad(Type::getInt8PtrTy(self.module->getContext()), selRef);
                auto clsCastInst = builder.CreateCast(Instruction::BitCast, clsLoadInst, Type::getInt8PtrTy(self.module->getContext()));
                std::vector<Value *> args;
                args.push_back(clsCastInst);
                args.push_back(selLoadInst);
                builder.CreateCall(loadFun, args);
            }
            builder.CreateRetVoid();
            inst->addCase(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), [index integerValue]), block);
        }
        datas.push_back(ConstantExpr::getBitCast(fun, Type::getInt8PtrTy(self.module->getContext())));
        methodList.push_back(dyn_cast<ConstantStruct>(ConstantStruct::get(methodType, datas)));
        GlobalVariable *cls = self.module->getNamedGlobal("OBJC_CLASS_$_NSObject");
        GlobalVariable *metaCls = self.module->getNamedGlobal("OBJC_METACLASS_$_NSObject");
        NSString *name = [NSString stringWithFormat:@"DDLoad_%u", controlId];
        GlobalVariable *newCls = [DDIRUtil createObjcClass:[name cStringUsingEncoding:NSUTF8StringEncoding]
                                                 withSuper:cls
                                                 metaSuper:metaCls
                                                     flags:RO_IS_ARC
                                                classFlags:(RO_META | RO_IS_ARC)
                                             instanceStart:8   // NSObject size
                                              instanceSize:8   // NSObject size
                                                methodList:std::vector<Constant *>()
                                           classMethodList:methodList
                                                  ivarList:std::vector<Constant *>()
                                              protocolList:std::vector<Constant *>()
                                                  propList:std::vector<Constant *>()
                                             classPropList:std::vector<Constant *>()
                                                  inModule:self.module];
        [DDIRUtil insertValue:ConstantExpr::getBitCast(newCls, Type::getInt8PtrTy(self.module->getContext()))
     toGlobalArrayWithSection:"__DATA,__objc_nlclslist"
                  defaultName:"OBJC_LABEL_NONLAZY_CLASS_$"
                     inModule:self.module];
    }
}

- (void)_handleInitFunctionWithControlVariable:(GlobalVariable *)control configuration:(nonnull NSMutableDictionary *)configuration
{
    GlobalVariable *ctorVal = self.module->getGlobalVariable("llvm.global_ctors");
    if (nullptr != ctorVal) {
        ctorVal->eraseFromParent();
        ctorVal = nullptr;
    }
    NSDictionary *initDic = [configuration objectForKey:ConfigurationKey_InitFuction];
    if (initDic.count > 0) {
        uint32_t controlId = (uint32_t)[[configuration objectForKey:ConfigurationKey_ControlId] unsignedIntegerValue];
        FunctionType *funType = FunctionType::get(Type::getVoidTy(self.module->getContext()), std::vector<Type *>(), false);
        Function *fun = Function::Create(funType, GlobalValue::InternalLinkage, [[NSString stringWithFormat:@"initFunction_%u", controlId] cStringUsingEncoding:NSUTF8StringEncoding], self.module);
        BasicBlock *switchBlock = BasicBlock::Create(self.module->getContext(), "", fun);
        BasicBlock *defaultBlock = BasicBlock::Create(self.module->getContext(), "", fun);
        IRBuilder<> defaultBuilder(defaultBlock);
        defaultBuilder.CreateRetVoid();
        IRBuilder<> switchBuilder(switchBlock);
        LoadInst *loadInst = switchBuilder.CreateLoad(control->getInitializer()->getType(), control);
        SwitchInst * inst = switchBuilder.CreateSwitch(switchBuilder.CreateExtractValue(loadInst, 1),
                                                       defaultBlock,
                                                       (unsigned int)initDic.count);
        for (NSNumber *index in initDic.allKeys) {
            BasicBlock *block = BasicBlock::Create(self.module->getContext(), "", fun);
            IRBuilder<> builder(block);
            for (NSString *funName in [initDic objectForKey:index]) {
                Function *initFun = self.module->getFunction([funName cStringUsingEncoding:NSUTF8StringEncoding]);
                builder.CreateCall(initFun, std::vector<Value *>());
            }
            builder.CreateRetVoid();
            inst->addCase(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), [index integerValue]), block);
        }
        std::vector<Type *> type;
        type.push_back(Type::getInt32Ty(self.module->getContext()));
        type.push_back(FunctionType::get(Type::getVoidTy(self.module->getContext()), std::vector<Type *>(), false)->getPointerTo());
        type.push_back(Type::getInt8PtrTy(self.module->getContext()));
        StructType *strType = StructType::get(self.module->getContext(), type);
        std::vector<Constant *> data;
        data.push_back(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 65535));
        data.push_back(fun);
        data.push_back(ConstantPointerNull::get(PointerType::getInt8PtrTy(self.module->getContext())));
        Constant *val = ConstantArray::get(ArrayType::get(strType, 1), ConstantStruct::get(strType, data));
        new GlobalVariable(*self.module,
                           val->getType(),
                           false,
                           GlobalValue::AppendingLinkage,
                           val,
                           "llvm.global_ctors");
    }
}

- (Function * _Nullable)_getFunction:(const char * _Nonnull)selector inClass:(GlobalVariable * _Nonnull)cls
{
    GlobalVariable *metaCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(0));
    GlobalVariable *metaRo = dyn_cast<GlobalVariable>(metaCls->getInitializer()->getOperand(4));
    ConstantStruct *metaMethodStruct = dyn_cast<ConstantStruct>(getValue(metaRo, 5)->getInitializer());
    uint64_t methodCount = (dyn_cast<ConstantInt>(metaMethodStruct->getOperand(1)))->getZExtValue();
    ConstantArray *methodList = dyn_cast<ConstantArray>(metaMethodStruct->getOperand(2));
    for (int i = 0; i < methodCount; ++i) {
        GlobalVariable *m = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(methodList->getOperand(i)->getOperand(0))->getOperand(0));
        if (0 == strcmp(selector, [[DDIRUtil stringFromGlobalVariable:m] cStringUsingEncoding:NSUTF8StringEncoding])) {
            return dyn_cast<Function>(dyn_cast<ConstantExpr>(methodList->getOperand(i)->getOperand(2))->getOperand(0));
            break;
        }
    }
    return nullptr;
}

- (StructType * _Nonnull)_getClassMapListType
{
    const char *name = "struct._dd_class_map_list_t";
    StructType *mapListType = [DDIRUtil getStructType:name inModule:self.module];
    if (nullptr == mapListType) {
        StructType *mapType = [self _getClassMapType];
        mapListType = StructType::create(self.module->getContext(), name);
        mapListType->setBody(Type::getInt32Ty(self.module->getContext()),
                             Type::getInt32Ty(self.module->getContext()),
                             Type::getInt32Ty(self.module->getContext()),
                             ArrayType::get(mapType, 0));
    }
    return mapListType;
}


- (StructType * _Nonnull)_getCategoryMapType
{
    const char *name = "struct._dd_category_map_t";
    StructType *mapType = [DDIRUtil getStructType:name inModule:self.module];
    if (nullptr == mapType) {
        StructType *classType    = [DDIRUtil getStructType:IR_Objc_ClassTypeName inModule:self.module];
        StructType *categoryType = [DDIRUtil getStructType:IR_Objc_CategoryTypeName inModule:self.module];
        StructType *protocolType = [DDIRUtil getStructType:IR_Objc_ProtocolTypeName inModule:self.module];
        mapType = StructType::create(self.module->getContext(), name);
        mapType->setBody(classType->getPointerTo(),
                         categoryType->getPointerTo(),
                         Type::getInt8PtrTy(self.module->getContext()),
                         Type::getInt8PtrTy(self.module->getContext()),
                         protocolType->getPointerTo(),
                         Type::getInt8PtrTy(self.module->getContext()),
                         Type::getInt8PtrTy(self.module->getContext()));
    }
    return mapType;
}

- (StructType * _Nonnull)_getCategoryMapListType
{
    const char *name = "struct._dd_category_map_list_t";
    StructType *mapListType = [DDIRUtil getStructType:name inModule:self.module];
    if (nullptr == mapListType) {
        StructType *mapType = [self _getCategoryMapType];
        mapListType = StructType::create(self.module->getContext(), name);
        mapListType->setBody(Type::getInt32Ty(self.module->getContext()),
                             Type::getInt32Ty(self.module->getContext()),
                             Type::getInt32Ty(self.module->getContext()),
                             ArrayType::get(mapType, 0));
    }
    return mapListType;
}

- (void)_mergeSameFunctionSets:(NSDictionary *)dic toList:(std::vector<Constant *>&)list control:(GlobalVariable *)ctr configuration:(nonnull NSMutableDictionary *)configuration
{
    for (NSString *n in dic.allKeys) {
        NSArray *a = [dic objectForKey:n];
        if (a.count > 1) {
            NSMutableArray<DDIRModuleMergeInfo *> *i = [NSMutableArray array];
            for (NSArray *v in a) {
                ConstantStruct *m = (ConstantStruct *)[v[0] pointerValue];
                Function *f = dyn_cast<Function>((dyn_cast<ConstantExpr>(m->getOperand(2)))->getOperand(0));
                [i addObject:[DDIRModuleMergeInfo infoWithTarget:[NSString stringWithCString:f->getName().data() encoding:NSUTF8StringEncoding]
                                                                index:[v[1] integerValue]]];
            }
            ConstantStruct *m = (ConstantStruct *)[[a[0] objectAtIndex:0] pointerValue];
            [configuration setObject:[configuration objectForKey:[[a objectAtIndex:0] objectAtIndex:1]] forKey:i[0].target];
            Function *f = [self _mergeFunctions:i withControl:ctr configuration:configuration];
            std::vector<Constant *> l;
            l.push_back(m->getOperand(0));
            l.push_back(m->getOperand(1));
            l.push_back(ConstantExpr::getBitCast(f, Type::getInt8PtrTy(self.module->getContext())));
            list.push_back(ConstantStruct::get(m->getType(), l));
        } else {
            list.push_back((Constant *)[[a[0] objectAtIndex:0] pointerValue]);
        }
    }
}

class TypeMap : public ValueMapTypeRemapper {
public:
    Type *remapType(Type *src) {
        Type *t = map[src];
        if (nullptr != t) {
            return t;
        }
        if (src->isPointerTy()) {
            t = map[src->getPointerElementType()];
            if (nullptr != t) {
                return t->getPointerTo();
            }
        }
        return src;
    }
    std::map<Type *, Type *> map;
};

// only used by global function, not objc function
- (Function *)_mergeFunctions:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos withControl:(GlobalVariable *)control configuration:(nonnull NSMutableDictionary *)configuration
{
    std::vector<Function *> functionList;
    for (DDIRModuleMergeInfo *inf in infos) {
        Function *f = self.module->getFunction([inf.target cStringUsingEncoding:NSUTF8StringEncoding]);
        assert(nullptr != f);
        functionList.push_back(f);
    }
    NSString *key = [configuration objectForKey:infos[0].target];
    assert(nil != key);
    NSMutableDictionary *record = [configuration objectForKey:ConfigurationKey_ChangeRecord];
    NSString *newFunctionName = [infos[0].target stringByAppendingFormat:@"_%lu", GetAppendValue(key)];
    [[record objectForKey:key] addObject:[DDIRNameChangeItem functionItemWithTargetName:infos[0].target newName:newFunctionName]];
    functionList[0]->setName([newFunctionName cStringUsingEncoding:NSUTF8StringEncoding]);
    
    Function *fun = Function::Create(functionList[0]->getFunctionType(), GlobalValue::InternalLinkage, [infos[0].target cStringUsingEncoding:NSUTF8StringEncoding], self.module);
    BasicBlock *switchBlock = BasicBlock::Create(self.module->getContext(), "", fun);
    BasicBlock *defaultBlock = BasicBlock::Create(self.module->getContext(), "", fun);
    IRBuilder<> defaultBuilder(defaultBlock);
    std::vector<Value *> defaultArgList;
    for (int i = 0; i < fun->getFunctionType()->getNumParams(); ++i) {
        Argument *arg = fun->getArg(i);
        defaultArgList.push_back(defaultBuilder.CreateBitCast(arg, functionList[0]->getFunctionType()->getParamType(i)));
    }
    CallInst *defautlCallInst = defaultBuilder.CreateCall(functionList[0], defaultArgList);
    if (fun->getReturnType()->isVoidTy()) {
        defaultBuilder.CreateRetVoid();
    } else {
        defaultBuilder.CreateRet(defautlCallInst);
    }
    IRBuilder<> switchBuilder(switchBlock);
    LoadInst *loadInst = switchBuilder.CreateLoad(control->getInitializer()->getType(), control);
    SwitchInst * inst = switchBuilder.CreateSwitch(switchBuilder.CreateExtractValue(loadInst, 1),
                                                   defaultBlock,
                                                   (unsigned int)infos.count);
    for (int i = 0; i < infos.count; ++i) {
        BasicBlock *block = BasicBlock::Create(self.module->getContext(), "", fun);
        IRBuilder<> builder(block);
        std::vector<Value *> argList;
        for (int j = 0; j < fun->getFunctionType()->getNumParams(); ++j) {
            Argument *arg = fun->getArg(j);
            argList.push_back(builder.CreateBitCast(arg, functionList[i]->getFunctionType()->getParamType(j)));
        }
        Value *returnValue = builder.CreateCall(functionList[i], argList);
        if (fun->getReturnType()->isVoidTy()) {
            builder.CreateRetVoid();
        } else {
            if (returnValue->getType() != fun->getFunctionType()->getReturnType()) {
                returnValue = builder.CreateBitCast(returnValue, fun->getFunctionType()->getReturnType());
            }
            builder.CreateRet(returnValue);
        }
        inst->addCase(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), infos[i].index), block);
    }
    return fun;
}

- (Function *)_mergeFunctions:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos withControl:(GlobalVariable *)control
{
    Function *bf = self.module->getFunction([infos[0].target cStringUsingEncoding:NSUTF8StringEncoding]);
    bf->setName(Twine([[NSString stringWithFormat:@"%s..", bf->getName().data()] cStringUsingEncoding:NSUTF8StringEncoding]));
    Function *baseFun = Function::Create(bf->getFunctionType(), bf->getLinkage(), [infos[0].target cStringUsingEncoding:NSUTF8StringEncoding], self.module);
    infos[0].target = [NSString stringWithUTF8String:bf->getName().data()];
    BasicBlock *baseBlock = BasicBlock::Create(self.module->getContext(), "", baseFun);
    BasicBlock *defaultBlock = BasicBlock::Create(self.module->getContext(), "", baseFun);
    IRBuilder<> builder(baseBlock);
    LoadInst *loadInst = builder.CreateLoad(control->getInitializer()->getType(), control);
    SwitchInst * inst = builder.CreateSwitch(builder.CreateExtractValue(loadInst, 1),
                                             defaultBlock,
                                             (unsigned int)infos.count);
    BasicBlock *endBlock = defaultBlock;
    BOOL did = false;
    for (DDIRModuleMergeInfo *i in infos) {
        NSString *fun = i.target;
        Function *f = self.module->getFunction([fun cStringUsingEncoding:NSUTF8StringEncoding]);
        ValueToValueMapTy vmap;
        TypeMap tmap;
        auto it = baseFun->arg_begin();
        for (auto &a: f->args()) {
            vmap[&a] = &(*it);
            auto t = a.getType();
            tmap.map[t] = (*it).getType();
            it++;
        }
        tmap.map[f->getReturnType()] = baseFun->getReturnType();
        SmallVector<ReturnInst*, 8> returns;
        CloneFunctionInto(baseFun, f, vmap, CloneFunctionChangeType::LocalChangesOnly, returns, "", nullptr, &tmap);
        BasicBlock *last = nullptr;
        for (BasicBlock &b : baseFun->getBasicBlockList()) {
            if (last == endBlock) {
                inst->addCase(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), i.index), std::addressof(b));
                if (false == did) {
                    IRBuilder<> db(defaultBlock);
                    db.CreateBr(std::addressof(b));
                    did = true;
                }
                break;
            }
            last = std::addressof(b);
        }
        endBlock = &baseFun->getBasicBlockList().back();
    }
    baseFun->clearMetadata();
    
    return baseFun;
}
     
- (Function *)_mergeStaticVariables:(nonnull NSDictionary<NSString *, NSArray<DDIRModuleMergeInfo *> *> *)dic withControl:(GlobalVariable *)control count:(NSUInteger)count configuration:(nonnull NSMutableDictionary *)configuration
{
    __block NSMutableArray<NSMutableArray<NSArray<NSString *> *> *> *staticVarList = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; ++i) {
        [staticVarList addObject:[NSMutableArray array]];
    }
    [dic enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull name, NSArray<DDIRModuleMergeInfo *> * _Nonnull infoList, BOOL * _Nonnull stop) {
        if (infoList.count > 1) {
            for (DDIRModuleMergeInfo *info in infoList) {
                [[staticVarList objectAtIndex:info.index] addObject:@[name, info.target]];
            }
        }
    }];
    Function *fun = Function::Create(FunctionType::get(Type::getVoidTy(self.module->getContext()), false), GlobalValue::InternalLinkage, "dd_static_variable_function", self.module);
    BasicBlock *baseBlock = BasicBlock::Create(self.module->getContext(), "", fun);
    IRBuilder<> builder(baseBlock);
    BasicBlock *defaultBlock = BasicBlock::Create(self.module->getContext(), "", fun);
    IRBuilder<> defalultBuilder(defaultBlock);
    defalultBuilder.CreateRetVoid();
    LoadInst *loadInst = builder.CreateLoad(control->getInitializer()->getType(), control);
    SwitchInst * switchInst = builder.CreateSwitch(builder.CreateExtractValue(loadInst, 1),
                                                   defaultBlock,
                                                   (unsigned int)count);
    for (int i = 0; i < count; ++i) {
        BasicBlock *block = BasicBlock::Create(self.module->getContext(), "", fun);
        IRBuilder<> builder(block);
        for (NSArray<NSString *> *list in [staticVarList objectAtIndex:i]) {
            NSString *srcName = list[0];
            NSString *dstName = list[1];
            if ([srcName isEqualToString:dstName]) {
                NSString *key = [configuration objectForKey:srcName];
                assert(nil != key);
                NSMutableDictionary *record = [configuration objectForKey:ConfigurationKey_ChangeRecord];
                dstName = [srcName stringByAppendingFormat:@"%lu", GetAppendValue(key)];
                [[record objectForKey:key] addObject:[DDIRNameChangeItem functionItemWithTargetName:dstName newName:srcName]];
                GlobalVariable *var = self.module->getGlobalVariable([srcName cStringUsingEncoding:NSUTF8StringEncoding]);
                var->setName([dstName cStringUsingEncoding:NSUTF8StringEncoding]);
                new GlobalVariable(*self.module,
                                   dyn_cast<PointerType>(var->getType())->getElementType(),
                                   false,
                                   GlobalValue::ExternalLinkage,
                                   var->getInitializer(),
                                   [srcName cStringUsingEncoding:NSUTF8StringEncoding]);
            }
            GlobalVariable *srcVar = self.module->getGlobalVariable([srcName cStringUsingEncoding:NSUTF8StringEncoding]);
            GlobalVariable *dstVar = self.module->getGlobalVariable([dstName cStringUsingEncoding:NSUTF8StringEncoding]);
            LoadInst *load = builder.CreateLoad(dyn_cast<PointerType>(dstVar->getType())->getElementType(), dstVar);
            Value *bitcast = builder.CreateBitCast(load, dyn_cast<PointerType>(srcVar->getType())->getElementType());
            builder.CreateStore(bitcast, srcVar);
        }
        builder.CreateRetVoid();
        switchInst->addCase(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), i), block);
    }
    return fun;
}

static bool _isObjcClassHasLoad(GlobalVariable *cls)
{
    GlobalVariable *metalCls = dyn_cast<GlobalVariable>((dyn_cast<ConstantStruct>(cls->getInitializer()))->getOperand(0));
    GlobalVariable *metalRo = dyn_cast<GlobalVariable>(dyn_cast<ConstantStruct>(metalCls->getInitializer())->getOperand(4));
    if (isNullValue(metalRo, 5)) {
        GlobalVariable *classMethods = getValue(metalRo, 5);
        ConstantStruct *methodsPtr = dyn_cast<ConstantStruct>(classMethods->getInitializer());
        uint64_t count = (dyn_cast<ConstantInt>(methodsPtr->getOperand(1)))->getZExtValue();
        ConstantArray *list = dyn_cast<ConstantArray>(methodsPtr->getOperand(2));
        for (int i = 0; i < count; ++i) {
            ConstantStruct *methodStr = dyn_cast<ConstantStruct>(list->getOperand(i));
            GlobalVariable *methodName = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(methodStr->getOperand(0))->getOperand(0));
            if ([[DDIRUtil stringFromGlobalVariable:methodName] isEqualToString:@"load"]) {
                return true;
            }
        }
    }
    return false;
}

static bool _isObjcCategoryHasLoad(GlobalVariable *cat)
{
    if (isNullValue(cat, 3)) {
        GlobalVariable *classMethods = getValue(cat, 3);
        ConstantStruct *methodsPtr = dyn_cast<ConstantStruct>(classMethods->getInitializer());
        uint64_t count = (dyn_cast<ConstantInt>(methodsPtr->getOperand(1)))->getZExtValue();
        ConstantArray *list = dyn_cast<ConstantArray>(methodsPtr->getOperand(2));
        for (int i = 0; i < count; ++i) {
            ConstantStruct *methodStr = dyn_cast<ConstantStruct>(list->getOperand(i));
            GlobalVariable *methodName = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(methodStr->getOperand(0))->getOperand(0));
            if ([[DDIRUtil stringFromGlobalVariable:methodName] isEqualToString:@"load"]) {
                return true;
            }
            
        }
    }
    return false;
}

static void _clearObjcCategory(GlobalVariable *cat)
{
    [DDIRUtil removeValue:cat
          fromGlobalArray:[DDIRUtil getLlvmCompilerUsedInModule:cat->getParent()]
                 inModule:cat->getParent()];
    [DDIRUtil removeValue:cat
          fromGlobalArray:[DDIRUtil getGlabalArrayWithSection:"__DATA,__objc_catlist" inModule:cat->getParent()]
                 inModule:cat->getParent()];
    GlobalVariable *nonlazyLabel = [DDIRUtil getGlabalArrayWithSection:"__DATA,__objc_nlcatlist" inModule:cat->getParent()];
    if (nullptr != nonlazyLabel) {
        [DDIRUtil removeValue:cat
              fromGlobalArray:nonlazyLabel
                     inModule:cat->getParent()];
    }
    [DDIRUtil removeGlobalValue:cat inModule:cat->getParent()];
}

static void _addObjcCategoryToClass(GlobalVariable *cat, GlobalVariable *cls, bool shouldCheckLoadMethod)
{
    NSString *name = [DDIRUtil getObjcClassName:cls];
    GlobalVariable *ro = dyn_cast<GlobalVariable>(dyn_cast<ConstantStruct>(cls->getInitializer())->getOperand(4));
    // method list
    ro = _mergeObjcList(ro, 5, cat, 2, false, [[NSString stringWithFormat:@"_OBJC_$_INSTANCE_METHODS_%@", name] cStringUsingEncoding:NSUTF8StringEncoding]);
    // protocol list
    ro = _mergeObjcList(ro, 6, cat, 4, true, [[NSString stringWithFormat:@"_OBJC_CLASS_PROTOCOLS_$_%@", name] cStringUsingEncoding:NSUTF8StringEncoding]);
    // prop list
    ro = _mergeObjcList(ro, 8, cat, 5, false, [[NSString stringWithFormat:@"_OBJC_$_PROP_LIST_$_%@", name] cStringUsingEncoding:NSUTF8StringEncoding]);
    
    GlobalVariable *metalCls = dyn_cast<GlobalVariable>((dyn_cast<ConstantStruct>(cls->getInitializer()))->getOperand(0));
    GlobalVariable *metalRo = dyn_cast<GlobalVariable>(dyn_cast<ConstantStruct>(metalCls->getInitializer())->getOperand(4));
    // method list
    metalRo = _mergeObjcList(metalRo, 5, cat, 3, false, [[NSString stringWithFormat:@"_OBJC_$_CLASS_METHODS_%@", name] cStringUsingEncoding:NSUTF8StringEncoding], shouldCheckLoadMethod ? cls : nullptr);
    // prop list
    metalRo = _mergeObjcList(metalRo, 8, cat, 6, false, [[NSString stringWithFormat:@"_OBJC_$_PROP_LIST_CLASS_$_%@", name] cStringUsingEncoding:NSUTF8StringEncoding]);
}

static GlobalVariable *_addObjcCategoryToCategory(GlobalVariable *src, GlobalVariable *dst, bool shouldCheckLoadMethod)
{
    NSString *name = [DDIRUtil getObjcCategoryName:src];
    GlobalVariable *cls = dyn_cast<GlobalVariable>(src->getInitializer()->getOperand(1));
    NSString *clsName = [DDIRUtil getObjcClassName:cls];
    GlobalVariable * d = dst;
    // method list
    d = _mergeObjcList(d, 2, src, 2, false, [[NSString stringWithFormat:@"_OBJC_$_CATEGORY_INSTANCE_METHODS_%@_$_%@", clsName, name] cStringUsingEncoding:NSUTF8StringEncoding]);
    // method list
    d = _mergeObjcList(d, 3, src, 3, false, [[NSString stringWithFormat:@"_OBJC_$_CATEGORY_CLASS_METHODS_%@_$_%@", clsName, name] cStringUsingEncoding:NSUTF8StringEncoding], shouldCheckLoadMethod ? cls : nullptr);
    // protocol list
    d = _mergeObjcList(d, 4, src, 4, true, [[NSString stringWithFormat:@"_OBJC_CATEGORY_PROTOCOLS_$_%@_$_%@", clsName, name] cStringUsingEncoding:NSUTF8StringEncoding]);
    // prop list
    d = _mergeObjcList(d, 5, src, 5, false, [[NSString stringWithFormat:@"_OBJC_$_PROP_LIST_%@_$_%@", clsName, name] cStringUsingEncoding:NSUTF8StringEncoding]);
    // prop list
    d = _mergeObjcList(d, 6, src, 6, false, [[NSString stringWithFormat:@"_OBJC_$_PROP_LIST_CLASS_$_%@_$_%@", clsName, name] cStringUsingEncoding:NSUTF8StringEncoding]);
    return d;
}

static GlobalVariable *_mergeObjcList(GlobalVariable *dst, int dIndex, GlobalVariable *src, int sIndex, BOOL is64, const char *defaultName, GlobalVariable *cls = nullptr)
{
    GlobalVariable *dstList = ((dyn_cast<Constant>(dst->getInitializer()->getOperand(dIndex)))->getNumOperands() > 0 ? dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(dst->getInitializer()->getOperand(dIndex))->getOperand(0))) : NULL);
    GlobalVariable *srcList = ((dyn_cast<Constant>(src->getInitializer()->getOperand(sIndex)))->getNumOperands() > 0 ? dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(src->getInitializer()->getOperand(sIndex))->getOperand(0))) : NULL);
    if (nullptr != srcList) {
        if (nullptr != dstList) {
            assert(false == is64 || nullptr == cls);
            StringRef oldName = StringRef([[NSString stringWithFormat:@"%s", dstList->getName().data()] cStringUsingEncoding:NSUTF8StringEncoding]);
            dstList->setName(Twine([[NSString stringWithFormat:@"%s..", oldName.data()] cStringUsingEncoding:NSUTF8StringEncoding]));
            std::vector<Type *> types;
            std::vector<Constant *> data;
            std::vector<Constant *> list;
            ConstantArray *sArr = dyn_cast<ConstantArray>(dyn_cast<ConstantStruct>(srcList->getInitializer())->getOperand(is64 ? 1 : 2));
            Function *srcLoadFunction = nullptr;
            for (int i = 0; i < sArr->getNumOperands(); ++i) {
                Constant *val = sArr->getOperand(i);
                if (false == val->isNullValue()) {
                    if (nullptr != cls) {
                        // only useful for method list
                        GlobalVariable *methodName = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(val->getOperand(0))->getOperand(0));
                        if ([[DDIRUtil stringFromGlobalVariable:methodName] isEqualToString:@"load"]) {
                            srcLoadFunction = dyn_cast<Function>(dyn_cast<ConstantExpr>(val->getOperand(2))->getOperand(0));
                            continue;
                        }
                    }
                    list.push_back(sArr->getOperand(i));
                }
            }
            ConstantArray *dArr = dyn_cast<ConstantArray>(dyn_cast<ConstantStruct>(dstList->getInitializer())->getOperand(is64 ? 1 : 2));
            for (int i = 0; i < dArr->getNumOperands(); ++i) {
                Constant *val = dArr->getOperand(i);
                if (false == val->isNullValue()) {
                    if (nullptr != cls) {
                        // only useful for method list
                        GlobalVariable *methodName = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(val->getOperand(0))->getOperand(0));
                        if ([[DDIRUtil stringFromGlobalVariable:methodName] isEqualToString:@"load"]) {
                            Function *fun = dyn_cast<Function>(dyn_cast<ConstantExpr>(val->getOperand(2))->getOperand(0));
                            if (fun->getBasicBlockList().size() > 0) {
                                BasicBlock &block = fun->getEntryBlock();
                                int step = 0;
                                Instruction *selLoadInst = nullptr;
                                Instruction *clsCastInst = nullptr;
                                for (Instruction &inst : block.getInstList()) {
                                    if (0 == step) {
                                        step++;
                                    } else if (1 == step) {
                                        selLoadInst = std::addressof(inst);
                                        step++;
                                    } else if (2 == step) {
                                        clsCastInst = std::addressof(inst);
                                        break;
                                    }
                                }
                                block.back().eraseFromParent();  // remove return inst
                                IRBuilder<> builder(std::addressof(block));
                                std::vector<Value *> args;
                                args.push_back(clsCastInst);
                                args.push_back(selLoadInst);
                                builder.CreateCall(srcLoadFunction, args);
                                builder.CreateRetVoid();
                                
                            } else {
                                std::vector<Type *> typeList;
                                typeList.push_back(Type::getInt8PtrTy(dst->getContext()));
                                typeList.push_back(Type::getInt8PtrTy(dst->getContext()));
                                FunctionType *type = FunctionType::get(Type::getVoidTy(dst->getContext()), typeList, false);
                                Function *newFun = Function::Create(type, GlobalValue::InternalLinkage, [[NSString stringWithFormat:@"+[%@(DD) load]", [DDIRUtil getObjcClassName:cls]] cStringUsingEncoding:NSUTF8StringEncoding], dst->getParent());
                                BasicBlock *block = BasicBlock::Create(dst->getContext(), "", newFun);
                                IRBuilder<> builder(block);
                                GlobalVariable *clsRef = [DDIRUtil getAndCreateClassReference:cls inModule:dst->getParent()];
                                GlobalVariable *selRef = [DDIRUtil getAndCreateSelectorReference:"load" inClass:cls inModule:dst->getParent()];
                                auto clsLoadInst = builder.CreateLoad([DDIRUtil getStructType:IR_Objc_ClassTypeName inModule:dst->getParent()]->getPointerTo(), clsRef);
                                auto selLoadInst = builder.CreateLoad(Type::getInt8PtrTy(dst->getContext()), selRef);
                                auto clsCastInst = builder.CreateCast(Instruction::BitCast, clsLoadInst, Type::getInt8PtrTy(dst->getContext()));
                                std::vector<Value *> args;
                                args.push_back(clsCastInst);
                                args.push_back(selLoadInst);
                                builder.CreateCall(fun, args);
                                builder.CreateCall(srcLoadFunction, args);
                                builder.CreateRetVoid();
                                dyn_cast<ConstantExpr>(val->getOperand(2))->handleOperandChange(fun, newFun);
                            }
                        }
                    }
                    list.push_back(val);
                }
            }
            if (is64) {
                list.push_back(Constant::getNullValue(list.front()->getType()));
                types.push_back(Type::getInt64Ty(dst->getContext()));
                data.push_back(Constant::getIntegerValue(Type::getInt64Ty(dst->getContext()), APInt(64, list.size() - 1, false)));
            } else {
                types.push_back(Type::getInt32Ty(dst->getContext()));
                types.push_back(Type::getInt32Ty(dst->getContext()));
                data.push_back(dyn_cast<Constant>(dyn_cast<ConstantStruct>(dstList->getInitializer())->getOperand(0)));
                data.push_back(Constant::getIntegerValue(Type::getInt32Ty(dst->getContext()), APInt(32, list.size(), false)));
            }
            types.push_back(ArrayType::get(list.front()->getType(), list.size()));
            data.push_back(ConstantArray::get(ArrayType::get(list.front()->getType(), list.size()), list));
            Constant *val = ConstantStruct::get(StructType::get(dst->getContext(), types), data);
            GlobalVariable *newVariable = new GlobalVariable(*dstList->getParent(),
                                                             val->getType(),
                                                             dstList->isConstant(),
                                                             dstList->getLinkage(),
                                                             val,
                                                             oldName,
                                                             dstList,
                                                             dstList->getThreadLocalMode(),
                                                             dstList->getAddressSpace(),
                                                             dstList->isExternallyInitialized());
            newVariable->setAlignment(dstList->getAlign());
            newVariable->setUnnamedAddr(dstList->getUnnamedAddr());
            if (dstList->hasSection()) {
                newVariable->setSection(dstList->getSection());
            }
            if (dstList->hasComdat()) {
                newVariable->setComdat(dstList->getComdat());
            }
            [DDIRUtil replaceGlobalVariable:dstList with:newVariable];
            dstList->eraseFromParent();
            
        } else {
            assert(nullptr == cls);
            std::vector<Type *> types;
            std::vector<Constant *> data;
            std::vector<Constant *> list;
            ConstantArray *sArr = dyn_cast<ConstantArray>(dyn_cast<ConstantStruct>(srcList->getInitializer())->getOperand(is64 ? 1 : 2));
            for (int i = 0; i < sArr->getNumOperands(); ++i) {
                if (false == sArr->getOperand(i)->isNullValue()) {
                    list.push_back(sArr->getOperand(i));
                }
            }
            if (is64) {
                list.push_back(Constant::getNullValue(list.front()->getType()));
                types.push_back(Type::getInt64Ty(dst->getContext()));
                data.push_back(Constant::getIntegerValue(Type::getInt64Ty(dst->getContext()), APInt(64, list.size() - 1, false)));
            } else {
                types.push_back(Type::getInt32Ty(dst->getContext()));
                types.push_back(Type::getInt32Ty(dst->getContext()));
                data.push_back(dyn_cast<Constant>(dyn_cast<ConstantStruct>(srcList->getInitializer())->getOperand(0)));
                data.push_back(Constant::getIntegerValue(Type::getInt64Ty(dst->getContext()), APInt(32, list.size(), false)));
            }
            types.push_back(ArrayType::get(list.front()->getType(), list.size()));
            data.push_back(ConstantArray::get(ArrayType::get(list.front()->getType(), list.size()), list));
            Constant *val = ConstantStruct::get(StructType::get(dst->getContext(), types), data);
            GlobalVariable *newVariable = new GlobalVariable(*srcList->getParent(),
                                                             val->getType(),
                                                             srcList->isConstant(),
                                                             srcList->getLinkage(),
                                                             val,
                                                             defaultName,
                                                             srcList,
                                                             srcList->getThreadLocalMode(),
                                                             srcList->getAddressSpace(),
                                                             srcList->isExternallyInitialized());
            newVariable->setAlignment(srcList->getAlign());
            newVariable->setUnnamedAddr(srcList->getUnnamedAddr());
            if (srcList->hasSection()) {
                newVariable->setSection(srcList->getSection());
            }
            if (srcList->hasComdat()) {
                newVariable->setComdat(srcList->getComdat());
            }
            [DDIRUtil insertValue:ConstantExpr::getBitCast(newVariable, Type::getInt8PtrTy(dst->getContext()))
                    toGlobalArray:[DDIRUtil getLlvmCompilerUsedInModule:src->getParent()]
                               at:0
                         inModule:src->getParent()];
            std::vector<Constant *> d;
            for (int i = 0; i < dst->getInitializer()->getNumOperands(); ++i) {
                if (i == dIndex) {
                    d.push_back(ConstantExpr::getBitCast(newVariable, dst->getInitializer()->getOperand(i)->getType()));
                } else {
                    d.push_back(dyn_cast<Constant>(dst->getInitializer()->getOperand(i)));
                }
            }
            StringRef n = dst->getName();
            dst->setName("");
            GlobalVariable *v = [DDIRUtil createGlobalVariableName:n.data()
                                                fromGlobalVariable:dst
                                                              type:dst->getInitializer()->getType()
                                                       initializer:ConstantStruct::get(dyn_cast<StructType>(dst->getInitializer()->getType()), d)
                                                          inModule:dst->getParent()];
            [DDIRUtil replaceGlobalVariable:dst with:v];
            dst->eraseFromParent();
            return v;
        }
    }
    return dst;
}

#pragma mark empty
- (GlobalVariable *)_getDefaultEmptyProtocolWithConfiguration:(nonnull NSMutableDictionary *)configuration
{
    uint32_t controlId = (uint32_t)[[configuration objectForKey:ConfigurationKey_ControlId] unsignedIntegerValue];
    const NSString *key = @"DefaultProtocol";
    if (nil == [configuration objectForKey:key]) {
        NSString *name = [NSString stringWithFormat:@"DDEmptyProtocol_%u", controlId];
        GlobalVariable *protocol = [DDIRUtil getObjcProtocolLabel:name inModule:self.module];
        if (nullptr == protocol) {
            protocol = [DDIRUtil createObjcProtocol:[name cStringUsingEncoding:NSUTF8StringEncoding]
                                          withFlags:0
                                       protocolList:std::vector<Constant *>()
                                         methodList:std::vector<Constant *>()
                                    classMethodList:std::vector<Constant *>()
                                 optionalMethodList:std::vector<Constant *>()
                            optionalClassMethodList:std::vector<Constant *>()
                                           propList:std::vector<Constant *>()
                                      classPropList:std::vector<Constant *>()
                                           inModule:self.module];
        } else {
            protocol = dyn_cast<GlobalVariable>(protocol->getInitializer());
        }
        [configuration setObject:[NSValue valueWithPointer:protocol] forKey:key];
    }
    return (GlobalVariable *)[[configuration objectForKey:key] pointerValue];
}

- (ConstantStruct *)_getDefaultEmptyPropertyWithConfiguration:(nonnull NSMutableDictionary *)configuration
{
    uint32_t controlId = (uint32_t)[[configuration objectForKey:ConfigurationKey_ControlId] unsignedIntegerValue];
    const NSString *key = @"DefaultProperty";
    if (nil == [configuration objectForKey:key]) {
        StructType *methodType = [DDIRUtil getStructType:IR_Objc_PropTypeName inModule:self.module];
        std::vector<Constant *> datas;
        Constant *zero = ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 0);
        // atrribute
        GlobalVariable *attrName = [DDIRUtil createObjcMethodName:[[NSString stringWithFormat:@"dd_default_prop_%u", controlId] cStringUsingEncoding:NSUTF8StringEncoding]
                                                         inModule:self.module];
        datas.push_back(ConstantExpr::getInBoundsGetElementPtr(attrName->getInitializer()->getType(), attrName, (Constant *[]){zero, zero}));
        // type
        GlobalVariable *attrType = [DDIRUtil createObjcMethodName:"Tq,N,Vc" inModule:self.module];
        datas.push_back(ConstantExpr::getInBoundsGetElementPtr(attrType->getInitializer()->getType(), attrType, (Constant *[]){zero, zero}));
        [configuration setObject:[NSValue valueWithPointer:ConstantStruct::get(methodType, datas)] forKey:key];
    }
    return (ConstantStruct *)[[configuration objectForKey:key] pointerValue];
}

- (ConstantStruct *)_getEmptyFunctionWithConfiguration:(nonnull NSMutableDictionary *)configuration atIndex:(NSUInteger)index
{
    const NSString *key = @"FunctionList";
    NSMutableArray *arr = [configuration objectForKey:key];
    if (nil == arr) {
        arr = [NSMutableArray array];
        [configuration setObject:arr forKey:key];
    }
    ConstantStruct *str = nullptr;
    if (index < arr.count) {
        str = (ConstantStruct *)[[arr objectAtIndex:index] pointerValue];
    } else {
        [arr addObject:[NSValue valueWithPointer:[self _getEmptyFunctionWithFunctionName:@"dd_empty_function"]]];
    }
    return str;
}

- (ConstantStruct *)_getDefaultEmptyFunctionWithConfiguration:(nonnull NSMutableDictionary *)configuration
{
    uint32_t controlId = (uint32_t)[[configuration objectForKey:ConfigurationKey_ControlId] unsignedIntegerValue];
    const NSString *key = @"DefaultFunction";
    if (nil == [configuration objectForKey:key]) {
        [configuration setObject:[NSValue valueWithPointer:[self _getEmptyFunctionWithFunctionName:[NSString stringWithFormat:@"dd_default_empty_function_%u", controlId]]]
                          forKey:key];
    }
    return (ConstantStruct *)[[configuration objectForKey:key] pointerValue];
}

- (ConstantStruct *)_getEmptyFunctionWithFunctionName:(nonnull NSString *)functionName
{
    StructType *methodType = [DDIRUtil getStructType:IR_Objc_MethodTypeName inModule:self.module];
    std::vector<Constant *> datas;
    Constant *zero = ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 0);
    // name
    GlobalVariable *methodName = [DDIRUtil createObjcMethodName:[functionName cStringUsingEncoding:NSUTF8StringEncoding] inModule:self.module];
    datas.push_back(ConstantExpr::getInBoundsGetElementPtr(methodName->getInitializer()->getType(), methodName, (Constant *[]){zero, zero}));
    // type
    GlobalVariable *varType = [DDIRUtil createObjcVarType:"v16@0:8" inModule:self.module];
    datas.push_back(ConstantExpr::getInBoundsGetElementPtr(varType->getInitializer()->getType(), varType, (Constant *[]){zero, zero}));
    // function
    Function *fun = self.module->getFunction("-[DDDefault dd_default_empty_function]");
    if (nullptr == fun) {
        std::vector<Type *> typeList;
        typeList.push_back(Type::getInt8PtrTy(self.module->getContext()));
        typeList.push_back(Type::getInt8PtrTy(self.module->getContext()));
        FunctionType *type = FunctionType::get(Type::getVoidTy(self.module->getContext()), typeList, false);
        fun = Function::Create(type, GlobalValue::InternalLinkage, "-[DDDefault dd_default_empty_function]", self.module);
        BasicBlock *block = BasicBlock::Create(self.module->getContext(), "", fun);
        IRBuilder<> builder(block);
        builder.CreateRetVoid();
    }
    datas.push_back(ConstantExpr::getBitCast(fun, Type::getInt8PtrTy(self.module->getContext())));
    return dyn_cast<ConstantStruct>(ConstantStruct::get(methodType, datas));
}

#pragma mark Util
+ (nonnull NSString *)_getSpecialName
{
    return [NSString stringWithFormat:@"dd_special_name_%u", arc4random()];
}

+ (bool)_isSpecailName:(nonnull NSString *)name
{
    return [name hasPrefix:@"dd_special_name_"];
}
@end

@implementation DDIRModuleMergeInfo
+ (instancetype)infoWithTarget:(nonnull NSString *)target index:(NSUInteger)index
{
    DDIRModuleMergeInfo *info = [[DDIRModuleMergeInfo alloc] init];
    info.target = target;
    info.index  = index;
    return info;
}
@end

@implementation DDIRModulePath(Merge)
static const char *declareChangedRecordKey = "declareChangedRecord";
- (void)setDeclareChangedRecord:(DDIRChangeDeclareRecord *)declareChangedRecord
{
    objc_setAssociatedObject(self, declareChangedRecordKey, declareChangedRecord, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (DDIRChangeDeclareRecord *)declareChangedRecord
{
    return objc_getAssociatedObject(self, declareChangedRecordKey);
}
@end
