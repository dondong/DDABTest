//
//  DDIRModule.m
//  DDToolKit
//
//  Created by dondong on 2021/8/30.
//

#import "DDIRModule.h"
#import "DDIRModule+Private.h"
#import "DDIRUtil.h"
#import "DDIRUtil+Objc.h"
#include <llvm/AsmParser/Parser.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/IRBuilder.h>
#include <llvm/IR/Constants.h>
#include <llvm/Transforms/Utils/Cloning.h>
#include <llvm/Transforms/IPO/Internalize.h>
#include <llvm/Support/ToolOutputFile.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/MemoryBuffer.h>
#include <llvm/Bitcode/BitcodeReader.h>
#include <llvm/Bitcode/BitcodeWriter.h>
#include <llvm/Linker/Linker.h>
#include <system_error>

using namespace llvm;

@interface DDIRModuleData()
@property(nonatomic,assign,readwrite) BOOL isBitcode;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRStringVariable *> *stringList;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRObjCClass *> *objcClassList;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRObjCCategory *> *objcCategoryList;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRObjCProtocol *> *objcProtocolList;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRFunction *> *ctorFunctionList;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRFunction *> *functionList;
@end

@implementation DDIRModule
+ (nullable instancetype)moduleFromPath:(nonnull NSString *)path
{
    if ([[path lowercaseString] hasSuffix:@".bc"]) {
        return [self moduleFromBCPath:path];
    } else if ([[path lowercaseString] hasSuffix:@".ll"]) {
        return [self moduleFromLLPath:path];
    }
    return nil;
}

+ (nullable instancetype)moduleFromBCPath:(nonnull NSString *)path
{
    static ExitOnError exitOnErr;
    std::unique_ptr<MemoryBuffer> memoryBuffer = exitOnErr(errorOrToExpected(MemoryBuffer::getFileOrSTDIN([path cStringUsingEncoding:NSUTF8StringEncoding])));
    BitcodeFileContents fileContents = exitOnErr(llvm::getBitcodeFileContents(*memoryBuffer));
    const size_t size = fileContents.Mods.size();
    if (1 != size) {
        memoryBuffer.release();
        return nil;
    }
    LLVMContext context;
    BitcodeModule bitcodeModule = fileContents.Mods[0];
    std::unique_ptr<Module> m = exitOnErr(bitcodeModule.getLazyModule(context, false, false));
    if (nullptr == m) {
        return nil;
    }
    memoryBuffer.release();
    m.release();
    
    DDIRModule *module = [[DDIRModule alloc] init];
    module.path = path;
    return module;
}

+ (nullable instancetype)moduleFromLLPath:(nonnull NSString *)path
{
    LLVMContext context;
    SMDiagnostic err;
    std::unique_ptr<Module> ptr = parseAssemblyFile([path cStringUsingEncoding:NSUTF8StringEncoding], err, context);
    if (nullptr == ptr) {
        return nil;
    }
    ptr.release();
    
    DDIRModule *module = [[DDIRModule alloc] init];
    module.path = path;
    return module;
}

