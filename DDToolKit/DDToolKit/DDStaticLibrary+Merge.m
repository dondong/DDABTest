//
//  DDStaticLibrary+Merge.m
//  DDToolKit
//
//  Created by dondong on 2021/12/1.
//

#import "DDStaticLibrary+Merge.h"
#import "DDStaticLibrary+Private.h"
#import "DDIRModule+Merge.h"
#import "DDToolKitDefine.h"
#import <objc/runtime.h>

@interface DDStaticLibrary(Merge_Private)
@property(nonatomic,strong) NSString *headerPath;
@property(nonatomic,strong) NSMutableArray<NSString *> *mergePathList;
@end

@implementation DDStaticLibrary(Merge)
+ (nullable DDStaticLibrary *)mergeLibraries:(nonnull NSArray<DDStaticLibrary *> *)libraries
                               withControlId:(UInt32)controlId
                                 toLibraries:(nonnull NSString *)outputLibrary
                                   directory:(nonnull NSString *)tmpDirectory
{
    if ([[NSFileManager defaultManager] fileExistsAtPath:tmpDirectory]) {
        [[NSFileManager defaultManager] removeItemAtPath:tmpDirectory error:NULL];
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDirectory withIntermediateDirectories:true attributes:nil error:NULL];
    NSMutableArray *pathList = [NSMutableArray array];
    NSMutableArray *headerPathList = [NSMutableArray array];
    for (int i = 0; i < libraries.count; ++i) {
        DDStaticLibrary *lib = [libraries objectAtIndex:i];
        // use bitcode file to build o file, will cash some unkown crash
        lib.headerPath = [tmpDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%d.ll", [[lib.path lastPathComponent] stringByDeletingPathExtension], i]];
        NSMutableArray *mergePathList = [NSMutableArray array];
        for (NSString *path in lib.pathList) {
            NSString *newPath =  [tmpDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@_%d.%@", [[path lastPathComponent] stringByDeletingPathExtension], i, [path pathExtension]]];
            [[NSFileManager defaultManager] copyItemAtPath:path toPath:newPath error:NULL];
            [mergePathList addObject:newPath];
        }
        [DDIRModule linkIRFiles:mergePathList toIRFile:lib.headerPath];
        DDIRModulePath *path = [[DDIRModulePath alloc] init];
        path.path = lib.headerPath;
        DDIRModule *headerModule = [DDIRModule moduleFromPath:lib.headerPath];
        [headerModule executeChangesWithBlock:^(DDIRModule * _Nullable module) {
            path.declareChangedRecord = [module extractObjcDataAndFunctionDeclaration];;
        }];
        for (NSString *p in mergePathList) {
            DDIRModule *module  = [DDIRModule moduleFromPath:p];
#if EnableDebug
            [module executeChangesWithBlock:^(DDIRModule * _Nullable m) {
#else
            [module executeChangesWithSavePath:[p stringByReplacingCharactersInRange:NSMakeRange(p.length - 3, 3) withString:@".ll"] block:^(DDIRModule * _Nullable m) {
#endif
                [m remeveObjcData];
            }];
        }
        [headerPathList addObject:path];
#if EnableDebug
        lib.mergePathList = mergePathList;
#else
        lib.mergePathList = [NSMutableArray array];
        for (NSString *p in mergePathList) {
            // use bitcode file to build o file, will cash some unkown crash
            [lib.mergePathList addObject:[p stringByReplacingCharactersInRange:NSMakeRange(p.length - 3, 3) withString:@".ll"]];
            [[NSFileManager defaultManager] removeItemAtPath:p error:NULL];
        }
#endif
        [pathList addObjectsFromArray:lib.mergePathList];
    }
    // use bitcode file to build o file, will cash some unkown crash
    NSString *headerPath = [tmpDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.ll", [[outputLibrary lastPathComponent] stringByDeletingPathExtension]]];
    [pathList addObject:headerPath];
    NSDictionary *changeRecords = [DDIRModule mergeIRModules:headerPathList withControlId:controlId toIRFile:headerPath];
    NSMutableDictionary *libDic = [NSMutableDictionary dictionary];
    for (DDStaticLibrary *lib in libraries) {
        [libDic setObject:lib forKey:lib.headerPath];
#if CleanTempFiles
        [[NSFileManager defaultManager] removeItemAtPath:lib.headerPath error:NULL];
        lib.headerPath = nil;
#endif
    }
    for (NSString *key in changeRecords.allKeys) {
        NSDictionary *record = [changeRecords objectForKey:key];
        DDStaticLibrary *lib = [libDic objectForKey:key];
        for (NSString *p in lib.mergePathList) {
            DDIRModule *module  = [DDIRModule moduleFromPath:p];
            [module executeChangesWithBlock:^(DDIRModule * _Nullable m) {
                [m synchronzieReplaceResult:record];
            }];
        }
        lib.mergePathList = nil;
    }
    NSMutableSet *architectures = [NSMutableSet set];
    for (DDStaticLibrary *lib in libraries) {
        [architectures addObjectsFromArray:lib.architectures];
    }
    DDStaticLibrary *ret = [[DDStaticLibrary alloc] init];
    ret.path = outputLibrary;
    ret.tmpPath = tmpDirectory;
    ret.pathList = pathList;
    ret.architectures = architectures.allObjects;
    
    NSMutableString *archPath = [NSMutableString string];
    NSMutableArray *archList = [NSMutableArray array];
    for (NSString *arch in ret.architectures) {
        NSString *tmpDir = [ret.tmpPath stringByAppendingPathComponent:[NSString stringWithFormat:@"tmp_%u", arc4random()]];
        [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:NULL];
        [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:NULL];
        NSString *target = [self _targetForArch:arch];
        for (NSString *p in ret.pathList) {
            NSString *name = [p lastPathComponent];
            system([[NSString stringWithFormat:@"xcrun clang -O1 -isysroot /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk -target %@ -fembed-bitcode -c %@ -o %@", target, p, [tmpDir stringByAppendingPathComponent:[[name stringByDeletingPathExtension] stringByAppendingString:@".o"]]] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        if (architectures.count > 1) {
            NSString *name = [[ret.path lastPathComponent] stringByDeletingPathExtension];
            NSString *output = [NSString stringWithFormat:@"%@_%@.a", [ret.tmpPath stringByAppendingPathComponent:name], arch];
            [archList addObject:output];
            system([[NSString stringWithFormat:@"ar -rcs %@ %@/*.o", output, tmpDir] cStringUsingEncoding:NSUTF8StringEncoding]);
        } else {
            system([[NSString stringWithFormat:@"ar -rcs %@ %@/*.o", ret.path, tmpDir] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:NULL];
    }
    if (archPath.length > 0) {
        system([[NSString stringWithFormat:@"lipo -create %@ -output %@", archPath, ret.path] cStringUsingEncoding:NSUTF8StringEncoding]);
        for (NSString *p in archList) {
            [[NSFileManager defaultManager] removeItemAtPath:p error:NULL];
        }
    }
    
    return ret;
}


+ (nonnull NSString *)_targetForArch:(nonnull NSString *)arch
{
    NSDictionary *dic = @{@"armv7":  @"armv7-apple-ios10.0.0",
                          @"arm64":  @"arm64-apple-ios10.0.0",
                          @"i386":   @"i386-apple-macosx10.14",
                          @"x86_64": @"x86_64-apple-macosx10.14"};
    return [dic objectForKey:arch];
}
@end

@implementation DDStaticLibrary(Merge_Private)
static const char *headerPathKey = "headerPath";
- (void)setHeaderPath:(NSString *)headerPath
{
    objc_setAssociatedObject(self, headerPathKey, headerPath, OBJC_ASSOCIATION_RETAIN);
}
- (NSString *)headerPath
{
    return objc_getAssociatedObject(self, headerPathKey);
}
static const char *mergePathListKey = "mergePathList";
- (void)setMergePathList:(NSMutableArray<NSString *> *)mergePathList
{
    objc_setAssociatedObject(self, mergePathListKey, mergePathList, OBJC_ASSOCIATION_RETAIN);
}
- (NSMutableArray<NSString *> *)mergePathList
{
    return objc_getAssociatedObject(self, mergePathListKey);
}
@end
