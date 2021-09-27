//
//  DDIRModule.m
//  DDToolKit
//
//  Created by dondong on 2021/8/30.
//

#import "DDIRModule.h"
#import "DDIRUtil.h"
#include <llvm/AsmParser/Parser.h>
#include <llvm/IR/LLVMContext.h>
#include <llvm/IR/Module.h>
#include <llvm/Support/SourceMgr.h>
#include <llvm/IR/Constants.h>
#include <llvm/Support/ToolOutputFile.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Bitcode/BitcodeWriter.h>
#include <system_error>

#define checkValue(ptr, index) (NULL != dyn_cast<ConstantExpr>(ptr->getOperand(index)))
#define getGlobalVariable(ptr, index) (dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(ptr->getOperand(index)))->getOperand(0)))
#define getValue(ptr, index) ((dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(ptr->getOperand(index)))->getOperand(0)))->getInitializer())
using namespace llvm;

@interface DDIRModule()
@property(nonatomic,assign) Module *module;
@property(nonatomic,strong,readwrite,nonnull) NSString *path;
@end

@interface DDIRModuleData()
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRStringVariable *> *stringList;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRObjCClass *> *objcClassList;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRObjCCategory *> *objcCategoryList;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRFunction *> *functionList;
@end

@implementation DDIRModule
+ (nullable instancetype)moduleFromLLPath:(nonnull NSString *)path
{
    LLVMContext context;
    SMDiagnostic err;
    std::unique_ptr<Module> ptr = parseAssemblyFile([path cStringUsingEncoding:NSUTF8StringEncoding], err, context);
    if (NULL == ptr) {
        return nil;
    }
    ptr.release();
    
    DDIRModule *module = [[DDIRModule alloc] init];
    module.path = path;
    return module;
}

- (nullable DDIRModuleData *)getData
{
    LLVMContext context;
    SMDiagnostic err;
    std::unique_ptr<Module> ptr = parseAssemblyFile([self.path cStringUsingEncoding:NSUTF8StringEncoding], err, context);
    if (NULL == ptr) {
        return nil;
    }
    
    DDIRModuleData *data = [[DDIRModuleData alloc] init];
    
    NSMutableDictionary *globalDic = [NSMutableDictionary dictionary];
    NSMutableArray *stringList = [[NSMutableArray alloc] init];
    NSMutableArray *objcClassList = [[NSMutableArray alloc] init];
    NSMutableArray *objcCategoryList = [[NSMutableArray alloc] init];
    Module::GlobalListType &globallist = ptr->getGlobalList();
    for (GlobalVariable &v : globallist) {
        if (0 == strncmp(v.getName().data(), ".str", 4) && NULL != v.getValueType()) {
            if (v.getInitializer()->getType()->isArrayTy()) {
                ConstantDataArray *arr = dyn_cast<ConstantDataArray>(v.getInitializer());
                if (NULL != arr && arr->getElementType()->isIntegerTy()) {
                    DDIRStringVariable *variable = [[DDIRStringVariable alloc] init];
                    variable.name = [NSString stringWithFormat:@"%s", v.getName().data()];
                    variable.value = [DDIRUtil stringFromArray:arr];
                    [stringList addObject:variable];
                }
            }
        } else if (v.hasSection()) {
            if (0 == strncmp(v.getSection().data(), "__DATA,__objc_classlist", 23)) {
                ConstantArray *arr = dyn_cast<ConstantArray>(v.getInitializer());
                for (int i = 0; i < arr->getNumOperands(); ++i) {
                    DDIRObjCClass *objcClass = _objCClassFromVariable(dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0)), globalDic);
                    [objcClassList addObject:objcClass];
                }
            } else if (0 == strncmp(v.getSection().data(), "__DATA,__objc_catlist", 21)) {
                ConstantArray *arr = dyn_cast<ConstantArray>(v.getInitializer());
                for (int i = 0; i < arr->getNumOperands(); ++i) {
                    DDIRObjCCategory *objcCategory = _objCCategoryFromVariable(dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0)), globalDic);
                    [objcCategoryList addObject:objcCategory];
                }
            }
        }
    }
    data.stringList = [NSArray arrayWithArray:stringList];
    data.objcClassList = [NSArray arrayWithArray:objcClassList];
    data.objcCategoryList = [NSArray arrayWithArray:objcCategoryList];
    
    NSMutableArray *functionNameList = [[NSMutableArray alloc] init];
    Module::FunctionListType &functionList = ptr->getFunctionList();
    for (Function &f : functionList) {
        DDIRFunction *function = [[DDIRFunction alloc] init];
        function.name = [NSString stringWithFormat:@"%s", f.getName().data()];
        if (f.getBasicBlockList().size() > 0) {
            function.type = DDIRFunctionType_Define;
        } else {
            function.type = DDIRFunctionType_Declare;
        }
        [functionNameList addObject:function];
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
    SMDiagnostic err;
    std::unique_ptr<Module> ptr = parseAssemblyFile([self.path cStringUsingEncoding:NSUTF8StringEncoding], err, context);
    self.module = ptr.get();
    if (nil != block) {
        block(self);
    }
    self.module = NULL;
    NSString *outputPath = [savePath stringByReplacingOccurrencesOfString:@".ll" withString:@".bc"];
    StringRef output([outputPath cStringUsingEncoding:NSUTF8StringEncoding]);
    std::error_code ec;
    raw_fd_stream stream(output, ec);
    WriteBitcodeToFile(*ptr, stream);
    stream.close();
    ptr.release();
    
    system([[NSString stringWithFormat:@"/usr/local/bin/llvm-dis %@ %@", outputPath, savePath] cStringUsingEncoding:NSUTF8StringEncoding]);
    [[NSFileManager defaultManager] removeItemAtPath:outputPath error:NULL];
}