+ (void)linkIRFiles:(nonnull NSArray<NSString *> *)pathes toIRFile:(nonnull NSString *)outputPath
{
    if (pathes.count <= 0) {
        return;
    }
    LLVMContext context;
    auto basePtr = std::make_unique<Module>("DDTool", context);
    Linker linker(*basePtr);
    if (nullptr != basePtr) {
        // merge module
        BOOL hasCls = false;
        BOOL hasCat = false;
        BOOL hasNoLazyCls = false;
        BOOL hasNoLazyCat = false;
        NSMutableDictionary *protocolDic = [NSMutableDictionary dictionary];
        for (int i = 0; i < pathes.count; ++i) {
            std::unique_ptr<Module> ptr = nullptr;
            if ([[pathes[i] lowercaseString] hasSuffix:@".bc"]) {
                static ExitOnError exitOnErr;
                std::unique_ptr<MemoryBuffer> memoryBuffer = exitOnErr(errorOrToExpected(MemoryBuffer::getFileOrSTDIN([pathes[i] cStringUsingEncoding:NSUTF8StringEncoding])));
                BitcodeFileContents fileContents = exitOnErr(llvm::getBitcodeFileContents(*memoryBuffer));
                assert(1 == fileContents.Mods.size());
                BitcodeModule bitcodeModule = fileContents.Mods[0];
                ptr = exitOnErr(bitcodeModule.parseModule(context));
                memoryBuffer.release();
            } else if ([[pathes[i] lowercaseString] hasSuffix:@".ll"]) {
                SMDiagnostic err;
                ptr = parseAssemblyFile([pathes[i] cStringUsingEncoding:NSUTF8StringEncoding], err, context);
            } else {
                assert("Unknown input file type");
            }
            if (nullptr != ptr) {
                NSMutableArray *removeArray = [NSMutableArray array];
                Module::GlobalListType &globallist = ptr->getGlobalList();
                for (GlobalVariable &v : globallist) {
                    if (v.hasSection()) {
                        BOOL isCls = false;
                        BOOL isCat = false;
                        BOOL isNoLazyCls = false;
                        BOOL isNoLazyCat = false;
                        if (0 == strncmp(v.getSection().data(), "__DATA,__objc_classlist", 23)) {
                            isCls = true;
                        } else if (0 == strncmp(v.getSection().data(), "__DATA,__objc_catlist", 21)) {
                            isCat = true;
                        } else if (0 == strncmp(v.getSection().data(), "__DATA,__objc_nlclslist", 23)) {
                            isNoLazyCls = true;
                        } else if (0 == strncmp(v.getSection().data(), "__DATA,__objc_nlcatlist", 23)) {
                            isNoLazyCat = true;
                        }
                        if (isCls || isCat || isNoLazyCls || isNoLazyCat) {
                            v.setLinkage(GlobalValue::AppendingLinkage);
                            v.setDSOLocal(false);
                        } else if (0 == strncmp(v.getSection().data(), "__DATA,__objc_protolist", 23)) {
                            GlobalVariable *var = dyn_cast<GlobalVariable>(v.getInitializer());
                            NSString *name = [DDIRUtil getObjcProcotolName:var];
                            if (nil != [protocolDic objectForKey:name]) {
                                StringRef oldName = var->getName();
                                v.setName("");
                                var->setName("");
                                GlobalVariable *newVar = [DDIRUtil createGlobalVariableName:oldName.data()
                                                                         fromGlobalVariable:var
                                                                                       type:var->getInitializer()->getType()
                                                                                initializer:nullptr
                                                                                   inModule:ptr.get()];
                                newVar->setLinkage(GlobalValue::ExternalWeakLinkage);
                                [DDIRUtil replaceGlobalVariable:var with:newVar];
                                [removeArray addObject:[NSValue valueWithPointer:std::addressof(v)]];
                                [removeArray addObject:[NSValue valueWithPointer:var]];
                                [DDIRUtil removeValue:newVar
                                      fromGlobalArray:[DDIRUtil getLlvmCompilerUsedInModule:ptr.get()]
                                             inModule:ptr.get()];
                                [DDIRUtil removeValue:newVar
                                      fromGlobalArray:[DDIRUtil getLlvmUsedInModule:ptr.get()]
                                             inModule:ptr.get()];
                            } else {
                                [protocolDic setObject:@(YES) forKey:name];
                            }
                        }
                        if ((hasCls && isCls) || (hasCat && isCat) ||
                            (hasNoLazyCls && isNoLazyCls) || (hasNoLazyCat && isNoLazyCat)) {
                            [DDIRUtil removeValue:std::addressof(v)
                                  fromGlobalArray:[DDIRUtil getLlvmCompilerUsedInModule:ptr.get()]
                                         inModule:ptr.get()];
                        }
                        hasCls |= isCls;
                        hasCat |= isCat;
                        hasNoLazyCls |= isNoLazyCls;
                        hasNoLazyCat |= isNoLazyCat;
                    }
                }
                for (NSValue *val in removeArray) {
                    [DDIRUtil removeGlobalValue:(GlobalVariable *)val.pointerValue inModule:ptr.get()];
                }
                linker.linkInModule(std::move(ptr), Linker::Flags::None);
                ptr.release();
            }
        }
        Module::GlobalListType &globallist = basePtr->getGlobalList();
        for (GlobalVariable &v : globallist) {
            if (v.hasSection()) {
                if (0 == strncmp(v.getSection().data(), "__DATA,__objc_classlist", 23) ||
                    0 == strncmp(v.getSection().data(), "__DATA,__objc_catlist", 21) ||
                    0 == strncmp(v.getSection().data(), "__DATA,__objc_nlclslist", 23) ||
                    0 == strncmp(v.getSection().data(), "__DATA,__objc_nlcatlist", 23)) {
                    v.setLinkage(GlobalValue::PrivateLinkage);
                }
            }
        }
        // remove duplicates of llvm.linker.options
        NamedMDNode *optionNode = basePtr->getNamedMetadata("llvm.linker.options");
        if (nullptr != optionNode) {
            NSMutableDictionary *optionDic = [NSMutableDictionary dictionary];
            for (int i = 0; i < optionNode->getNumOperands(); ++i) {
                NSValue *val = [NSValue valueWithPointer:optionNode->getOperand(i)];
                if (nil == [optionDic objectForKey:val]) {
                    [optionDic setObject:val forKey:val];
                }
            }
            optionNode->clearOperands();
            for (NSValue *key in optionDic.allKeys) {
                optionNode->addOperand((MDNode *)[key pointerValue]);
            }
        }
        // remove duplicates of llvm.ident
        NamedMDNode *identNode = basePtr->getNamedMetadata("llvm.ident");
        if (nullptr != identNode) {
            NSMutableDictionary *identDic = [NSMutableDictionary dictionary];
            for (int i = 0; i < identNode->getNumOperands(); ++i) {
                NSValue *val = [NSValue valueWithPointer:identNode->getOperand(i)];
                if (nil == [identDic objectForKey:val]) {
                    [identDic setObject:val forKey:val];
                }
            }
            identNode->clearOperands();
            for (NSValue *key in identDic.allKeys) {
                identNode->addOperand((MDNode *)[key pointerValue]);
            }
        }
        
        StringRef output([outputPath cStringUsingEncoding:NSUTF8StringEncoding]);
        std::error_code ec;
        raw_fd_stream stream(output, ec);
        if ([[outputPath lowercaseString] hasSuffix:@".bc"]) {
            WriteBitcodeToFile(*basePtr, stream);
        } else if ([[outputPath lowercaseString] hasSuffix:@".ll"]) {
            basePtr->print(stream, nullptr);
        } else {
            assert("Unknown output file type");
        }
        stream.close();
        basePtr.release();
    }
}

