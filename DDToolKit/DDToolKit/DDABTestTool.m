//
//  DDABTestTool.m
//  DDToolKit
//
//  Created by dondong on 2021/9/10.
//

#import "DDABTestTool.h"
#import "DDCommonDefine.h"
#import "DDToolKitDefine.h"
#import "DDStaticLibrary.h"
#import "DDStaticLibrary+Merge.h"
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
    }
    assert(nil != defaultInfo);
    NSMutableArray *libraries = [NSMutableArray array];
    UInt32 index = 0;
    [libraries addObject:defaultInfo.lib];
    defaultInfo.index = index;
    index++;
    for (DDStaticLibraryInfo *i in info.inputLibraries) {
        if (i != defaultInfo) {
            [libraries addObject:i.lib];
            i.index = index;
            index++;
        }
    }
    DDStaticLibrary *outputLibrary = [DDStaticLibrary mergeLibraries:libraries
                                                       withControlId:info.moduleId
                                                         toLibraries:info.outputPath
                                                           directory:[info.tempDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"tmp_%u", arc4random()]]];
#if CleanTempFiles
    [outputLibrary clear];
    for (DDStaticLibraryInfo *i in info.inputLibraries) {
        [i.lib clear];
    }
#endif
    
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
