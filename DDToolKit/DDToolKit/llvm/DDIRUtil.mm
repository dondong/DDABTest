//
//  DDIRUtil.m
//  DDToolKit
//
//  Created by dondong on 2021/9/15.
//

#import "DDIRUtil.h"
#include "DDIRUtil.hpp"
#include <llvm/IR/Module.h>
#include <llvm/IR/ValueHandle.h>

using namespace llvm;

std::string changeGlobalValueName(llvm::GlobalValue * _Nonnull variable, const char * _Nonnull oldNameStr, const char * _Nonnull newNameStr)
{
    assert(nullptr != variable);
    NSString *oldName = [NSString stringWithUTF8String:oldNameStr];
    NSString *newName = [NSString stringWithUTF8String:newNameStr];
    NSString *n = nil;
    NSString *o = [NSString stringWithCString:variable->getName().data() encoding:NSUTF8StringEncoding];
    if ([o hasSuffix:[@"_" stringByAppendingString:oldName]]) {   // xx_oldName
        n = [o stringByReplacingOccurrencesOfString:oldName withString:newName options:0 range:NSMakeRange(o.length - oldName.length, oldName.length)];
    } else if ([o containsString:[NSString stringWithFormat:@"$_%@.", oldName]]) {   // xx$_oldName.xx
        n = [o stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"$_%@.", oldName] withString:[NSString stringWithFormat:@"$_%@.", newName]];
    } else if ([o containsString:[NSString stringWithFormat:@"[%@ ", oldName]]) {   // xx[oldName xx
        n = [o stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"[%@ ", oldName] withString:[NSString stringWithFormat:@"[%@ ", newName]];
    } else if ([o containsString:[NSString stringWithFormat:@"[%@(", oldName]]) {   // xx[oldName xx
        n = [o stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"[%@(", oldName] withString:[NSString stringWithFormat:@"[%@(", newName]];
    } else if ([o containsString:[NSString stringWithFormat:@"(%@) ", oldName]]) {   // xx(oldName) xx
        n = [o stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"(%@) ", oldName] withString:[NSString stringWithFormat:@"(%@) ", newName]];
    }
    if (nil != n) {
        variable->setName(Twine([n cStringUsingEncoding:NSUTF8StringEncoding]));
        return std::string([n cStringUsingEncoding:NSUTF8StringEncoding]);
    } else {
        return std::string([o cStringUsingEncoding:NSUTF8StringEncoding]);
    }
}