- (nullable DDIRModuleData *)getData
{
    LLVMContext context;
    std::unique_ptr<Module> ptr = nullptr;
    if ([[self.path lowercaseString] hasSuffix:@".bc"]) {
        static ExitOnError exitOnErr;
        std::unique_ptr<MemoryBuffer> memoryBuffer = exitOnErr(errorOrToExpected(MemoryBuffer::getFileOrSTDIN([self.path cStringUsingEncoding:NSUTF8StringEncoding])));
        BitcodeFileContents fileContents = exitOnErr(llvm::getBitcodeFileContents(*memoryBuffer));
        assert(1 == fileContents.Mods.size());
        BitcodeModule bitcodeModule = fileContents.Mods[0];
        ptr = exitOnErr(bitcodeModule.parseModule(context));
        memoryBuffer.release();
    } else if ([[self.path lowercaseString] hasSuffix:@".ll"]) {
        SMDiagnostic err;
        ptr = parseAssemblyFile([self.path cStringUsingEncoding:NSUTF8StringEncoding], err, context);
    } else {
        assert("Unknown file type");
    }
    if (nullptr == ptr) {
        return nil;
    }
    
    DDIRModuleData *data = [[DDIRModuleData alloc] init];
    
    NSMutableDictionary *globalDic = [NSMutableDictionary dictionary];
    NSMutableDictionary *objcFuncDic = [NSMutableDictionary dictionary];
    NSMutableArray *stringList = [[NSMutableArray alloc] init];
    NSMutableArray *objcClassList = [[NSMutableArray alloc] init];
    NSMutableArray *objcCategoryList = [[NSMutableArray alloc] init];
    NSMutableArray *objcProcotolList = [[NSMutableArray alloc] init];
    Module::GlobalListType &globallist = ptr->getGlobalList();
    for (GlobalVariable &v : globallist) {
        if (0 == strncmp(v.getName().data(), ".str", 4) && nullptr != v.getValueType()) {
            if (v.getInitializer()->getType()->isArrayTy()) {
                ConstantDataArray *arr = dyn_cast<ConstantDataArray>(v.getInitializer());
                if (nullptr != arr && arr->getElementType()->isIntegerTy()) {
                    DDIRStringVariable *variable = [[DDIRStringVariable alloc] init];
                    variable.name = [NSString stringWithFormat:@"%s", v.getName().data()];
                    variable.value = [DDIRUtil stringFromGlobalVariable:std::addressof(v)];
                    [stringList addObject:variable];
                }
            }
        } else if (v.hasSection()) {
            if (0 == strncmp(v.getSection().data(), "__DATA,__objc_classlist", 23)) {
                ConstantArray *arr = dyn_cast<ConstantArray>(v.getInitializer());
                for (int i = 0; i < arr->getNumOperands(); ++i) {
                    DDIRObjCClass *objcClass = _objCClassFromVariable(dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0)), globalDic);
                    [objcClassList addObject:objcClass];
                    for (DDIRObjCMethod *method in objcClass.methodList) {
                        [objcFuncDic setObject:@(YES) forKey:method.functionName];
                    }
                    for (DDIRObjCMethod *method in objcClass.isaObjCClass.methodList) {
                        [objcFuncDic setObject:@(YES) forKey:method.functionName];
                    }
                }
            } else if (0 == strncmp(v.getSection().data(), "__DATA,__objc_catlist", 21)) {
                ConstantArray *arr = dyn_cast<ConstantArray>(v.getInitializer());
                for (int i = 0; i < arr->getNumOperands(); ++i) {
                    DDIRObjCCategory *objcCategory = _objCCategoryFromVariable(dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0)), globalDic);
                    [objcCategoryList addObject:objcCategory];
                    for (DDIRObjCMethod *method in objcCategory.instanceMethodList) {
                        [objcFuncDic setObject:@(YES) forKey:method.functionName];
                    }
                    for (DDIRObjCMethod *method in objcCategory.classMethodList) {
                        [objcFuncDic setObject:@(YES) forKey:method.functionName];
                    }
                }
            } else if (0 == strncmp(v.getSection().data(), "__DATA,__objc_protolist", 23)) {
                DDIRObjCProtocol *objcProtocol = _objcProtocolFromVariable(dyn_cast<GlobalVariable>(v.getInitializer()), globalDic);
                [objcProcotolList addObject:objcProtocol];
            }
        }
    }
    data.stringList = [NSArray arrayWithArray:stringList];
    data.objcClassList = [NSArray arrayWithArray:objcClassList];
    data.objcCategoryList = [NSArray arrayWithArray:objcCategoryList];
    data.objcProtocolList = [NSArray arrayWithArray:objcProcotolList];
    
    NSMutableArray *ctorFunctionList = [NSMutableArray array];
    GlobalVariable *ctorVal = ptr->getGlobalVariable("llvm.global_ctors");
    if (nullptr != ctorVal && ctorVal->hasInitializer()) {
        ConstantArray *arr = dyn_cast<ConstantArray>(ctorVal->getInitializer());
        for (int i = 0; i < arr->getNumOperands(); ++i) {
            Function *f = dyn_cast<Function>(arr->getOperand(i)->getOperand(1));
            DDIRFunction *function = [[DDIRFunction alloc] init];
            function.name = [NSString stringWithFormat:@"%s", f->getName().data()];
            [ctorFunctionList addObject:function];
        }
    }
    data.ctorFunctionList = [NSArray arrayWithArray:ctorFunctionList];
    
    NSMutableArray *functionNameList = [[NSMutableArray alloc] init];
    Module::FunctionListType &functionList = ptr->getFunctionList();
    for (Function &f : functionList) {
        NSString *funName = [NSString stringWithFormat:@"%s", f.getName().data()];
        if (nil == [objcFuncDic objectForKey:funName]) {
            DDIRFunction *function = [[DDIRFunction alloc] init];
            function.name = funName;
            [functionNameList addObject:function];
        }
    }
    data.functionList = [NSArray arrayWithArray:functionNameList];
    ptr.release();
    return data;
}

- (void)executeChangesWithBlock:(void (^_Nullable)(DDIRModule * _Nullable module))block
{
    [self executeChangesWithSavePath:self.path block:block];
}

- (void)executeChangesWithSavePath:(nonnull NSString *)savePath block:(void (^_Nullable)(DDIRModule * _Nullable module))block
{
    LLVMContext context;
    std::unique_ptr<Module> ptr = nullptr;
    if ([[self.path lowercaseString] hasSuffix:@".bc"]) {
        static ExitOnError exitOnErr;
        std::unique_ptr<MemoryBuffer> memoryBuffer = exitOnErr(errorOrToExpected(MemoryBuffer::getFileOrSTDIN([self.path cStringUsingEncoding:NSUTF8StringEncoding])));
        BitcodeFileContents fileContents = exitOnErr(llvm::getBitcodeFileContents(*memoryBuffer));
        assert(1 == fileContents.Mods.size());
        BitcodeModule bitcodeModule = fileContents.Mods[0];
        ptr = exitOnErr(bitcodeModule.parseModule(context));
        memoryBuffer.release();
    } else if ([[self.path lowercaseString] hasSuffix:@".ll"]) {
        SMDiagnostic err;
        ptr = parseAssemblyFile([self.path cStringUsingEncoding:NSUTF8StringEncoding], err, context);
    } else {
        assert("Unknown file type");
    }
    self.module = ptr.get();
    if (nil != block) {
        block(self);
    }
    self.module = nullptr;
    StringRef output([savePath cStringUsingEncoding:NSUTF8StringEncoding]);
    std::error_code ec;
    raw_fd_stream stream(output, ec);
    if ([[savePath lowercaseString] hasSuffix:@".bc"]) {
        WriteBitcodeToFile(*ptr, stream);
    } else if ([[savePath lowercaseString] hasSuffix:@".ll"]) {
        ptr->print(stream, nullptr);
    } else {
        assert("Unknown output file type");
    }
    stream.close();
    ptr.release();
}