- (void)addEmptyClass:(nonnull NSString *)className
{
    GlobalVariable *cls = [DDIRUtil getObjcClass:className inModule:self.module];
    if (NULL == cls) {
        NSDictionary *dic = [DDIRUtil getObjcClassTypeInModule:self.module];
        StructType *classType        = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Ojbc_ClassTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        StructType *roType           = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Ojbc_RoTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        StructType *methodListType   = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Ojbc_MethodListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        StructType *protocolListType = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Ojbc_ProtocolListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        StructType *ivarListType     = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Ojbc_IvarListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        StructType *propListType     = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Ojbc_PropListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        assert(NULL != classType && NULL != roType && NULL != methodListType && NULL != protocolListType && NULL != ivarListType && NULL != propListType);
        
        Constant *zero = ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 0);
        // NSObject
        Constant *nameVal = ConstantDataArray::getString(self.module->getContext(), StringRef([className cStringUsingEncoding:NSUTF8StringEncoding]), true);
        GlobalVariable *name = new GlobalVariable(*self.module,
                                                  nameVal->getType(),
                                                  true,
                                                  GlobalValue::PrivateLinkage,
                                                  nameVal,
                                                  "OBJC_CLASS_NAME_");
        name->setAlignment(MaybeAlign(1));
        name->setUnnamedAddr(GlobalValue::UnnamedAddr::Global);
        name->setSection("__TEXT,__objc_classname,cstring_literals");
        [DDIRUtil insertValue:ConstantExpr::getInBoundsGetElementPtr(name->getInitializer()->getType(), name, (Constant *[]){zero, zero})
              toConstantArray:[DDIRUtil getLlvmCompilerUsedInModule:self.module]
                           at:0
                     inModule:self.module];
        
        GlobalVariable *nsobject = self.module->getNamedGlobal("OBJC_CLASS_$_NSObject");
        if (NULL == nsobject) {
            nsobject = new GlobalVariable(*self.module,
                                          classType,
                                          false,
                                          GlobalValue::ExternalLinkage,
                                          NULL,
                                          "OBJC_CLASS_$_NSObject");
        }
        GlobalVariable *metalNSObject = self.module->getNamedGlobal("OBJC_METACLASS_$_NSObject");
        if (NULL == metalNSObject) {
            metalNSObject = new GlobalVariable(*self.module,
                                               classType,
                                               false,
                                               GlobalValue::ExternalLinkage,
                                               NULL,
                                               "OBJC_METACLASS_$_NSObject");
        }
        GlobalVariable *cache = self.module->getNamedGlobal("_objc_empty_cache");
        if (NULL == cache) {
            cache = new GlobalVariable(*self.module,
                                       [DDIRUtil getStructType:IR_Ojbc_CacheTypeName inModule:self.module],
                                       false,
                                       GlobalValue::ExternalLinkage,
                                       NULL,
                                       "_objc_empty_cache");
        }
        
        // metal class
        std::vector<Constant *> metalRoList;
        metalRoList.push_back(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 129));
        metalRoList.push_back(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 40));
        metalRoList.push_back(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 40));
        metalRoList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(self.module->getContext())));
        metalRoList.push_back(ConstantExpr::getInBoundsGetElementPtr(name->getInitializer()->getType(), name, (Constant *[]){zero, zero}));
        metalRoList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
        metalRoList.push_back(ConstantPointerNull::get(PointerType::getUnqual(protocolListType)));
        metalRoList.push_back(ConstantPointerNull::get(PointerType::getUnqual(ivarListType)));
        metalRoList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(self.module->getContext())));
        metalRoList.push_back(ConstantPointerNull::get(PointerType::getUnqual(propListType)));
        GlobalVariable *metalRo = new GlobalVariable(*self.module,
                                                     roType,
                                                     false,
                                                     GlobalValue::InternalLinkage,
                                                     ConstantStruct::get(roType, metalRoList),
                                                     [[NSString stringWithFormat:@"_OBJC_METACLASS_RO_$_%@", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        metalRo->setSection("__DATA, __objc_const");
        metalRo->setAlignment(MaybeAlign(8));
        
        std::vector<Constant *> metalClsList;
        metalClsList.push_back(metalNSObject);  // isa
        metalClsList.push_back(metalNSObject);  // super
        metalClsList.push_back(cache);
        metalClsList.push_back(ConstantPointerNull::get(PointerType::getUnqual(PointerType::getUnqual(FunctionType::get(Type::getInt8PtrTy(self.module->getContext()),
                                                                                                                        {Type::getInt8PtrTy(self.module->getContext()), Type::getInt8PtrTy(self.module->getContext())},
                                                                                                                        false)))));
        metalClsList.push_back(metalRo);
        GlobalVariable *metalCls =  new GlobalVariable(*self.module,
                                                       classType,
                                                       false,
                                                       GlobalValue::ExternalLinkage,
                                                       ConstantStruct::get(classType, metalClsList),
                                                       [[NSString stringWithFormat:@"OBJC_METACLASS_$_%@", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        metalCls->setSection("__DATA, __objc_data");
        metalCls->setAlignment(MaybeAlign(8));
        
        // class
        std::vector<Constant *> roList;
        roList.push_back(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 128));
        roList.push_back(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 8));
        roList.push_back(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 8));
        roList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(self.module->getContext())));
        roList.push_back(ConstantExpr::getInBoundsGetElementPtr(name->getInitializer()->getType(), name, (Constant *[]){zero, zero}));
        roList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
        roList.push_back(ConstantPointerNull::get(PointerType::getUnqual(protocolListType)));
        roList.push_back(ConstantPointerNull::get(PointerType::getUnqual(ivarListType)));
        roList.push_back(ConstantPointerNull::get(Type::getInt8PtrTy(self.module->getContext())));
        roList.push_back(ConstantPointerNull::get(PointerType::getUnqual(propListType)));
        GlobalVariable *ro = new GlobalVariable(*self.module,
                                                roType,
                                                false,
                                                GlobalValue::InternalLinkage,
                                                ConstantStruct::get(roType, roList),
                                                [[NSString stringWithFormat:@"_OBJC_CLASS_RO_$_%@", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        ro->setSection("__DATA, __objc_const");
        ro->setAlignment(MaybeAlign(8));
        
        std::vector<Constant *> clsList;
        clsList.push_back(metalCls);  // isa
        clsList.push_back(nsobject);  // super
        clsList.push_back(cache);
        clsList.push_back(ConstantPointerNull::get(PointerType::getUnqual(PointerType::getUnqual(FunctionType::get(Type::getInt8PtrTy(self.module->getContext()),
                                                                                                                        {Type::getInt8PtrTy(self.module->getContext()), Type::getInt8PtrTy(self.module->getContext())},
                                                                                                                        false)))));
        clsList.push_back(ro);
        cls = new GlobalVariable(*self.module,
                                 classType,
                                 false,
                                 GlobalValue::ExternalLinkage,
                                 ConstantStruct::get(classType, clsList),
                                 [[NSString stringWithFormat:@"OBJC_CLASS_$_%@", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        cls->setSection("__DATA, __objc_data");
        cls->setAlignment(MaybeAlign(8));
        [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(cls), Type::getInt8PtrTy(self.module->getContext()))
              toConstantArray:[DDIRUtil getLlvmCompilerUsedInModule:self.module]
                           at:0
                     inModule:self.module];
        GlobalVariable *label = NULL;
        for (GlobalVariable &v : self.module->getGlobalList()) {
            if (v.GlobalValue::hasSection()) {
                if (0 == strncmp(v.getSection().data(), "__DATA,__objc_classlist", 23)) {
                    label = &v;
                    break;
                }
            }
        }
        if (NULL == label) {
            std::vector<Constant *> list;
            Constant *val = ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(self.module->getContext()), 0), list);
            label = new GlobalVariable(*self.module,
                                       val->getType(),
                                       false,
                                       GlobalValue::PrivateLinkage,
                                       val,
                                       "OBJC_LABEL_CLASS_$");
            label->setSection("__DATA,__objc_classlist,regular,no_dead_strip");
            label->setAlignment(MaybeAlign(8));
            [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(label), Type::getInt8PtrTy(self.module->getContext()))
                  toConstantArray:[DDIRUtil getLlvmCompilerUsedInModule:self.module]
                               at:0
                         inModule:self.module];
        }
        [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(cls), Type::getInt8PtrTy(self.module->getContext()))
              toConstantArray:label
                           at:0
                     inModule:self.module];
    }
}

