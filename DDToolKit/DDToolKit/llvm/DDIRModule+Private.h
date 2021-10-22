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
@property(nonatomic,assign,readwrite) llvm::Module *module;
@property(nonatomic,strong,readwrite,nonnull) NSString *path;
@end

#endif /* DDIRModule_Private_h */
