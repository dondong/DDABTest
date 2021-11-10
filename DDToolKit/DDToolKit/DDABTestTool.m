//
//  DDABTestTool.m
//  DDToolKit
//
//  Created by dondong on 2021/9/10.
//

#import "DDABTestTool.h"
#import "DDCommonDefine.h"
#import "DDStaticLibrary.h"
#import "DDIRModule+Merge.h"
#import <objc/runtime.h>

@interface DDStaticLibraryInfo()
@property(nonatomic,strong) DDStaticLibrary *lib;
@property(nonatomic,assign) UInt32 index;
@end

@interface DDStaticLibrary(DDABTestTool)
@property(nonatomic,strong) DDIRModuleData *data;
@end


@implementation DDABTestTool

+ (void)mergeStaticLibrariesWithInfo:(nonnull DDABTestInfo *)info
{
    DDStaticLibraryInfo *defaultInfo = nil;
    for (DDStaticLibraryInfo *i in info.inputLibraries) {
        if (i.isDefault || nil == defaultInfo) {
            defaultInfo = i;
        }
        i.lib = [DDStaticLibrary libraryFromPath:i.path tempDir:info.tempDirectory];
        [i.lib.module executeChangesWithBlock:^(DDIRModule * _Nullable module) {
            [module mergeObjcData];
        }];
        i.lib.data = [i.lib.module getData];
    }
    assert(NULL != defaultInfo);
    NSMutableArray *llfilePathes = [NSMutableArray array];
    UInt32 index = 0;
    [llfilePathes addObject:defaultInfo.lib.module.path];
    defaultInfo.index = index;
    index++;
    for (DDStaticLibraryInfo *i in info.inputLibraries) {
        if (i != defaultInfo) {
            [llfilePathes addObject:i.lib.module.path];
            i.index = index;
            index++;
        }
    }
    NSString *llfile = [info.tempDirectory stringByAppendingPathComponent:[info.moduleName stringByAppendingPathExtension:@"ll"]];
    [DDIRModule mergeLLFiles:llfilePathes withControlId:info.moduleId toLLFile:llfile];
    
    NSString *archDir = [[info.outputPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"tmp_%lu", random()]];
    [[NSFileManager defaultManager] removeItemAtPath:archDir error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:archDir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSMutableString *archPath = [NSMutableString string];
    NSMutableSet *architectures = [NSMutableSet set];
    for (DDStaticLibraryInfo *i in info.inputLibraries) {
        [architectures addObjectsFromArray:i.lib.architectures];
    }
    for (NSString *arch in architectures) {
        NSString *tmpDir = [[info.outputPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:[NSString stringWithFormat:@"tmp_%lu", random()]];
        [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:NULL];
        [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:NULL];
        NSString *target = [self _targetForArch:arch];
        NSString *name = [llfile lastPathComponent];
        system([[NSString stringWithFormat:@"xcrun clang -O1 -target %@ -fembed-bitcode -c %@ -o %@", target, llfile, [tmpDir stringByAppendingPathComponent:[[name stringByDeletingPathExtension] stringByAppendingString:@".o"]]] cStringUsingEncoding:NSUTF8StringEncoding]);
        if (architectures.count > 1) {
            NSString *name = [[info.outputPath lastPathComponent] stringByDeletingPathExtension];
            NSString *output = [NSString stringWithFormat:@"%@_%@.a", [archDir stringByAppendingPathComponent:name], arch];
            system([[NSString stringWithFormat:@"ar -rcs %@ %@/*.o", output, tmpDir] cStringUsingEncoding:NSUTF8StringEncoding]);
            [archPath appendFormat:@" %@ ", output];
        } else {
            system([[NSString stringWithFormat:@"ar -rcs %@ %@/*.o", info.outputPath, tmpDir] cStringUsingEncoding:NSUTF8StringEncoding]);
        }
        [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:NULL];
    }
    if (archPath.length > 0) {
        system([[NSString stringWithFormat:@"lipo -create %@ -output %@", archPath, info.outputPath] cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    [[NSFileManager defaultManager] removeItemAtPath:archDir error:NULL];
//    for (DDStaticLibraryInfo *i in info.inputLibraries) {
//        [i.lib clear];
//    }
    
    NSMutableDictionary *outputConfig = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:info.configPath]) {
        outputConfig = [NSMutableDictionary dictionaryWithContentsOfFile:info.configPath];
    } else {
        outputConfig = [NSMutableDictionary dictionary];
    }
    NSMutableArray *outputArr = [NSMutableArray array];
    for (DDStaticLibraryInfo *i in info.inputLibraries) {
        [outputArr addObject:@{DDConfigTagKey: i.tag, DDConfigIndexKey: @(i.index)}];
    }
    [outputConfig setObject:@{DDConfigModuleNameKey: info.moduleName,
                              DDConfigModuleIdKey: @(info.moduleId),
                              DDConfigComponentsKey: outputArr}
                     forKey:info.moduleName];
    [outputConfig writeToFile:info.configPath atomically:YES];
}

+ (nonnull NSString *)_getNewEmptyClassName
{
    static NSString *curretClassName = nil;
    static int num = 0;
    if (nil == curretClassName) {
        curretClassName = @"DDEmptyObject";
    } else {
        curretClassName = [NSString stringWithFormat:@"DDEmptyObject%d", num];
    }
    num++;
    return curretClassName;
}

+ (nonnull NSString *)_getNewEmptyCategoryName
{
    static NSString *curretCategoryName = nil;
    static int num = 0;
    if (nil == curretCategoryName) {
        curretCategoryName = @"DDEmptyCategory";
    } else {
        curretCategoryName = [NSString stringWithFormat:@"DDEmptyCategory%d", num];
    }
    num++;
    return curretCategoryName;
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

@implementation DDStaticLibraryInfo
+ (nonnull instancetype)infoWithPath:(nonnull NSString *)path tag:(nonnull NSString *)tag
{
    DDStaticLibraryInfo *info = [[self alloc] init];
    info.path = path;
    info.tag = tag;
    info.isDefault = false;
    return info;
}
@end

@implementation DDABTestInfo
@end

@implementation DDStaticLibrary(DDABTestTool)
const char *DDStaticLibrary_DataKey = "DDStaticLibrary_Data";
- (void)setData:(DDIRModuleData *)data
{
    objc_setAssociatedObject(self, DDStaticLibrary_DataKey, data, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (DDIRModuleData *)data
{
    return objc_getAssociatedObject(self, DDStaticLibrary_DataKey);
}
@end