- (BOOL)replaceFunction:(nonnull NSString *)funName withNewComponentName:(nonnull NSString *)newName
{
    Function *function = self.module->getFunction([funName cStringUsingEncoding:NSUTF8StringEncoding]);
    if (nullptr != function) {
        function->setName([newName cStringUsingEncoding:NSUTF8StringEncoding]);
        return true;
    }
    return false;
}

// class is a metaclass
#define RO_META               (1<<0)
// class compiled with ARC
#define RO_IS_ARC             (1<<7)
- (void)addEmptyClass:(nonnull NSString *)className
{
    GlobalVariable *cls = [DDIRUtil getObjcClass:className inModule:self.module];
    if (nullptr == cls) {
        NSDictionary *dic = [DDIRUtil getObjcClassTypeInModule:self.module];
        StructType *classType = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_ClassTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        assert(nullptr != classType);
        
        GlobalVariable *nsobject = self.module->getNamedGlobal("OBJC_CLASS_$_NSObject");
        if (nullptr == nsobject) {
            nsobject = new GlobalVariable(*self.module,
                                          classType,
                                          false,
                                          GlobalValue::ExternalLinkage,
                                          nullptr,
                                          "OBJC_CLASS_$_NSObject");
        }
        GlobalVariable *metaNSObject = self.module->getNamedGlobal("OBJC_METACLASS_$_NSObject");
        if (nullptr == metaNSObject) {
            metaNSObject = new GlobalVariable(*self.module,
                                               classType,
                                               false,
                                               GlobalValue::ExternalLinkage,
                                               nullptr,
                                               "OBJC_METACLASS_$_NSObject");
        }
        [DDIRUtil createObjcClass:[className cStringUsingEncoding:NSUTF8StringEncoding]
                        withSuper:nsobject
                        metaSuper:metaNSObject
                            flags:RO_IS_ARC
                       classFlags:(RO_META | RO_IS_ARC)
                    instanceStart:8   // NSObject size
                     instanceSize:8   // NSObject size
                       methodList:std::vector<llvm::Constant *>()
                  classMethodList:std::vector<llvm::Constant *>()
                         ivarList:std::vector<llvm::Constant *>()
                     protocolList:std::vector<llvm::Constant *>()
                         propList:std::vector<llvm::Constant *>()
                    classPropList:std::vector<llvm::Constant *>()
                         inModule:self.module];
    }
}

- (nullable DDIRReplaceResult *)replaceObjcClass:(nonnull NSString *)className withNewComponentName:(nonnull NSString *)newName
{
    GlobalVariable *classVariable = [DDIRUtil getObjcClass:className inModule:self.module];
    if (nullptr != classVariable && classVariable->hasInitializer()) {
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        NSString *oldName = [[NSString stringWithCString:classVariable->getName().data() encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"OBJC_CLASS_$_" withString:@""];
        void (^changeName)(NSString *, GlobalValue *, NSString *, NSString *) = ^(NSString *key, GlobalValue *var, NSString *oldName, NSString *newName) {
            NSMutableDictionary *dic = [result objectForKey:key];
            if (nil == dic) {
                dic = [NSMutableDictionary dictionary];
                [result setObject:dic forKey:key];
            }
            NSString *k = [NSString stringWithFormat:@"%s", var->getName().data()];
            [DDIRUtil changeGlobalValueName:var from:oldName to:newName];
            [dic setObject:[NSString stringWithFormat:@"%s", var->getName().data()] forKey:k];
        };
        void (^setNewClassName)(GlobalVariable *) = ^(GlobalVariable *variable) {
            assert(nullptr != variable);
            changeName(DDIRReplaceResultGlobalVariableKey, variable, oldName, newName);
            ConstantStruct *structPtr = dyn_cast<ConstantStruct>(variable->getInitializer());
            GlobalVariable *ro = dyn_cast<GlobalVariable>(structPtr->getOperand(4));
            changeName(DDIRReplaceResultGlobalVariableKey, ro, oldName, newName);
            // method
            if (isNullValue(ro, 5)) {
                GlobalVariable *methods = getValue(ro, 5);
                changeName(DDIRReplaceResultGlobalVariableKey, methods, oldName, newName);
                ConstantStruct *methodsPtr = dyn_cast<ConstantStruct>(methods->getInitializer());
                uint64_t count = (dyn_cast<ConstantInt>(methodsPtr->getOperand(1)))->getZExtValue();
                ConstantArray *list = dyn_cast<ConstantArray>(methodsPtr->getOperand(2));
                for (int i = 0; i < count; ++i) {
                    ConstantStruct *str = dyn_cast<ConstantStruct>(list->getOperand(i));
                    GlobalVariable *m = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(str->getOperand(0))->getOperand(0));
                    changeName(DDIRReplaceResultGlobalVariableKey, m, oldName, newName);
                    Function *f = dyn_cast<Function>(dyn_cast<ConstantExpr>(str->getOperand(2))->getOperand(0));
                    changeName(DDIRReplaceResultFunctionKey, f, oldName, newName);
                }
            }
            // protocol
            if (isNullValue(ro, 6)) {
                changeName(DDIRReplaceResultGlobalVariableKey, getValue(ro, 6), oldName, newName);
            }
            // ivar
            if (isNullValue(ro, 7)) {
                GlobalVariable *ivars = getValue(ro, 7);
                changeName(DDIRReplaceResultGlobalVariableKey, ivars, oldName, newName);
                ConstantStruct *ivarsPtr = dyn_cast<ConstantStruct>(ivars->getInitializer());
                uint64_t count = (dyn_cast<ConstantInt>(ivarsPtr->getOperand(1)))->getZExtValue();
                ConstantArray *list = dyn_cast<ConstantArray>(ivarsPtr->getOperand(2));
                for (int i = 0; i < count; ++i) {
                    ConstantStruct *str = dyn_cast<ConstantStruct>(list->getOperand(i));
                    GlobalVariable *v = dyn_cast<GlobalVariable>(str->getOperand(0));
                    changeName(DDIRReplaceResultGlobalVariableKey, v, oldName, newName);
                }
            }
            // prop
            if (isNullValue(ro, 9)) {
                changeName(DDIRReplaceResultGlobalVariableKey, getValue(ro, 9), oldName, newName);
            }
        };
        const char *oldVariablesName = classVariable->getName().data();
        setNewClassName(classVariable);
        ConstantStruct *classPtr = dyn_cast<ConstantStruct>(classVariable->getInitializer());
        setNewClassName(dyn_cast<GlobalVariable>(classPtr->getOperand(0)));
        // class name
//            GlobalVariable *ro = dyn_cast<GlobalVariable>((dyn_cast<ConstantStruct>(classVariable->getInitializer()))->getOperand(4));
//            [DDIRUtil changeStringValue:dyn_cast<ConstantStruct>(ro->getInitializer()) atOperand:4 to:newName inModule:self.module];
        // category
        GlobalVariable *newClassVariable = nullptr;
        Module::GlobalListType &globallist = self.module->getGlobalList();
        for (GlobalVariable &variable : globallist) {
            if (variable.hasSection()) {
                if (0 == strncmp(variable.getSection().data(), "__DATA,__objc_catlist", 21)) {
                    ConstantArray *arr = dyn_cast<ConstantArray>(variable.getInitializer());
                    for (int i = 0; i < arr->getNumOperands(); ++i) {
                        ConstantStruct *cat = dyn_cast<ConstantStruct>((dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0)))->getInitializer());
                        if (cat->getOperand(1) == classVariable) {
                            if (nullptr == newClassVariable) {
                                newClassVariable = new GlobalVariable(*self.module,
                                                                      [DDIRUtil getStructType:IR_Objc_ClassTypeName inModule:self.module],
                                                                      false,
                                                                      GlobalValue::ExternalLinkage,
                                                                      nullptr,
                                                                      oldVariablesName);
                            }
                            cat->handleOperandChange(classVariable, newClassVariable);
                        }
                    }
                }
            }
        }
        return result;
    }
    return nil;
}

