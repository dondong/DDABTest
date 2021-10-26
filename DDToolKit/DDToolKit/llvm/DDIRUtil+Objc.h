//
//  DDIRUtil+Objc.h
//  DDToolKit
//
//  Created by dondong on 2021/10/18.
//

#import "DDIRUtil.h"
#include <llvm/IR/Module.h>
#include <llvm/IR/Constants.h>

NS_ASSUME_NONNULL_BEGIN
extern const char *IR_Objc_ClassTypeName;
extern const char *IR_Objc_CacheTypeName;
extern const char *IR_Objc_RoTypeName;
extern const char *IR_Objc_MethodListTypeName;
extern const char *IR_Objc_MethodTypeName;
extern const char *IR_Objc_ProtocolListTypeName;
extern const char *IR_Objc_ProtocolTypeName;
extern const char *IR_Objc_IvarListTypeName;
extern const char *IR_Objc_IvarTypeName;
extern const char *IR_Objc_PropListTypeName;
extern const char *IR_Objc_PropTypeName;
extern const char *IR_Objc_CategoryTypeName;

@interface DDIRUtil(Objc)
// create
+ (llvm::GlobalVariable * _Nonnull)createObjcClass:(const char * _Nonnull)className
                                         withSuper:(llvm::GlobalVariable * _Nonnull)superCls
                                         metaSuper:(llvm::GlobalVariable * _Nonnull)metaSuperCls
                                             flags:(uint32_t)flags
                                     instanceStart:(uint32_t)instanceStart
                                      instanceSize:(uint32_t)instanceSize
                                        methodList:(std::vector<llvm::Constant *>)methods
                                   classMethodList:(std::vector<llvm::Constant *>)classMethods
                                          ivarList:(std::vector<llvm::Constant *>)ivars
                                      protocolList:(std::vector<llvm::Constant *>)protocols
                                          propList:(std::vector<llvm::Constant *>)props
                                     classPropList:(std::vector<llvm::Constant *>)classProps
                                          inModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable * _Nonnull)createObjcCategory:(const char * _Nonnull)categoryName
                                                  cls:(llvm::GlobalVariable * _Nonnull)cls
                                       withMethodList:(std::vector<llvm::Constant *>)methods
                                      classMethodList:(std::vector<llvm::Constant *>)classMethods
                                         protocolList:(std::vector<llvm::Constant *>)protocols
                                             propList:(std::vector<llvm::Constant *>)props
                                        classPropList:(std::vector<llvm::Constant *>)classProps
                                             inModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable * _Nonnull)createObjcProtocol:(const char * _Nonnull)protocolName
                                            withFlags:(uint32_t)flags
                                         protocolList:(std::vector<llvm::Constant *>)protocols
                                           methodList:(std::vector<llvm::Constant *>)methods
                                      classMethodList:(std::vector<llvm::Constant *>)classMethods
                                   optionalMethodList:(std::vector<llvm::Constant *>)optionalMethods
                              optionalClassMethodList:(std::vector<llvm::Constant *>)optionalClassMethods
                                             propList:(std::vector<llvm::Constant *>)props
                                        classPropList:(std::vector<llvm::Constant *>)classProps
                                             inModule:(llvm::Module * _Nonnull)module;
// get
+ (nullable NSString *)getObjcClassName:(llvm::GlobalVariable * _Nonnull)cls;
+ (nullable NSString *)getObjcCategoryName:(llvm::GlobalVariable * _Nonnull)cat;
+ (nullable NSString *)getObjcClassNameFromCategory:(llvm::GlobalVariable * _Nonnull)cat;
+ (nullable NSString *)getObjcProcotolName:(llvm::GlobalVariable * _Nonnull)pro;
+ (nonnull NSDictionary<NSString *, NSValue *> *)getObjcClassTypeInModule:(llvm::Module * _Nonnull)module;
+ (nonnull NSDictionary<NSString *, NSValue *> *)getObjcCategoryTypeInModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable * _Nullable)getObjcClass:(nonnull NSString *)className
                                        inModule:(llvm::Module * _Nonnull)module;
+ (llvm:: GlobalVariable * _Nullable)getCategory:(nonnull NSString *)categoryName
                                    forObjcClass:(nonnull NSString *)className
                                        inModule:(llvm::Module * _Nonnull)module;
+ (llvm::GlobalVariable * _Nullable)getObjcProtocolLabel:(nonnull NSString *)protocolName
                                                inModule:(llvm::Module * _Nonnull)module;
@end

NS_ASSUME_NONNULL_END
