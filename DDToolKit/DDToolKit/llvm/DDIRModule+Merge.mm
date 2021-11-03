//
//  DDIRModule+Merge.m
//  DDToolKit
//
//  Created by dondong on 2021/10/21.
//

#import "DDIRModule+Merge.h"
#import "DDIRModule+Private.h"
#import "DDCommonDefine.h"
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
+ (void)mergeLLFiles:(nonnull NSArray<NSString *> *)pathes withControlId:(UInt32)controlId toLLFile:(nonnull NSString *)outputPath
{
    NSMutableArray<DDIRModule *> *moduleList = [NSMutableArray array];
    for (NSString *p in pathes) {
        DDIRModule *m = [DDIRModule moduleFromLLPath:p];
        [moduleList addObject:m];
    }
    NSMutableDictionary *mergeConfiguration = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeClassList = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeCategoryList = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeProtocolList = [NSMutableDictionary dictionary];
    NSMutableDictionary *mergeProtocolMap = [NSMutableDictionary dictionary];
    for (int i = 0; i < moduleList.count; ++i) {
        DDIRModule *module = moduleList[i];
        [mergeConfiguration setObject:[NSMutableArray array] forKey:[NSString stringWithFormat:@"class_%d", i]];
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
            NSString *key = [NSString stringWithFormat:@"class_%d", i];
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
        // category
        NSString *control = [NSString stringWithFormat:@"Control_$_dd_%d", controlId];
        [m addControlVariable:control controlId:controlId section:[NSString stringWithFormat:@"__DATA,%@", DDControlSection]];
        for (NSString *name in mergeCategoryList.allKeys) {
            NSArray *cats = [mergeCategoryList objectForKey:name];
            if (cats.count > 0) {
                [m _mergeCategoryInfos:cats forClass:name withSize:pathes.count controlVariable:control];
            }
        }
    }];
}

#pragma mark change
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

- (void)addControlVariable:(nonnull NSString *)name controlId:(UInt32)controlId section:(nonnull NSString *)section
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
}

#pragma mark private

- (void)_mergeClassInfos:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos configuration:(nonnull NSMutableDictionary *)configuration
{
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
    Constant *defaultName = dyn_cast<Constant>(defaultRo->getInitializer()->getOperand(4));
    StructType *mapType = [self _getClassMapType];
    for (int i = 0; i < infos.count; ++i) {
        GlobalVariable *cls = [DDIRUtil getObjcClass:infos[i].target inModule:self.module];
        GlobalVariable *metaCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(0));
        GlobalVariable *ro = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(4));
        GlobalVariable *metaRo = dyn_cast<GlobalVariable>(metaCls->getInitializer()->getOperand(4));
        GlobalVariable *superCls = dyn_cast<GlobalVariable>(cls->getInitializer()->getOperand(1));
        assert(nullptr != superCls);
        std::vector<Constant *> datas;
        datas.push_back(defautCls);
        datas.push_back(superCls);
        datas.push_back(ro);
        datas.push_back(metaRo);
        NSMutableArray *arr = [configuration objectForKey:[NSString stringWithFormat:@"class_%ld", (long)infos[i].index]];
        GlobalVariable *item = new GlobalVariable(*self.module,
                                                  mapType,
                                                  false,
                                                  GlobalValue::InternalLinkage,
                                                  ConstantStruct::get(mapType, datas),
                                                  "_DD_OBJC_Class_MAP_$_tmp");
        [arr addObject:[NSValue valueWithPointer:item]];
        if (0 != i) {
            ro->getInitializer()->handleOperandChange(ro->getInitializer()->getOperand(4), defaultName);
            metaRo->getInitializer()->handleOperandChange(metaRo->getInitializer()->getOperand(4), defaultName);
            dropClsArray.push_back(cls);
        }
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

