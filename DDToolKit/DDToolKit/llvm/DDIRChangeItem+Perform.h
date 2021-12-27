//
//  DDIRChangeItem+Perform.h
//  DDToolKit
//
//  Created by dondong on 2021/12/24.
//

#import "DDIRChangeItem.h"
#include <llvm/IR/Module.h>
#include <llvm/IR/Constants.h>

NS_ASSUME_NONNULL_BEGIN

@interface DDIRChangeItem(Perform)
- (void)performChange:(llvm::Module * _Nonnull)module;
@end

NS_ASSUME_NONNULL_END