- (BOOL)moveClass:(nonnull NSString *)className to:(nonnull NSString *)section
{
    GlobalVariable *classVariable = [DDIRUtil getObjcClass:className inModule:self.module];
    if (nullptr != classVariable && classVariable->hasInitializer()) {
        Module::GlobalListType &globallist = self.module->getGlobalList();
        GlobalVariable *clsSection = nullptr;
        GlobalVariable *targetSection = nullptr;
        for (GlobalVariable &v : globallist) {
            if (v.hasSection()) {
                if (0 == strncmp(v.getSection().data(), "__DATA,__objc_classlist", 23)) {
                    clsSection = std::addressof(v);
                } else if (0 == strncmp(v.getSection().data(), [section cStringUsingEncoding:NSUTF8StringEncoding], section.length)) {
                    targetSection = std::addressof(v);
                }
            }
        }
        if (nullptr != clsSection) {
            ConstantArray *arr = dyn_cast<ConstantArray>(clsSection->getInitializer());
            for (int i = 0; i < arr->getNumOperands(); ++i) {
                GlobalVariable *cls = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0));
                if (classVariable == cls) {
                    if (nullptr == targetSection) {
                        std::vector<Constant *> list;
                        Constant *val = ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(self.module->getContext()), 0), list);
                        targetSection = new GlobalVariable(*self.module,
                                                           val->getType(),
                                                           clsSection->isConstant(),
                                                           clsSection->getLinkage(),
                                                           val,
                                                           clsSection->getName(),
                                                           clsSection,
                                                           clsSection->getThreadLocalMode(),
                                                           clsSection->getAddressSpace(),
                                                           clsSection->isExternallyInitialized());
                        targetSection->setAlignment(clsSection->getAlign());
                        targetSection->setUnnamedAddr(clsSection->getUnnamedAddr());
                        targetSection->setSection([[[NSString stringWithFormat:@"%s", clsSection->getSection().data()] stringByReplacingOccurrencesOfString:@"__DATA,__objc_classlist" withString:section] cStringUsingEncoding:NSUTF8StringEncoding]);
                        if (clsSection->hasComdat()) {
                            targetSection->setComdat(clsSection->getComdat());
                        }
                        [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(targetSection), Type::getInt8PtrTy(self.module->getContext()))
                                toGlobalArray:[DDIRUtil getLlvmCompilerUsedInModule:self.module]
                                           at:0
                                     inModule:self.module];
                    }
                    [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(classVariable), Type::getInt8PtrTy(self.module->getContext()))
                            toGlobalArray:targetSection
                                       at:0
                                 inModule:self.module];
                    clsSection = [DDIRUtil removeValueAtIndex:i
                                              fromGlobalArray:clsSection
                                                     inModule:self.module];
                    if (0 == (dyn_cast<Constant>(clsSection->getInitializer())->getNumOperands())) {
                        GlobalVariable *use = [DDIRUtil getLlvmCompilerUsedInModule:self.module];
                        ConstantArray *list = dyn_cast<ConstantArray>(use->getInitializer());
                        for (int j = 0; j < list->getNumOperands(); ++j) {
                            if (list->getOperand(j)->getOperand(0) == clsSection) {
                                [DDIRUtil removeValueAtIndex:j
                                             fromGlobalArray:use
                                                    inModule:self.module];
                                clsSection->eraseFromParent();
                                break;
                            }
                        }
                    }
                    break;
                }
            }
        }
        return true;
    }
    return false;
}