- (StructType * _Nonnull)_getClassMapType
{
    const char *name = "struct._dd_class_map_t";
    StructType *mapType = [DDIRUtil getStructType:name inModule:self.module];
    if (nullptr == mapType) {
        StructType *classType = [DDIRUtil getStructType:IR_Objc_ClassTypeName inModule:self.module];
        StructType *roType    = [DDIRUtil getStructType:IR_Objc_RoTypeName inModule:self.module];
        mapType = StructType::create(self.module->getContext(), name);
        mapType->setBody(classType->getPointerTo(),
                         classType->getPointerTo(),
                         roType->getPointerTo(),
                         roType->getPointerTo());
    }
    return mapType;
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

- (void)_mergeCategoryInfos:(nonnull NSArray<DDIRModuleMergeInfo *> *)infos
                   forClass:(nonnull NSString *)clsName
                   withSize:(NSUInteger)size
              configuration:(nonnull NSMutableDictionary *)configuration
{
    __block NSMutableArray *emptyFunctionList = [configuration objectForKey:@""];
    __block NSUInteger funIndex = 0;
    uint32_t maxInstanceMethodCount   = 0;
    uint32_t maxClassMethodCount      = 0;
    uint32_t maxInstancePropertyCount = 0;
    uint32_t maxClassPropertyCount    = 0;
    uint32_t maxProtocolCount         = 0;
    for (DDIRModuleMergeInfo *info in infos) {
        GlobalVariable *category = [DDIRUtil getCategory:info.target forObjcClass:clsName inModule:self.module];
        if (isNullValue(category, 2)) {
            maxInstanceMethodCount = MAX(maxInstanceMethodCount, (uint32_t)dyn_cast<ConstantInt>(getValue(category, 2)->getOperand(1))->getZExtValue());
        }
        if (isNullValue(category, 3)) {
            maxClassMethodCount = MAX(maxClassMethodCount, (uint32_t)dyn_cast<ConstantInt>(getValue(category, 3)->getOperand(1))->getZExtValue());
        }
        if (isNullValue(category, 4)) {
            maxProtocolCount = MAX(maxProtocolCount, (uint32_t)dyn_cast<ConstantInt>(getValue(category, 4)->getOperand(0))->getZExtValue());
        }
        if (isNullValue(category, 5)) {
            maxInstancePropertyCount = MAX(maxInstancePropertyCount, (uint32_t)dyn_cast<ConstantInt>(getValue(category, 5)->getOperand(1))->getZExtValue());
        }
        if (isNullValue(category, 6)) {
            maxClassPropertyCount = MAX(maxClassPropertyCount, (uint32_t)dyn_cast<ConstantInt>(getValue(category, 6)->getOperand(1))->getZExtValue());
        }
    }
    GlobalVariable *emptyCategory = nullptr;
    for (int i = 0; i < size; ++i) {
        GlobalVariable *category = nullptr;
        for (DDIRModuleMergeInfo *info in infos) {
            if (i == info.index) {
                category = [DDIRUtil getCategory:info.target forObjcClass:clsName inModule:self.module];
                break;
            }
        }
        
        ConstantStruct *(^getMethodBlock)() = ^() {
            ConstantStruct *str = nullptr;
            if (emptyFunctionList.count == funIndex) {
                StructType *methodType = [DDIRUtil getStructType:IR_Objc_MethodTypeName inModule:self.module];
                std::vector<Constant *> datas;
                // name
                // type
                // function
                std::vector<Type *> typeList;
                typeList.push_back(Type::getInt8PtrTy(self.module->getContext()));
                typeList.push_back(Type::getInt8PtrTy(self.module->getContext()));
                FunctionType *type = FunctionType::get(Type::getVoidTy(self.module->getContext()), typeList, false);
                datas.push_back(ConstantExpr::getBitCast(Function::Create(type, GlobalValue::PrivateLinkage, "dd_empty_function", self.module), Type::getInt8PtrTy(self.module->getContext())));
                str = dyn_cast<ConstantStruct>(ConstantStruct::get(methodType, datas));
                [emptyFunctionList addObject:[NSValue valueWithPointer:str]];
            } else {
                str = (ConstantStruct *)[[emptyFunctionList objectAtIndex:funIndex] pointerValue];
            }
            
            return str;
        };
        if (nullptr != category) {
            void (^methodBlock)(uint32_t, uint32_t) = ^(uint32_t index, uint32_t maxCount) {
                if (maxCount > 0) {
                    if (!isNullValue(category, index) || maxCount != dyn_cast<ConstantInt>(getValue(category, index)->getOperand(1))->getZExtValue()) {
                        if (isNullValue(category, index)) {
                            
                        }
                    }
                }
            };
            methodBlock(2, maxInstanceMethodCount);
            methodBlock(3, maxClassMethodCount);
            if (0 != i) {
                [DDIRUtil removeValue:category
                      fromGlobalArray:[DDIRUtil getGlabalArrayWithSection:"__DATA,__objc_catlist" inModule:self.module]
                             inModule:self.module];
            }
        } else {
            if (nullptr == emptyCategory) {
                
            }
            category = emptyCategory;
        }
        
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

#pragma mark empty
- (GlobalVariable *)_getDefaultEmptyProtocolWithConfiguration:(nonnull NSMutableDictionary *)configuration
{
    const NSString *key = @"DefaultProtocol";
    if (nil == [configuration objectForKey:key]) {
        NSString *name = @"DDEmptyProtocol";
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
    const NSString *key = @"DefaultProperty";
    if (nil == [configuration objectForKey:key]) {
        StructType *methodType = [DDIRUtil getStructType:IR_Objc_PropTypeName inModule:self.module];
        std::vector<Constant *> datas;
        Constant *zero = ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 0);
        // atrribute
        GlobalVariable *attrName = [DDIRUtil createObjcMethodName:"dd_default_prop" inModule:self.module];
        datas.push_back(ConstantExpr::getInBoundsGetElementPtr(attrName->getInitializer()->getType(), attrName, (Constant *[]){zero, zero}));
        // type
        GlobalVariable *attrType = [DDIRUtil createObjcMethodName:"TQ,R" inModule:self.module];
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
        [arr addObject:[NSValue valueWithPointer:[self _getEmptyFunctionWithClassName:@"DDUnknown" functionName:@"dd_empty_function"]]];
    }
    return str;
}

- (ConstantStruct *)_getDefaultEmptyFunctionWithConfiguration:(nonnull NSMutableDictionary *)configuration
{
    const NSString *key = @"DefaultFunction";
    if (nil == [configuration objectForKey:key]) {
        [configuration setObject:[NSValue valueWithPointer:[self _getEmptyFunctionWithClassName:@"DDUnknown" functionName:@"dd_default_empty_function"]]
                          forKey:key];
    }
    return (ConstantStruct *)[[configuration objectForKey:key] pointerValue];
}

- (ConstantStruct *)_getEmptyFunctionWithClassName:(nonnull NSString *)className functionName:(nonnull NSString *)functionName
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
    std::vector<Type *> typeList;
    typeList.push_back(Type::getInt8PtrTy(self.module->getContext()));
    typeList.push_back(Type::getInt8PtrTy(self.module->getContext()));
    FunctionType *type = FunctionType::get(Type::getVoidTy(self.module->getContext()), typeList, false);
    Function *fun = Function::Create(type, GlobalValue::InternalLinkage, [[NSString stringWithFormat:@"-[%@ %@]", className, functionName] cStringUsingEncoding:NSUTF8StringEncoding], self.module);
    BasicBlock *block = BasicBlock::Create(self.module->getContext(), "", fun);
    IRBuilder<> builder(block);
    builder.CreateRetVoid();
    datas.push_back(ConstantExpr::getBitCast(fun, Type::getInt8PtrTy(self.module->getContext())));
    return dyn_cast<ConstantStruct>(ConstantStruct::get(methodType, datas));
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
