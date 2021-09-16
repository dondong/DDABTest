//
//  DDLibrary.h
//  DDToolKit
//
//  Created by dondong on 2021/9/9.
//

#import <Foundation/Foundation.h>
#import "DDIRModule.h"

NS_ASSUME_NONNULL_BEGIN

@interface DDLibrary : NSObject
@property(nonatomic,strong,readonly,nonnull) NSString *path;
@property(nonatomic,strong,readonly,nonnull) NSArray<NSString *> *architectures;
@property(nonatomic,strong,readonly,nonnull) NSArray<NSString *> *ofilePathes;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRModule *> *moduleList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRObjCClass *> *classList;
@property(nonatomic,strong,readonly,nonnull) NSArray<DDIRObjCCategory *> *categoryList;
+ (nullable instancetype)libraryFromPath:(nonnull NSString *)path tempDir:(nonnull NSString *)tempDir;
- (void)clear;
@end

NS_ASSUME_NONNULL_END
