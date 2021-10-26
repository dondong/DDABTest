//
//  DDIRModule+Merge.m
//  DDToolKit
//
//  Created by dondong on 2021/10/21.
//

#import "DDIRModule+Merge.h"
#import "DDIRModule+Private.h"
#import "DDIRUtil.h"
#import "DDIRUtil+Objc.h"
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/Transforms/Utils/Cloning.h>
#include <llvm/IR/Constants.h>
#include <llvm/Linker/Linker.h>
#include <llvm/Transforms/IPO/Internalize.h>

using namespace llvm;

@interface DDIRModuleMergeInfo()
@property(nonatomic,strong,readwrite,nonnull) NSString *target;
@end

@implementation DDIRModule(Merge)
+ (void)mergeLLFiles:(nonnull NSArray<NSString *> *)pathes toLLFile:(nonnull NSString *)outputPath
{
    NSMutableArray<DDIRModule *> *moduleList = [NSMutableArray array];
    for (NSString *p in pathes) {
        DDIRModule *m = [DDIRModule moduleFromLLPath:p];
        [moduleList addObject:m];
    }
    NSMutableDictionary *mergeClassList = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeCategoryList = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeProtocolList = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeProtocolMap = [NSMutableDictionary dictionary];
    for (int i = 0; i < moduleList.count; ++i) {
        DDIRModule *module = moduleList[i];
        NSString *appendStr = [NSString stringWithFormat:@"%lu", (unsigned long)module.path.hash % 10000];
        NSMutableArray<NSArray<NSString *> *> *classChangeList    = [NSMutableArray array];
        NSMutableArray<NSArray<NSString *> *> *categoryChangeList = [NSMutableArray array];
        NSMutableArray<NSArray<NSString *> *> *protocolChangeList = [NSMutableArray array];
        DDIRModuleData *data = [module getData];
        for (DDIRObjCClass *c in data.objcClassList) {
            if (nil == [mergeClassList objectForKey:c.className]) {
                [mergeClassList setObject:@[[DDIRModuleMergeInfo infoWithTarget:c.className index:i]].mutableCopy forKey:c.className];
            } else {
                NSString *newName = [c.className stringByAppendingString:appendStr];
                [classChangeList addObject:@[c.className, newName]];
                [[mergeClassList objectForKey:c.className] addObject:[DDIRModuleMergeInfo infoWithTarget:newName index:i]];
            }
        }
        for (DDIRObjCCategory *c in data.objcCategoryList) {
            if (nil == [mergeCategoryList objectForKey:c.isa.className]) {
                [mergeCategoryList setObject:@[[DDIRModuleMergeInfo infoWithTarget:c.categoryName index:i]].mutableCopy forKey:c.isa.className];
            } else {
                [categoryChangeList addObject:@[c.isa.className, c.categoryName, appendStr]];
                [[mergeCategoryList objectForKey:c.isa.className] addObject:[DDIRModuleMergeInfo infoWithTarget:appendStr index:i]];
            }
        }
        for (DDIRObjCProtocol *p in data.objcProtocolList) {
            if (nil == [mergeProtocolList objectForKey:p.protocolName]) {
                [mergeProtocolList setObject:@[p.protocolName].mutableCopy forKey:p.protocolName];
                [mergeProtocolMap setObject:p.protocolName forKey:p.protocolName];
            } else {
                NSString *newName = [p.protocolName stringByAppendingString:appendStr];
                [protocolChangeList addObject:@[p.protocolName, newName]];
                [[mergeProtocolList objectForKey:p.protocolName] addObject:newName];
                [mergeProtocolMap setObject:p.protocolName forKey:newName];
            }
        }
        [module executeChangesWithBlock:^(DDIRModule * _Nullable m) {
            for (NSArray *arr in protocolChangeList) {
                [m replaceObjcProtocol:arr[0] withNewComponentName:arr[1]];
            }
            for (NSArray *arr in categoryChangeList) {
                [m replaceCategory:arr[1] forObjcClass:arr[0] withNewComponentName:arr[2]];
            }
            for (NSArray *arr in classChangeList) {
                [m replaceObjcClass:arr[0] withNewComponentName:arr[1]];
            }
        }];
    }
    
    [DDIRModule linkLLFiles:pathes toLLFile:outputPath];
    DDIRModule *module = [DDIRModule moduleFromLLPath:outputPath];
    
    [module executeChangesWithBlock:^(DDIRModule * _Nullable m) {
        for (NSString *name in mergeProtocolList.allKeys) {
            NSArray *nameList = [mergeProtocolList objectForKey:name];
            if (nameList.count > 0) {
                [m _mergeProtocols:nameList withMap:mergeProtocolMap];
            }
        }
        NSString *control = @"Control_$_1";
        [m addControlVariable:control section:@"__DATA, __dd_control"];
        for (NSString *name in mergeClassList.allKeys) {
            NSArray *clss = [mergeClassList objectForKey:name];
            if (clss.count > 0) {
                [m _mergeClassInfos:clss withSize:pathes.count controlVariable:control];
            }
        }
        for (NSString *name in mergeCategoryList.allKeys) {
            NSArray *cats = [mergeCategoryList objectForKey:name];
            if (cats.count > 0) {
                [m _mergeCategoryInfos:cats forClass:name withSize:pathes.count controlVariable:control];
            }
        }
    }];
}
- (void)mergeObjcData
{
    NSMutableDictionary<NSString *, NSValue *> *clsDic = [NSMutableDictionary dictionary];
    GlobalVariable *catSection = nullptr;
    Module::GlobalListType &globallist = self.module->getGlobalList();
    for (GlobalVariable &v : globallist) {
        if (v.hasSection()) {
            if (0 == strncmp(v.getSection().data(), "__DATA,__objc_classlist", 23)) {
                ConstantArray *arr = dyn_cast<ConstantArray>(v.getInitializer());
                for (int i = 0; i < arr->getNumOperands(); ++i) {
                    GlobalVariable *cls = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0));
                    [clsDic setObject:[NSValue valueWithPointer:cls] forKey:[DDIRUtil getObjcClassName:cls]];
                }
            } else if (0 == strncmp(v.getSection().data(), "__DATA,__objc_catlist", 21)) {
                catSection = std::addressof(v);
            }
        }
    }
    if (nullptr != catSection) {
        int currentIndex = 0;
        NSMutableDictionary<NSString *, NSValue *> *catDic = [NSMutableDictionary dictionary];
        do {
            ConstantArray *arr = dyn_cast<ConstantArray>(catSection->getInitializer());
            if (currentIndex < arr->getNumOperands()) {
                GlobalVariable *cat = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(currentIndex))->getOperand(0));
                NSString *clsName = [DDIRUtil getObjcClassNameFromCategory:cat];
                if (nil != [clsDic objectForKey:clsName]) {
                    GlobalVariable *cls = (GlobalVariable *)[[clsDic objectForKey:clsName] pointerValue];
                    _addObjcCategoryToClass(cat, cls);
                    catSection = [DDIRUtil removeValueAtIndex:currentIndex
                                              fromGlobalArray:catSection
                                                     inModule:self.module];
                    _clearObjcCategory(cat);
                    
                } else if (nil != [catDic objectForKey:clsName]) {
                    GlobalVariable *baseCat = (GlobalVariable *)[[catDic objectForKey:clsName] pointerValue];
                    _addObjcCategoryToCategory(cat, baseCat);
                    catSection = [DDIRUtil removeValueAtIndex:currentIndex
                                              fromGlobalArray:catSection
                                                     inModule:self.module];
                    _clearObjcCategory(cat);
                    
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

- (void)_mergeClassInfos:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos withSize:(NSUInteger)size controlVariable:(nonnull NSString *)varName
{
    if (infos.count <= 1) {
        return;
    }
    GlobalVariable *superCls = nullptr;
    GlobalVariable *metaSuperCls = nullptr;
    NSString *clsName = nil;
    uint32_t flags = 0;
    uint32_t instanceStart = 0;
    uint32_t instanceSize  = 0;
    std::vector<Constant *> instMethodList;
    std::vector<Constant *> classMethodList;
    std::vector<Constant *> ivarList;
    std::vector<Constant *> procotolList;
    std::vector<Constant *> instPropList;
    std::vector<Constant *> classPropList;
    
    NSMutableArray *clsArray = [NSMutableArray array];
    NSMutableDictionary *instMethodDic  = [NSMutableDictionary dictionary];
    NSMutableDictionary *classMethodDic = [NSMutableDictionary dictionary];
    NSMutableDictionary *ivarDic        = [NSMutableDictionary dictionary];
    NSMutableDictionary *procotolDic    = [NSMutableDictionary dictionary];
    NSMutableDictionary *instPropDic    = [NSMutableDictionary dictionary];
    NSMutableDictionary *classPropDic   = [NSMutableDictionary dictionary];
    for (int i = 0; i < infos.count; ++i) {
        GlobalVariable *cls = [DDIRUtil getObjcClass:infos[i].target inModule:self.module];
        assert(nullptr != cls);
        [clsArray addObject:[NSValue valueWithPointer:cls]];
        cls->setName("");
        GlobalVariable *metaCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(0));
        metaCls->setName("");
        GlobalVariable *ro = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(4));
        ro->setName("");
        GlobalVariable *metaRo = dyn_cast<GlobalVariable>(metaCls->getInitializer()->getOperand(4));
        metaRo->setName("");
        flags |= dyn_cast<ConstantInt>(ro->getInitializer()->getOperand(0))->getZExtValue();
        instanceStart = (uint32_t)MIN(instanceStart, dyn_cast<ConstantInt>(ro->getInitializer()->getOperand(1))->getZExtValue());
        instanceSize  = (uint32_t)MAX(instanceSize, dyn_cast<ConstantInt>(ro->getInitializer()->getOperand(2))->getZExtValue());
        // fuction
        void (^funBlock)(GlobalVariable *, NSMutableDictionary *) = ^(GlobalVariable *r, NSMutableDictionary *dic) {
            if (isNullValue(r, 5)) {
                GlobalVariable *v = getValue(r, 5);
                v->setName("");
                ConstantStruct *s = dyn_cast<ConstantStruct>(v->getInitializer());
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
        funBlock(ro, instMethodDic);
        funBlock(metaRo, classMethodDic);
        // protocol
        if (isNullValue(ro, 6)) {
            GlobalVariable *v = getValue(ro, 6);
            v->setName("");
            ConstantStruct *s = dyn_cast<ConstantStruct>(v->getInitializer());
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
        // ivar
        if (isNullValue(ro, 7)) {
            GlobalVariable *v = getValue(ro, 7);
            v->setName("");
            ConstantStruct *s = dyn_cast<ConstantStruct>(v->getInitializer());
            uint64_t count = (dyn_cast<ConstantInt>(s->getOperand(1)))->getZExtValue();
            ConstantArray *list = dyn_cast<ConstantArray>(s->getOperand(2));
            for (int j = 0; j < count; ++j) {
                ConstantStruct *m = dyn_cast<ConstantStruct>(list->getOperand(j));
                NSString *name = [DDIRUtil stringFromGlobalVariable:dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(m->getOperand(1)))->getOperand(0))];
                NSNumber *b = [ivarDic objectForKey:name];
                if (nil == b) {
                    ivarList.push_back(m);
                    [ivarDic setObject:@(YES) forKey:name];
                }
            }
        }
        // prop
        void (^propBlock)(GlobalVariable *, NSMutableDictionary *, std::vector<Constant *>&) = ^(GlobalVariable *r, NSMutableDictionary *dic, std::vector<Constant *>& l) {
            if (isNullValue(r, 9)) {
                GlobalVariable *v = getValue(r, 9);
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
        propBlock(ro, instPropDic, instPropList);
        propBlock(metaRo, classPropDic, classPropList);
        
        if (0 == i) {
            clsName = [DDIRUtil stringFromGlobalVariable:getValue(ro, 4)];
            superCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(1));
            metaSuperCls = dyn_cast<GlobalVariable>(metaCls->getInitializer()->getOperand(1));
        }
    }
    
    GlobalVariable *ctr = self.module->getNamedGlobal([varName cStringUsingEncoding:NSUTF8StringEncoding]);
    [self _mergeSameFunctionSets:instMethodDic toList:instMethodList control:ctr];
    [self _mergeSameFunctionSets:classMethodDic toList:classMethodList control:ctr];
    
    GlobalVariable *cls = [DDIRUtil createObjcClass:[clsName cStringUsingEncoding:NSUTF8StringEncoding]
                                          withSuper:superCls
                                          metaSuper:metaSuperCls
                                              flags:flags
                                      instanceStart:instanceStart
                                       instanceSize:instanceSize
                                         methodList:instMethodList
                                    classMethodList:classMethodList
                                           ivarList:ivarList
                                       protocolList:procotolList
                                           propList:instPropList
                                      classPropList:classPropList
                                           inModule:self.module];
    GlobalVariable *metaCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(0));
    for (NSValue *v in clsArray) {
        GlobalVariable *c = (GlobalVariable *)v.pointerValue;
        std::vector<GlobalVariable *> gl;
        std::vector<ConstantStruct *> sl;
        for (User *u : c->users()) {
            if (nullptr != dyn_cast<GlobalVariable>(u)) {
                gl.push_back(dyn_cast<GlobalVariable>(u));
            } else if (nullptr != dyn_cast<ConstantStruct>(u)) {
                sl.push_back(dyn_cast<ConstantStruct>(u));
            }
        }
        for (GlobalVariable *v : gl) {
            GlobalVariable *n = [DDIRUtil createGlobalVariableName:v->getName().data()
                                                fromGlobalVariable:v
                                                              type:nullptr
                                                       initializer:cls
                                                          inModule:self.module];
            [DDIRUtil replaceGlobalVariable:v with:n];
            v->eraseFromParent();
        }
        for (ConstantStruct *s : sl) {
            s->handleOperandChange(c, cls);
        }
        GlobalVariable *metaC = dyn_cast<GlobalVariable>(c->getInitializer()->getOperand(0));
        std::vector<GlobalVariable *> metaGL;
        std::vector<ConstantStruct *> metaSl;
        for (User *u : metaC->users()) {
            if (nullptr != dyn_cast<GlobalVariable>(u)) {
                metaGL.push_back(dyn_cast<GlobalVariable>(u));
            } else if (nullptr != dyn_cast<ConstantStruct>(u)) {
                ConstantStruct *s = dyn_cast<ConstantStruct>(u);
                if (s != c->getInitializer()) {
                    metaSl.push_back(dyn_cast<ConstantStruct>(u));
                }
            }
        }
        for (GlobalVariable *v : metaGL) {
            GlobalVariable *n = [DDIRUtil createGlobalVariableName:v->getName().data()
                                                fromGlobalVariable:v
                                                              type:nullptr
                                                       initializer:metaCls
                                                          inModule:self.module];
            [DDIRUtil replaceGlobalVariable:v with:n];
            v->eraseFromParent();
        }
        for (ConstantStruct *s : metaSl) {
            s->handleOperandChange(metaC, metaCls);
        }
        c->removeDeadConstantUsers();
        metaC->removeDeadConstantUsers();
        [DDIRUtil removeGlobalValue:c inModule:self.module];
    }
}

- (void)_mergeCategoryInfos:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos
                   forClass:(nonnull NSString *)clsName
                   withSize:(NSUInteger)size
            controlVariable:(nonnull NSString *)varName
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
    
    GlobalVariable *ctr = self.module->getNamedGlobal([varName cStringUsingEncoding:NSUTF8StringEncoding]);
    [self _mergeSameFunctionSets:instMethodDic toList:instMethodList control:ctr];
    [self _mergeSameFunctionSets:classMethodDic toList:classMethodList control:ctr];
    
    [DDIRUtil createObjcCategory:[[infos[0].target stringByAppendingString:@"_dd"] cStringUsingEncoding:NSUTF8StringEncoding]
                             cls:[DDIRUtil getObjcClass:clsName inModule:self.module]
                  withMethodList:instMethodList
                 classMethodList:classMethodList
                    protocolList:procotolList
                        propList:instPropList
                   classPropList:classPropList
                        inModule:self.module];
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

- (void)_mergeSameFunctionSets:(NSDictionary *)dic toList:(std::vector<Constant *>&)list control:(GlobalVariable *)ctr
{
    for (NSString *n in dic.allKeys) {
        NSArray *a = [dic objectForKey:n];
        if (a.count > 1) {
            NSMutableArray *i = [NSMutableArray array];
            for (NSArray *v in a) {
                ConstantStruct *m = (ConstantStruct *)[v[0] pointerValue];
                Function *f = dyn_cast<Function>((dyn_cast<ConstantExpr>(m->getOperand(2)))->getOperand(0));
                [i addObject:[DDIRModuleMergeInfo infoWithTarget:[NSString stringWithCString:f->getName().data() encoding:NSUTF8StringEncoding]
                                                                index:[v[1] integerValue]]];
            }
            ConstantStruct *m = (ConstantStruct *)[[a[0] objectAtIndex:0] pointerValue];
            Function *f = [self _mergeFunctions:i withControl:ctr];
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

- (Function *)_mergeFunctions:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos withControl:(GlobalVariable *)control
{
    Function *bf = self.module->getFunction([infos[0].target cStringUsingEncoding:NSUTF8StringEncoding]);
    bf->setName(Twine([[NSString stringWithFormat:@"%s..", bf->getName().data()] cStringUsingEncoding:NSUTF8StringEncoding]));
    Function *baseFun = Function::Create(bf->getFunctionType(), bf->getLinkage(), [infos[0].target cStringUsingEncoding:NSUTF8StringEncoding], self.module);
    infos[0].target = [NSString stringWithUTF8String:bf->getName().data()];
    BasicBlock *baseBlock = BasicBlock::Create(self.module->getContext(), "", baseFun);
    BasicBlock *defaultBlock = BasicBlock::Create(self.module->getContext(), "", baseFun);
    IRBuilder<> builder(baseBlock);
    SwitchInst * inst = builder.CreateSwitch(builder.CreateLoad(control->getInitializer()->getType(), control),
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
    return baseFun;
}

static void _clearObjcCategory(GlobalVariable *cat)
{
    [DDIRUtil removeValue:cat
          fromGlobalArray:[DDIRUtil getLlvmCompilerUsedInModule:cat->getParent()]
                 inModule:cat->getParent()];
    ConstantStruct *str = dyn_cast<ConstantStruct>(cat->getInitializer());
    assert(nullptr != str && 8 == str->getNumOperands());
    NSMutableArray *vs = [NSMutableArray array];
    [vs addObject:[NSValue valueWithPointer:dyn_cast<GlobalVariable>(dyn_cast<Constant>(str->getOperand(0))->getOperand(0))]];
    for (int i = 2; i < 7; ++i) {
        if (dyn_cast<Constant>(str->getOperand(i))->getNumOperands() > 0) {
            GlobalVariable *v = dyn_cast<GlobalVariable>(dyn_cast<Constant>(str->getOperand(i))->getOperand(0));
            [vs addObject:[NSValue valueWithPointer:v]];
        }
    }
    cat->eraseFromParent();
    for (NSValue *p in vs) {
        GlobalVariable *v = (GlobalVariable *)p.pointerValue;
        [DDIRUtil removeValue:v
              fromGlobalArray:[DDIRUtil getLlvmCompilerUsedInModule:v->getParent()]
                     inModule:v->getParent()];
        v->eraseFromParent();
    }
}

static void _addObjcCategoryToClass(GlobalVariable *cat, GlobalVariable *cls)
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
    metalRo = _mergeObjcList(metalRo, 5, cat, 3, false, [[NSString stringWithFormat:@"_OBJC_$_CLASS_METHODS_%@", name] cStringUsingEncoding:NSUTF8StringEncoding]);
    // prop list
    metalRo = _mergeObjcList(metalRo, 8, cat, 6, false, [[NSString stringWithFormat:@"_OBJC_$_PROP_LIST_CLASS_$_%@", name] cStringUsingEncoding:NSUTF8StringEncoding]);
}

static GlobalVariable *_addObjcCategoryToCategory(GlobalVariable *src, GlobalVariable *dst)
{
    NSString *name = [DDIRUtil getObjcCategoryName:src];
    NSString *clsName = [DDIRUtil getObjcClassNameFromCategory:src];
    GlobalVariable * d = dst;
    // method list
    d = _mergeObjcList(d, 2, src, 2, false, [[NSString stringWithFormat:@"_OBJC_$_CATEGORY_INSTANCE_METHODS_%@_$_%@", clsName, name] cStringUsingEncoding:NSUTF8StringEncoding]);
    // method list
    d = _mergeObjcList(d, 3, src, 3, false, [[NSString stringWithFormat:@"_OBJC_$_CATEGORY_CLASS_METHODS_%@_$_%@", clsName, name] cStringUsingEncoding:NSUTF8StringEncoding]);
    // protocol list
    d = _mergeObjcList(d, 4, src, 4, true, [[NSString stringWithFormat:@"_OBJC_CATEGORY_PROTOCOLS_$_%@_$_%@", clsName, name] cStringUsingEncoding:NSUTF8StringEncoding]);
    // prop list
    d = _mergeObjcList(d, 5, src, 5, false, [[NSString stringWithFormat:@"_OBJC_$_PROP_LIST_%@_$_%@", clsName, name] cStringUsingEncoding:NSUTF8StringEncoding]);
    // prop list
    d = _mergeObjcList(d, 6, src, 6, false, [[NSString stringWithFormat:@"_OBJC_$_PROP_LIST_CLASS_$_%@_$_%@", clsName, name] cStringUsingEncoding:NSUTF8StringEncoding]);
    return d;
}

static GlobalVariable *_mergeObjcList(GlobalVariable *dst, int dIndex, GlobalVariable *src, int sIndex, BOOL is64, const char *defaultName)
{
    GlobalVariable *dstList = ((dyn_cast<Constant>(dst->getInitializer()->getOperand(dIndex)))->getNumOperands() > 0 ? dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(dst->getInitializer()->getOperand(dIndex))->getOperand(0))) : NULL);
    GlobalVariable *srcList = ((dyn_cast<Constant>(src->getInitializer()->getOperand(sIndex)))->getNumOperands() > 0 ? dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(src->getInitializer()->getOperand(sIndex))->getOperand(0))) : NULL);
    if (nullptr != srcList) {
        if (nullptr != dstList) {
            StringRef oldName = StringRef([[NSString stringWithFormat:@"%s", dstList->getName().data()] cStringUsingEncoding:NSUTF8StringEncoding]);
            dstList->setName(Twine([[NSString stringWithFormat:@"%s..", oldName.data()] cStringUsingEncoding:NSUTF8StringEncoding]));
            std::vector<Type *> types;
            std::vector<Constant *> data;
            std::vector<Constant *> list;
            ConstantArray *dArr = dyn_cast<ConstantArray>(dyn_cast<ConstantStruct>(dstList->getInitializer())->getOperand(is64 ? 1 : 2));
            for (int i = 0; i < dArr->getNumOperands(); ++i) {
                if (false == dArr->getOperand(i)->isNullValue()) {
                    list.push_back(dArr->getOperand(i));
                }
            }
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