- (void)addEmptyCategory:(nonnull NSString *)categoryName toClass:(nonnull NSString *)className
{
    NSString *globalName = [NSString stringWithFormat:@"_OBJC_$_CATEGORY_%@_$_%@", className, categoryName];
    GlobalVariable *cat = self.module->getNamedGlobal([globalName cStringUsingEncoding:NSUTF8StringEncoding]);
    if (nullptr == cat) {
        GlobalVariable *cls = [DDIRUtil getObjcClass:className inModule:self.module];
        if (nullptr == cls) {
            NSDictionary *dic = [DDIRUtil getObjcClassTypeInModule:self.module];
            StructType *classType = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Objc_ClassTypeName encoding:NSUTF8StringEncoding]] pointerValue];
            cls = new GlobalVariable(*self.module,
                                     classType,
                                     false,
                                     GlobalValue::ExternalLinkage,
                                     nullptr,
                                     [[NSString stringWithFormat:@"OBJC_CLASS_$_%@", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        [DDIRUtil createObjcCategory:[categoryName cStringUsingEncoding:NSUTF8StringEncoding]
                                 cls:cls
                      withMethodList:std::vector<Constant *>()
                     classMethodList:std::vector<Constant *>()
                        protocolList:std::vector<Constant *>()
                            propList:std::vector<Constant *>()
                       classPropList:std::vector<Constant *>()
                            inModule:self.module];
    }
}

- (nullable DDIRReplaceResult *)replaceCategory:(nonnull NSString *)categoryName forObjcClass:(nonnull NSString *)className withNewComponentName:(nonnull NSString *)newName
{
    GlobalVariable *cat = [DDIRUtil getCategory:categoryName forObjcClass:className inModule:self.module];
    if (nullptr != cat) {
        NSMutableDictionary *result = [NSMutableDictionary dictionary];
        void (^changeName)(NSString *, GlobalValue *, NSString *, NSString *) = ^(NSString *key, GlobalValue *var, NSString *oldName, NSString *newName) {
            NSMutableDictionary *dic = [result objectForKey:key];
            if (nil == dic) {
                dic = [NSMutableDictionary dictionary];
                [result setObject:dic forKey:key];
            }
            NSString *k = [NSString stringWithFormat:@"%s", var->getName().data()];
            NSString *n = [DDIRUtil changeGlobalValueName:var from:oldName to:newName];
            if (false == [n isEqualToString:k]) {
                [dic setObject:[NSString stringWithFormat:@"%s", var->getName().data()] forKey:k];
            }
        };
        NSString *oldName = [[[NSString stringWithCString:cat->getName().data() encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"_$_"] lastObject];
        changeName(DDIRReplaceResultGlobalVariableKey, cat, oldName, newName);
        [DDIRUtil changeStringValue:dyn_cast<ConstantStruct>(cat->getInitializer()) atOperand:0 to:newName inModule:self.module];
        // instanceMethods
        if (isNullValue(cat, 2)) {
            GlobalVariable *methods = getValue(cat, 2);
            changeName(DDIRReplaceResultGlobalVariableKey, methods, oldName, newName);
            ConstantStruct *methodsPtr = dyn_cast<ConstantStruct>(methods->getInitializer());
            uint64_t count = (dyn_cast<ConstantInt>(methodsPtr->getOperand(1)))->getZExtValue();
            ConstantArray *list = dyn_cast<ConstantArray>(methodsPtr->getOperand(2));
            for (int i = 0; i < count; ++i) {
                ConstantStruct *str = dyn_cast<ConstantStruct>(list->getOperand(i));
                GlobalVariable *m = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(str->getOperand(0))->getOperand(0));
                Function *f = dyn_cast<Function>(dyn_cast<ConstantExpr>(str->getOperand(2))->getOperand(0));
                NSString *n = [NSString stringWithFormat:@"%s", f->getName().data()];
                NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"\\(\\w+\\) " options:NSRegularExpressionCaseInsensitive error:NULL];
                n = [n substringWithRange:[r rangeOfFirstMatchInString:n options:0 range:NSMakeRange(0, n.length)]];
                n = [n substringWithRange:NSMakeRange(1, n.length - 3)];
                changeName(DDIRReplaceResultGlobalVariableKey, m, n, newName);
                changeName(DDIRReplaceResultFunctionKey, f, n, newName);
            }
        }
        // classMethods
        if (isNullValue(cat, 3)) {
            GlobalVariable *methods = getValue(cat, 3);
            changeName(DDIRReplaceResultGlobalVariableKey, methods, oldName, newName);
            ConstantStruct *methodsPtr = dyn_cast<ConstantStruct>(methods->getInitializer());
            uint64_t count = (dyn_cast<ConstantInt>(methodsPtr->getOperand(1)))->getZExtValue();
            ConstantArray *list = dyn_cast<ConstantArray>(methodsPtr->getOperand(2));
            for (int i = 0; i < count; ++i) {
                ConstantStruct *str = dyn_cast<ConstantStruct>(list->getOperand(i));
                GlobalVariable *m = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(str->getOperand(0))->getOperand(0));
                Function *f = dyn_cast<Function>(dyn_cast<ConstantExpr>(str->getOperand(2))->getOperand(0));
                NSString *n = [NSString stringWithFormat:@"%s", f->getName().data()];
                NSRegularExpression *r = [NSRegularExpression regularExpressionWithPattern:@"\\(\\w+\\) " options:NSRegularExpressionCaseInsensitive error:NULL];
                n = [n substringWithRange:[r rangeOfFirstMatchInString:n options:0 range:NSMakeRange(0, n.length)]];
                n = [n substringWithRange:NSMakeRange(1, n.length - 3)];
                changeName(DDIRReplaceResultGlobalVariableKey, m, n, newName);
                changeName(DDIRReplaceResultFunctionKey, f, n, newName);
            }
        }
        return result;
    }
    return nil;
}