- (void)addEmptyCategory:(nonnull NSString *)categoryName toClass:(nonnull NSString *)className
{
    NSString *globalName = [NSString stringWithFormat:@"_OBJC_$_CATEGORY_%@_$_%@", className, categoryName];
    GlobalVariable *cat = self.module->getNamedGlobal([globalName cStringUsingEncoding:NSUTF8StringEncoding]);
    if (NULL == cat) {
        NSDictionary *dic = [DDIRUtil getObjcCategoryTypeInModule:self.module];
        StructType *categoryType     = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Ojbc_CategoryTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        StructType *classType        = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Ojbc_ClassTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        StructType *methodListType   = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Ojbc_MethodListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        StructType *protocolListType = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Ojbc_ProtocolListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        StructType *propListType     = (StructType *)[[dic objectForKey:[NSString stringWithCString:IR_Ojbc_PropListTypeName encoding:NSUTF8StringEncoding]] pointerValue];
        
        Constant *zero = ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 0);
        Constant *nameVal = ConstantDataArray::getString(self.module->getContext(), StringRef([categoryName cStringUsingEncoding:NSUTF8StringEncoding]), true);
        GlobalVariable *name = new GlobalVariable(*self.module,
                                                  nameVal->getType(),
                                                  true,
                                                  GlobalValue::PrivateLinkage,
                                                  nameVal,
                                                  "OBJC_CLASS_NAME_");
        name->setAlignment(MaybeAlign(1));
        name->setUnnamedAddr(GlobalValue::UnnamedAddr::Global);
        name->setSection("__TEXT,__objc_classname,cstring_literals");
        [DDIRUtil insertValue:ConstantExpr::getInBoundsGetElementPtr(name->getInitializer()->getType(), name, (Constant *[]){zero, zero})
              toConstantArray:[DDIRUtil getLlvmCompilerUsedInModule:self.module]
                           at:0
                     inModule:self.module];
        
        GlobalVariable *cls = [DDIRUtil getObjcClass:className inModule:self.module];
        if (NULL == cls) {
            cls = new GlobalVariable(*self.module,
                                     classType,
                                     false,
                                     GlobalValue::ExternalLinkage,
                                     NULL,
                                     [[NSString stringWithFormat:@"OBJC_CLASS_$_%@", className] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        
        std::vector<Constant *> catList;
        catList.push_back(ConstantExpr::getInBoundsGetElementPtr(name->getInitializer()->getType(), name, (Constant *[]){zero, zero}));
        catList.push_back(cls);
        catList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
        catList.push_back(ConstantPointerNull::get(PointerType::getUnqual(methodListType)));
        catList.push_back(ConstantPointerNull::get(PointerType::getUnqual(protocolListType)));
        catList.push_back(ConstantPointerNull::get(PointerType::getUnqual(propListType)));
        catList.push_back(ConstantPointerNull::get(PointerType::getUnqual(propListType)));
        catList.push_back(ConstantInt::get(Type::getInt32Ty(self.module->getContext()), 64));
        cat = new GlobalVariable(*self.module,
                                 categoryType,
                                 false,
                                 GlobalValue::InternalLinkage,
                                 ConstantStruct::get(categoryType, catList),
                                 [[NSString stringWithFormat:@"_OBJC_$_CATEGORY_%@_$_%@", className, categoryName] cStringUsingEncoding:NSUTF8StringEncoding]);
        cat->setSection("__DATA, __objc_const");
        cat->setAlignment(MaybeAlign(8));
        [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(cat), Type::getInt8PtrTy(self.module->getContext()))
              toConstantArray:[DDIRUtil getLlvmCompilerUsedInModule:self.module]
                           at:0
                     inModule:self.module];
        GlobalVariable *label = NULL;
        for (GlobalVariable &v : self.module->getGlobalList()) {
            if (v.GlobalValue::hasSection()) {
                if (0 == strncmp(v.getSection().data(), "__DATA,__objc_catlist", 21)) {
                    label = &v;
                    break;
                }
            }
        }
        if (NULL == label) {
            std::vector<Constant *> list;
            Constant *val = ConstantArray::get(ArrayType::get(Type::getInt8PtrTy(self.module->getContext()), 0), list);
            label = new GlobalVariable(*self.module,
                                       val->getType(),
                                       false,
                                       GlobalValue::PrivateLinkage,
                                       val,
                                       "OBJC_LABEL_CATEGORY_$");
            label->setSection("__DATA,__objc_catlist,regular,no_dead_strip");
            label->setAlignment(MaybeAlign(8));
            [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(label), Type::getInt8PtrTy(self.module->getContext()))
                  toConstantArray:[DDIRUtil getLlvmCompilerUsedInModule:self.module]
                               at:0
                         inModule:self.module];
        }
        [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(cat), Type::getInt8PtrTy(self.module->getContext()))
              toConstantArray:label
                           at:0
                     inModule:self.module];
    }
    
}

