//
//  DDIRUtil.h
//  DDToolKit
//
//  Created by dondong on 2021/9/15.
//

#import <Foundation/Foundation.h>
#include <llvm/IR/Module.h>
#include <llvm/IR/Constants.h>

NS_ASSUME_NONNULL_BEGIN


std::string changeGlobalValueName(llvm::GlobalValue * _Nonnull variable, const char * _Nonnull oldNameStr, const char * _Nonnull newNameStr);

NS_ASSUME_NONNULL_END