- (BOOL)moveCategory:(nonnull NSString *)categoryName forObjcClass:(nonnull NSString *)className to:(nonnull NSString *)section
{
    GlobalVariable *categoryVariable = [DDIRUtil getCategory:categoryName forObjcClass:className inModule:self.module];
    if (nullptr != categoryVariable) {
        Module::GlobalListType &globallist = self.module->getGlobalList();
        GlobalVariable *catSection = nullptr;
        GlobalVariable *targetSection = nullptr;
        for (GlobalVariable &v : globallist) {
            if (v.hasSection()) {
                if (0 == strncmp(v.getSection().data(), "__DATA,__objc_catlist", 21)) {
                    catSection = std::addressof(v);
                } else if (0 == strncmp(v.getSection().data(), [section cStringUsingEncoding:NSUTF8StringEncoding], section.length)) {
                    targetSection = std::addressof(v);
                }
            }
        }
        if (nullptr != catSection) {
            ConstantArray *arr = dyn_cast<ConstantArray>(catSection->getInitializer());
            for (int i = 0; i < arr->getNumOperands(); ++i) {
                GlobalVariable *cat = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0));
                if (categoryVariable == cat) {
                    if (nullptr == targetSection) {
                        std::vector<Constant *> list;
                        Constant *val = ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(self.module->getContext()), 0), list);
                        targetSection = new GlobalVariable(*self.module,
                                                           val->getType(),
                                                           catSection->isConstant(),
                                                           catSection->getLinkage(),
                                                           val,
                                                           catSection->getName(),
                                                           catSection,
                                                           catSection->getThreadLocalMode(),
                                                           catSection->getAddressSpace(),
                                                           catSection->isExternallyInitialized());
                        targetSection->setAlignment(catSection->getAlign());
                        targetSection->setUnnamedAddr(catSection->getUnnamedAddr());
                        targetSection->setSection([[[NSString stringWithFormat:@"%s", catSection->getSection().data()] stringByReplacingOccurrencesOfString:@"__DATA,__objc_catlist" withString:section] cStringUsingEncoding:NSUTF8StringEncoding]);
                        if (catSection->hasComdat()) {
                            targetSection->setComdat(catSection->getComdat());
                        }
                        [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(targetSection), Type::getInt8PtrTy(self.module->getContext()))
                                toGlobalArray:[DDIRUtil getLlvmCompilerUsedInModule:self.module]
                                           at:0
                                     inModule:self.module];
                    }
                    [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(categoryVariable), Type::getInt8PtrTy(self.module->getContext()))
                            toGlobalArray:targetSection
                                       at:0
                                 inModule:self.module];
                    catSection = [DDIRUtil removeValueAtIndex:i
                                              fromGlobalArray:catSection
                                                     inModule:self.module];
                    if (0 == (dyn_cast<Constant>(catSection->getInitializer())->getNumOperands())) {
                        GlobalVariable *use = [DDIRUtil getLlvmCompilerUsedInModule:self.module];
                        ConstantArray *list = dyn_cast<ConstantArray>(use->getInitializer());
                        for (int j = 0; j < list->getNumOperands(); ++j) {
                            if (list->getOperand(j)->getOperand(0) == catSection) {
                                [DDIRUtil removeValueAtIndex:j
                                             fromGlobalArray:use
                                                    inModule:self.module];
                                catSection->eraseFromParent();
                                break;
                            }
                        }
                    }
                    break;
                }
            }
        }
        return true;
    }
    return false;
}

- (BOOL)replaceObjcProtocol:(nonnull NSString *)protocolName withNewComponentName:(nonnull NSString *)newName
{
    GlobalVariable *protocolLabel = nullptr;
    for (GlobalVariable &v : self.module->getGlobalList()) {
        if (v.hasSection()) {
            if (0 == strncmp(v.getSection().data(), "__DATA,__objc_protolist", 23)) {
                GlobalVariable *var = dyn_cast<GlobalVariable>(v.getInitializer());
                NSString *name = [DDIRUtil getObjcProcotolName:var];
                if ([protocolName isEqualToString:name]) {
                    protocolLabel = std::addressof(v);
                    break;
                }
            }
        }
    }
    if (nullptr != protocolLabel) {
        [DDIRUtil changeGlobalValueName:protocolLabel from:protocolName to:newName];
        GlobalVariable *protocol = dyn_cast<GlobalVariable>(protocolLabel->getInitializer());
        [DDIRUtil changeGlobalValueName:protocol from:protocolName to:newName];
        // name
        [DDIRUtil changeStringValue:dyn_cast<ConstantStruct>(protocol->getInitializer()) atOperand:1 to:newName inModule:self.module];
        // protocols
        if (isNullValue(protocol, 2)) {
            [DDIRUtil changeGlobalValueName:getValue(protocol, 2) from:protocolName to:newName];
        }
        // instanceMethods
        if (isNullValue(protocol, 3)) {
            [DDIRUtil changeGlobalValueName:getValue(protocol, 3) from:protocolName to:newName];
        }
        // classMethods
        if (isNullValue(protocol, 4)) {
            [DDIRUtil changeGlobalValueName:getValue(protocol, 4) from:protocolName to:newName];
        }
        // optionalInstanceMethods
        if (isNullValue(protocol, 5)) {
            [DDIRUtil changeGlobalValueName:getValue(protocol, 5) from:protocolName to:newName];
        }
        // optionalClassMethods
        if (isNullValue(protocol, 6)) {
            [DDIRUtil changeGlobalValueName:getValue(protocol, 6) from:protocolName to:newName];
        }
        // instanceProperties
        if (isNullValue(protocol, 7)) {
            [DDIRUtil changeGlobalValueName:getValue(protocol, 7) from:protocolName to:newName];
        }
        // _extendedMethodTypes
        if (isNullValue(protocol, 10)) {
            [DDIRUtil changeGlobalValueName:getValue(protocol, 10) from:protocolName to:newName];
        }
        // _classProperties
        if (isNullValue(protocol, 12)) {
            [DDIRUtil changeGlobalValueName:getValue(protocol, 12) from:protocolName to:newName];
        }
        return true;
    }
    return false;
}

static NSArray<DDIRObjCMethod *> *_objcMethodListFromStruct(ConstantStruct *methodPtr)
{
    uint64_t count = (dyn_cast<ConstantInt>(methodPtr->getOperand(1)))->getZExtValue();
    NSMutableArray *methodList = [[NSMutableArray alloc] initWithCapacity:count];
    ConstantArray *list = dyn_cast<ConstantArray>(methodPtr->getOperand(2));
    for (int i = 0; i < count; ++i) {
        DDIRObjCMethod *method = [[DDIRObjCMethod alloc] init];
        ConstantStruct *str = dyn_cast<ConstantStruct>(list->getOperand(i));
        method.methodName = [DDIRUtil stringFromGlobalVariable:dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(str->getOperand(0))->getOperand(0))];
        if (false == str->getOperand(2)->isNullValue()) {
            method.functionName = [NSString stringWithFormat:@"%s", dyn_cast<Function>(dyn_cast<ConstantExpr>(str->getOperand(2))->getOperand(0))->getName().data()];
        }
        [methodList addObject:method];
    }
    return [NSArray arrayWithArray:methodList];
}