- (BOOL)replaceObjcClass:(nonnull NSString *)className withNewComponentName:(nonnull NSString *)newName
{
    GlobalVariable *classVariable = [DDIRUtil getObjcClass:className inModule:self.module];
    if (NULL != classVariable && classVariable->hasInitializer()) {
        NSString *oldName = [[NSString stringWithCString:classVariable->getName().data() encoding:NSUTF8StringEncoding] stringByReplacingOccurrencesOfString:@"OBJC_CLASS_$_" withString:@""];
        void (^setNewClassName)(GlobalVariable *) = ^(GlobalVariable *variable) {
            assert(NULL != variable);
            [DDIRUtil changeGlobalValueName:variable from:oldName to:newName];
            ConstantStruct *structPtr = dyn_cast<ConstantStruct>(variable->getInitializer());
            GlobalVariable *ro = dyn_cast<GlobalVariable>(structPtr->getOperand(4));
            [DDIRUtil changeGlobalValueName:ro from:oldName to:newName];
            ConstantStruct *roPtr = dyn_cast<ConstantStruct>(dyn_cast<GlobalVariable>(structPtr->getOperand(4))->getInitializer());
            assert(NULL != roPtr && 10 == roPtr->getNumOperands());
            // method
            if (checkValue(roPtr, 5)) {
                GlobalVariable *methods = getGlobalVariable(roPtr, 5);
                [DDIRUtil changeGlobalValueName:methods from:oldName to:newName];
                ConstantStruct *methodsPtr = dyn_cast<ConstantStruct>(methods->getInitializer());
                uint64_t count = (dyn_cast<ConstantInt>(methodsPtr->getOperand(1)))->getZExtValue();
                ConstantArray *list = dyn_cast<ConstantArray>(methodsPtr->getOperand(2));
                for (int i = 0; i < count; ++i) {
                    ConstantStruct *str = dyn_cast<ConstantStruct>(list->getOperand(i));
                    GlobalVariable *m = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(str->getOperand(0))->getOperand(0));
                    [DDIRUtil changeGlobalValueName:m from:oldName to:newName];
                    Function *f = dyn_cast<Function>(dyn_cast<ConstantExpr>(str->getOperand(2))->getOperand(0));
                    [DDIRUtil changeGlobalValueName:f from:oldName to:newName];
                }
            }
            // protocol
            if (checkValue(roPtr, 6)) {
                [DDIRUtil changeGlobalValueName:getGlobalVariable(roPtr, 6) from:oldName to:newName];
            }
            // ivar
            if (checkValue(roPtr, 7)) {
                GlobalVariable *ivars = getGlobalVariable(roPtr, 7);
                [DDIRUtil changeGlobalValueName:ivars from:oldName to:newName];
                ConstantStruct *ivarsPtr = dyn_cast<ConstantStruct>(ivars->getInitializer());
                uint64_t count = (dyn_cast<ConstantInt>(ivarsPtr->getOperand(1)))->getZExtValue();
                ConstantArray *list = dyn_cast<ConstantArray>(ivarsPtr->getOperand(2));
                for (int i = 0; i < count; ++i) {
                    ConstantStruct *str = dyn_cast<ConstantStruct>(list->getOperand(i));
                    GlobalVariable *v = dyn_cast<GlobalVariable>(str->getOperand(0));
                    [DDIRUtil changeGlobalValueName:v from:oldName to:newName];
                }
            }
            // prop
            if (checkValue(roPtr, 9)) {
                [DDIRUtil changeGlobalValueName:(getGlobalVariable(roPtr, 9)) from:oldName to:newName];
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
        GlobalVariable *newClassVariable = NULL;
        Module::GlobalListType &globallist = self.module->getGlobalList();
        for (GlobalVariable &variable : globallist) {
            if (variable.hasSection()) {
                if (0 == strncmp(variable.getSection().data(), "__DATA,__objc_catlist", 21)) {
                    ConstantArray *arr = dyn_cast<ConstantArray>(variable.getInitializer());
                    for (int i = 0; i < arr->getNumOperands(); ++i) {
                        ConstantStruct *cat = dyn_cast<ConstantStruct>((dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0)))->getInitializer());
                        if (cat->getOperand(1) == classVariable) {
                            if (NULL == newClassVariable) {
                                newClassVariable = new GlobalVariable(*self.module,
                                                                      [DDIRUtil getStructType:IR_Ojbc_ClassTypeName inModule:self.module],
                                                                      false,
                                                                      GlobalValue::ExternalLinkage,
                                                                      NULL,
                                                                      oldVariablesName);
                            }
                            cat->handleOperandChange(classVariable, newClassVariable);
                        }
                    }
                }
            }
        }
        return true;
    }
    return false;
}

