//
//  DDIRModule+Private.h
//  DDToolKit
//
//  Created by dondong on 2021/10/21.
//

#ifndef DDIRModule_Private_h
#define DDIRModule_Private_h

#import "DDIRModule.h"
#include <llvm/IR/Module.h>

@interface DDIRModule()
@property(nonatomic,assign,readwrite) llvm::Module * _Nullable module;
@property(nonatomic,strong,readwrite,nonnull) NSString *path;
@property(nonatomic,strong,readwrite,nullable) DDIRModulePath *modulePath;
@end

#endif /* DDIRModule_Private_h */
