//
//  DDStaticLibrary.h
//  DDToolKit
//
//  Created by dondong on 2021/9/9.
//

#import <Foundation/Foundation.h>
#import "DDIRModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface DDStaticLibrary : NSObject
@property(nonatomic,strong,readonly,nonnull) NSString *path;
@property(nonatomic,strong,readonly,nonnull) NSArray<NSString *> *architectures;
@property(nonatomic,strong,readonly,nonnull) DDIRModule *module;
+ (nullable instancetype)libraryFromPath:(nonnull NSString *)path tempDir:(nonnull NSString *)tempDir;
- (void)clear;
@end

NS_ASSUME_NONNULL_END