- (BOOL)moveClass:(nonnull NSString *)className to:(nonnull NSString *)section
{
    GlobalVariable *classVariable = [DDIRUtil getObjcClass:className inModule:self.module];
    if (NULL != classVariable && classVariable->hasInitializer()) {
        Module::GlobalListType &globallist = self.module->getGlobalList();
        GlobalVariable *clsSection = NULL;
        GlobalVariable *targetSection = NULL;
        for (GlobalVariable &v : globallist) {
            if (v.hasSection()) {
                if (0 == strncmp(v.getSection().data(), "__DATA,__objc_classlist", 23)) {
                    clsSection = &v;
                } else if (0 == strncmp(v.getSection().data(), [section cStringUsingEncoding:NSUTF8StringEncoding], section.length)) {
                    targetSection = &v;
                }
            }
        }
        if (NULL != clsSection) {
            ConstantArray *arr = dyn_cast<ConstantArray>(clsSection->getInitializer());
            for (int i = 0; i < arr->getNumOperands(); ++i) {
                GlobalVariable *cls = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0));
                if (classVariable == cls) {
                    if (NULL == targetSection) {
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
                              toConstantArray:[DDIRUtil getLlvmCompilerUsedInModule:self.module]
                                           at:0
                                     inModule:self.module];
                    }
                    [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(classVariable), Type::getInt8PtrTy(self.module->getContext()))
                          toConstantArray:targetSection
                                       at:0
                                 inModule:self.module];
                    clsSection = [DDIRUtil removeValueFromConstantArray:clsSection
                                                                     at:i
                                                               inModule:self.module];
                    if (0 == (dyn_cast<Constant>(clsSection->getInitializer())->getNumOperands())) {
                        GlobalVariable *use = [DDIRUtil getLlvmCompilerUsedInModule:self.module];
                        ConstantArray *list = dyn_cast<ConstantArray>(use->getInitializer());
                        for (int j = 0; j < list->getNumOperands(); ++j) {
                            if (list->getOperand(j)->getOperand(0) == clsSection) {
                                [DDIRUtil removeValueFromConstantArray:use
                                                                    at:j
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

- (BOOL)replaceCategory:(nonnull NSString *)categoryName forObjcClass:(nonnull NSString *)className withNewComponentName:(nonnull NSString *)newName
{
    GlobalVariable *categoryVariable = [DDIRUtil getCategory:categoryName forObjcClass:className inModule:self.module];
    if (NULL != categoryVariable) {
        ConstantStruct *category = dyn_cast<ConstantStruct>(categoryVariable->getInitializer());
        NSString *oldName = [[[NSString stringWithCString:categoryVariable->getName().data() encoding:NSUTF8StringEncoding] componentsSeparatedByString:@"_$_"] lastObject];
        [DDIRUtil changeGlobalValueName:categoryVariable from:oldName to:newName];
        // instanceMethods
        if (checkValue(category, 2)) {
            GlobalVariable *methods = getGlobalVariable(category, 2);
            [DDIRUtil changeGlobalValueName:methods from:oldName to:newName];
            ConstantStruct *methodsPtr = dyn_cast<ConstantStruct>(methods->getInitializer());
            uint64_t count = (dyn_cast<ConstantInt>(methodsPtr->getOperand(1)))->getZExtValue();
            ConstantArray *list = dyn_cast<ConstantArray>(methodsPtr->getOperand(2));
            for (int i = 0; i < count; ++i) {
                ConstantStruct *str = dyn_cast<ConstantStruct>(list->getOperand(i));
                GlobalVariable *m = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(str->getOperand(0))->getOperand(0));
                [DDIRUtil changeGlobalValueName:m from:oldName to:newName];
                Function *f = dyn_cast<Function>(dyn_cast<ConstantExpr>(str->getOperand(2))->getOperand(0));
                [DDIRUtil changeGlobalValueName:f from:oldName to:newName];
            }
        }
        // classMethods
        if (checkValue(category, 3)) {
            GlobalVariable *methods = getGlobalVariable(category, 3);
            [DDIRUtil changeGlobalValueName:methods from:oldName to:newName];
            ConstantStruct *methodsPtr = dyn_cast<ConstantStruct>(methods->getInitializer());
            uint64_t count = (dyn_cast<ConstantInt>(methodsPtr->getOperand(1)))->getZExtValue();
            ConstantArray *list = dyn_cast<ConstantArray>(methodsPtr->getOperand(2));
            for (int i = 0; i < count; ++i) {
                ConstantStruct *str = dyn_cast<ConstantStruct>(list->getOperand(i));
                GlobalVariable *m = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(str->getOperand(0))->getOperand(0));
                [DDIRUtil changeGlobalValueName:m from:oldName to:newName];
                Function *f = dyn_cast<Function>(dyn_cast<ConstantExpr>(str->getOperand(2))->getOperand(0));
                [DDIRUtil changeGlobalValueName:f from:oldName to:newName];
            }
        }
        return true;
    }
    return false;
}

- (BOOL)moveCategory:(nonnull NSString *)categoryName forObjcClass:(nonnull NSString *)className to:(nonnull NSString *)section
{
    GlobalVariable *categoryVariable = [DDIRUtil getCategory:categoryName forObjcClass:className inModule:self.module];
    if (NULL != categoryVariable) {
        Module::GlobalListType &globallist = self.module->getGlobalList();
        GlobalVariable *catSection = NULL;
        GlobalVariable *targetSection = NULL;
        for (GlobalVariable &v : globallist) {
            if (v.hasSection()) {
                if (0 == strncmp(v.getSection().data(), "__DATA,__objc_catlist", 21)) {
                    catSection = &v;
                } else if (0 == strncmp(v.getSection().data(), [section cStringUsingEncoding:NSUTF8StringEncoding], section.length)) {
                    targetSection = &v;
                }
            }
        }
        if (NULL != catSection) {
            ConstantArray *arr = dyn_cast<ConstantArray>(catSection->getInitializer());
            for (int i = 0; i < arr->getNumOperands(); ++i) {
                GlobalVariable *cat = dyn_cast<GlobalVariable>(dyn_cast<ConstantExpr>(arr->getOperand(i))->getOperand(0));
                if (categoryVariable == cat) {
                    if (NULL == targetSection) {
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
                              toConstantArray:[DDIRUtil getLlvmCompilerUsedInModule:self.module]
                                           at:0
                                     inModule:self.module];
                    }
                    [DDIRUtil insertValue:ConstantExpr::getBitCast(cast<Constant>(categoryVariable), Type::getInt8PtrTy(self.module->getContext()))
                          toConstantArray:targetSection
                                       at:0
                                 inModule:self.module];
                    catSection = [DDIRUtil removeValueFromConstantArray:catSection
                                                                     at:i
                                                               inModule:self.module];
                    if (0 == (dyn_cast<Constant>(catSection->getInitializer())->getNumOperands())) {
                        GlobalVariable *use = [DDIRUtil getLlvmCompilerUsedInModule:self.module];
                        ConstantArray *list = dyn_cast<ConstantArray>(use->getInitializer());
                        for (int j = 0; j < list->getNumOperands(); ++j) {
                            if (list->getOperand(j)->getOperand(0) == catSection) {
                                [DDIRUtil removeValueFromConstantArray:use
                                                                    at:j
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

static NSArray<DDIRObjCMethod *> *_objcMethodListFromStruct(ConstantStruct *methodPtr)
{
    uint64_t count = (dyn_cast<ConstantInt>(methodPtr->getOperand(1)))->getZExtValue();
    NSMutableArray *methodList = [[NSMutableArray alloc] initWithCapacity:count];
    ConstantArray *list = dyn_cast<ConstantArray>(methodPtr->getOperand(2));
    for (int i = 0; i < count; ++i) {
        DDIRObjCMethod *method = [[DDIRObjCMethod alloc] init];
        ConstantStruct *m = dyn_cast<ConstantStruct>(list->getOperand(i));
        ConstantDataArray *n = dyn_cast<ConstantDataArray>((dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(m->getOperand(0)))->getOperand(0)))->getInitializer());
        method.methodName = [DDIRUtil stringFromArray:n];
        [methodList addObject:method];
    }
    return [NSArray arrayWithArray:methodList];
}

static DDIRObjCProtocol *_objcProtocolFromStruct(ConstantStruct *protocolPtr, NSMutableDictionary *globalDic)
{
    NSString *name = [NSString stringWithFormat:@"%s", protocolPtr->getName().data()];
    DDIRObjCProtocol *protocol = [globalDic objectForKey:name];;
    if (nil == protocol) {
        protocol = [[DDIRObjCProtocol alloc] init];
        [globalDic setObject:protocol forKey:name];
        if (NULL != protocolPtr->getOperand(1)) {
            ConstantDataArray *name = dyn_cast<ConstantDataArray>((dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(protocolPtr->getOperand(1)))->getOperand(0)))->getInitializer());
            protocol.protocolName = [DDIRUtil stringFromArray:name];
        }
        if (NULL != protocolPtr->getOperand(3)) {
            ConstantStruct *instanceMethods = dyn_cast<ConstantStruct>((dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(protocolPtr->getOperand(3)))->getOperand(0)))->getInitializer());
            protocol.instanceMethodList = _objcMethodListFromStruct(instanceMethods);
        }
        if (NULL != protocolPtr->getOperand(4)) {
            ConstantStruct *classMethods = dyn_cast<ConstantStruct>((dyn_cast<GlobalVariable>((dyn_cast<ConstantExpr>(protocolPtr->getOperand(4)))->getOperand(0)))->getInitializer());
            protocol.classMethodList = _objcMethodListFromStruct(classMethods);
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
            assert(NULL != structPtr && 5 == structPtr->getNumOperands());
            objcClass.type = DDIRObjCClassType_Define;
            objcClass.isa = _objCClassFromVariable(dyn_cast<GlobalVariable>(structPtr->getOperand(0)), globalDic);
            objcClass.superObjCClass = _objCClassFromVariable(dyn_cast<GlobalVariable>(structPtr->getOperand(1)), globalDic);
            ConstantStruct *roPtr = dyn_cast<ConstantStruct>(dyn_cast<GlobalVariable>(structPtr->getOperand(4))->getInitializer());
            // name
            if (checkValue(roPtr, 4)) {
                objcClass.className = [DDIRUtil stringFromArray:dyn_cast<ConstantDataArray>(getValue(roPtr, 4))];
            }
            // method
            if (checkValue(roPtr, 5)) {
                ConstantStruct *methodPtr = dyn_cast<ConstantStruct>(getValue(roPtr, 5));
                objcClass.methodList = _objcMethodListFromStruct(methodPtr);
            }
            // protocol
            if (checkValue(roPtr, 6)) {
                ConstantStruct *protocolsPtr = dyn_cast<ConstantStruct>(getValue(roPtr, 6));
                ConstantArray *arr = dyn_cast<ConstantArray>(protocolsPtr->getOperand(1));
                if (2 == arr->getNumOperands()) {
                    uint64_t count = arr->getNumOperands();
                    NSMutableArray *protocolList = [[NSMutableArray alloc] initWithCapacity:count];
                    for (int i = 0; i < count; ++i) {
                        GlobalVariable *ptr = dyn_cast<GlobalVariable>(arr->getOperand(i));
                        if (NULL != ptr) {
                            DDIRObjCProtocol *p = _objcProtocolFromStruct(dyn_cast<ConstantStruct>(ptr->getInitializer()), globalDic);
                            [protocolList addObject:p];
                        }
                    }
                    objcClass.protocolList = protocolList;
                }
            }
            // ivar
            if (NULL != roPtr->getOperand(7)) {

            }
            // prop
            if (NULL != roPtr->getOperand(8)) {

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
        ConstantStruct *structPtr = dyn_cast<ConstantStruct>(variable->getInitializer());
        assert(NULL != structPtr && 8 == structPtr->getNumOperands());
        if (checkValue(structPtr, 0)) {
            objcCategory.categoryName = [DDIRUtil stringFromArray:dyn_cast<ConstantDataArray>(getValue(structPtr, 0))];
        }
        if (NULL != structPtr->getOperand(1)) {
            objcCategory.isa = _objCClassFromVariable(dyn_cast<GlobalVariable>(structPtr->getOperand(1)), globalDic);
        }
        // instanceMethods
        if (checkValue(structPtr, 2)) {
            ConstantStruct *methodPtr = dyn_cast<ConstantStruct>getValue(structPtr, 2);
            objcCategory.instanceMethodList = _objcMethodListFromStruct(methodPtr);
        }
        // classMethods
        if (checkValue(structPtr, 3)) {
            ConstantStruct *methodPtr = dyn_cast<ConstantStruct>getValue(structPtr, 3);
            objcCategory.classMethodList = _objcMethodListFromStruct(methodPtr);
        }
    }
    return objcCategory;
}

@end

@implementation DDIRModuleData
@end