static DDIRObjCProtocol *_objcProtocolFromVariable(GlobalVariable *variable, NSMutableDictionary *globalDic)
{
    NSString *name = [NSString stringWithFormat:@"%s", variable->getName().data()];
    DDIRObjCProtocol *protocol = [globalDic objectForKey:name];;
    if (nil == protocol) {
        protocol = [[DDIRObjCProtocol alloc] init];
        [globalDic setObject:protocol forKey:name];
        if (isNullValue(variable, 1)) {
            protocol.protocolName = [DDIRUtil stringFromGlobalVariable:getValue(variable, 1)];
        }
        if (isNullValue(variable, 2)) {
            ConstantStruct *list = dyn_cast<ConstantStruct>(getValue(variable, 2)->getInitializer());
            uint64_t count = dyn_cast<ConstantInt>(list->User::getOperand(0))->getZExtValue();
            ConstantArray *arr = dyn_cast<ConstantArray>(list->getOperand(1));
            if (count + 1 == arr->getNumOperands()) {
                NSMutableArray *protocolList = [[NSMutableArray alloc] initWithCapacity:count];
                for (int i = 0; i < count; ++i) {
                    GlobalVariable *ptr = dyn_cast<GlobalVariable>(arr->getOperand(i));
                    if (nullptr != ptr) {
                        DDIRObjCProtocol *p = _objcProtocolFromVariable(ptr, globalDic);
                        [protocolList addObject:p];
                    }
                }
                protocol.protocolList = protocolList;
            }
        }
        if (isNullValue(variable, 3)) {
            protocol.instanceMethodList = _objcMethodListFromStruct(dyn_cast<ConstantStruct>(getValue(variable, 3)->getInitializer()));
        }
        if (isNullValue(variable, 4)) {
            protocol.classMethodList = _objcMethodListFromStruct(dyn_cast<ConstantStruct>(getValue(variable, 4)->getInitializer()));
        }
        if (isNullValue(variable, 5)) {
            protocol.optionalInstanceMethodList = _objcMethodListFromStruct(dyn_cast<ConstantStruct>(getValue(variable, 5)->getInitializer()));
        }
        if (isNullValue(variable, 6)) {
            protocol.optionalClassMethodList = _objcMethodListFromStruct(dyn_cast<ConstantStruct>(getValue(variable, 6)->getInitializer()));
        }
    }
    return protocol;
}

static DDIRObjCClass *_objCClassFromVariable(GlobalVariable *variable, NSMutableDictionary *globalDic)
{
    NSString *name = [NSString stringWithFormat:@"%s", variable->getName().data()];
    DDIRObjCClass *objcClass = [globalDic objectForKey:name];;
    if (nil == objcClass) {
        objcClass = [[DDIRObjCClass alloc] init];
        [globalDic setObject:objcClass forKey:name];
        objcClass.name = name;
        objcClass.className = [[objcClass.name componentsSeparatedByString:@"_$_"] lastObject];
        if (!variable->hasInitializer()) {
            objcClass.type = DDIRObjCClassType_Declare;
        } else {
            ConstantStruct *structPtr = dyn_cast<ConstantStruct>(variable->getInitializer());
            assert(nullptr != structPtr && 5 == structPtr->getNumOperands());
            objcClass.type = DDIRObjCClassType_Define;
            objcClass.isaObjCClass = _objCClassFromVariable(dyn_cast<GlobalVariable>(structPtr->getOperand(0)), globalDic);
            objcClass.superObjCClass = _objCClassFromVariable(dyn_cast<GlobalVariable>(structPtr->getOperand(1)), globalDic);
            GlobalVariable *ro = dyn_cast<GlobalVariable>(structPtr->getOperand(4));
            // name
            if (isNullValue(ro, 4)) {
                objcClass.className = [DDIRUtil stringFromGlobalVariable:getValue(ro, 4)];
            }
            // method
            if (isNullValue(ro, 5)) {
                ConstantStruct *methodPtr = dyn_cast<ConstantStruct>(getValue(ro, 5)->getInitializer());
                objcClass.methodList = _objcMethodListFromStruct(methodPtr);
            }
            // protocol
            if (isNullValue(ro, 6)) {
                ConstantStruct *protocolsPtr = dyn_cast<ConstantStruct>(getValue(ro, 6)->getInitializer());
                uint64_t count = dyn_cast<ConstantInt>(protocolsPtr->User::getOperand(0))->getZExtValue();
                ConstantArray *arr = dyn_cast<ConstantArray>(protocolsPtr->getOperand(1));
                if (count + 1 == arr->getNumOperands()) {
                    NSMutableArray *protocolList = [[NSMutableArray alloc] initWithCapacity:count];
                    for (int i = 0; i < count; ++i) {
                        GlobalVariable *ptr = dyn_cast<GlobalVariable>(arr->getOperand(i));
                        if (nullptr != ptr) {
                            DDIRObjCProtocol *p = _objcProtocolFromVariable(ptr, globalDic);
                            [protocolList addObject:p];
                        }
                    }
                    objcClass.protocolList = protocolList;
                }
            }
            // ivar
            if (isNullValue(ro, 7)) {

            }
            // prop
            if (isNullValue(ro, 8)) {

            }
        }
    }
    return objcClass;
}

static DDIRObjCCategory *_objCCategoryFromVariable(GlobalVariable *variable, NSMutableDictionary *globalDic)
{
    NSString *name = [NSString stringWithFormat:@"%s", variable->getName().data()];
    DDIRObjCCategory *objcCategory = [globalDic objectForKey:name];
    if (nil == objcCategory) {
        objcCategory = [[DDIRObjCCategory alloc] init];
        [globalDic setObject:objcCategory forKey:name];
        objcCategory.name = name;
        if (isNullValue(variable, 0)) {
            objcCategory.categoryName = [DDIRUtil stringFromGlobalVariable:getValue(variable, 0)];
        }
        if (nullptr != variable->getInitializer()->getOperand(1)) {
            objcCategory.cls = _objCClassFromVariable(dyn_cast<GlobalVariable>(variable->getInitializer()->getOperand(1)), globalDic);
        }
        // instanceMethods
        if (isNullValue(variable, 2)) {
            ConstantStruct *methodPtr = dyn_cast<ConstantStruct>(getValue(variable, 2)->getInitializer());
            objcCategory.instanceMethodList = _objcMethodListFromStruct(methodPtr);
        }
        // classMethods
        if (isNullValue(variable, 3)) {
            ConstantStruct *methodPtr = dyn_cast<ConstantStruct>(getValue(variable, 3)->getInitializer());
            objcCategory.classMethodList = _objcMethodListFromStruct(methodPtr);
        }
    }
    return objcCategory;
}
@end

@implementation DDIRModuleData
@end
