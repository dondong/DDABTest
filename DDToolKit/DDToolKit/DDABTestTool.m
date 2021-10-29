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
@end

@interface DDStaticLibrary(DDABTestTool)
@property(nonatomic,strong) DDIRModuleData *data;
@end


@implementation DDABTestTool

+ (void)mergeStaticLibrariesWithInfo:(nonnull DDABTestInfo *)info
{
    NSMutableDictionary *outputConfig = [NSMutableDictionary dictionary];
    if ([[NSFileManager defaultManager] fileExistsAtPath:info.configPath]) {
        outputConfig = [NSMutableDictionary dictionaryWithContentsOfFile:info.configPath];
    } else {
        outputConfig = [NSMutableDictionary dictionary];
    }
    
    DDStaticLibraryInfo *defaultInfo = nil;
    NSInteger maxClsCount = 0;
    NSInteger maxCatCount = 0;
    for (DDStaticLibraryInfo *i in info.inputLibraries) {
        if (i.isDefault || nil == defaultInfo) {
            defaultInfo = i;
        }
        i.lib = [DDStaticLibrary libraryFromPath:i.path tempDir:info.tempDirectory];
        [i.lib.module executeChangesWithBlock:^(DDIRModule * _Nullable module) {
            [module mergeObjcData];
        }];
        i.lib.data = [i.lib.module getData];
        maxClsCount = MAX(maxClsCount, i.lib.data.objcClassList.count);
        maxCatCount = MAX(maxCatCount, i.lib.data.objcCategoryList.count);
    }
    assert(NULL != defaultInfo);
    // add empty
//    NSUInteger emptyClsCount = maxClsCount - defaultInfo.lib.data.objcClassList.count;
//    NSMutableArray<NSString *> *emptyClasses = [NSMutableArray arrayWithCapacity:emptyClsCount];
//    NSUInteger emptyCatCount = maxCatCount - defaultInfo.lib.data.objcCategoryList.count;
//    NSMutableArray<NSString *> *emptyCategories = [NSMutableArray arrayWithCapacity:emptyCatCount];
//    [defaultInfo.lib.module executeChangesWithBlock:^(DDIRModule * _Nullable module) {
//        for (int i = 0; i < emptyClsCount; ++i) {
//            NSString *n = [self _getNewEmptyClassName];
//            [module addEmptyClass:n];
//            [emptyClasses addObject:n];
//        }
//        NSString *clsName = emptyClasses.count > 0 ? emptyClasses[0] : @"NSObject";
//        for (int i = 0; i < emptyCatCount; ++i) {
//            NSString *n = [self _getNewEmptyCategoryName];
//            [module addEmptyCategory:n toClass:clsName];
//            [emptyCategories addObject:[NSString stringWithFormat:@"%@(%@)", clsName, n]];
//        }
//    }];
//
//    NSMutableArray *llfilePathes = [NSMutableArray array];
//    [llfilePathes addObject:defaultInfo.lib.module.path];
//    NSMutableDictionary *config = [NSMutableDictionary dictionary];
//    [outputConfig setObject:config forKey:info.moduleName];
//    NSMutableDictionary *classDic = [NSMutableDictionary dictionaryWithCapacity:defaultInfo.lib.data.objcClassList.count];
//    for (DDIRObjCClass *cls in defaultInfo.lib.data.objcClassList) {
//        [classDic setObject:cls forKey:cls.className];
//    }
//    NSMutableDictionary *categoryDic = [NSMutableDictionary dictionaryWithCapacity:defaultInfo.lib.data.objcClassList.count];
//    for (DDIRObjCCategory *cat in defaultInfo.lib.data.objcCategoryList) {
//        [categoryDic setObject:cat forKey:[NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName]];
//    }
//    for (DDStaticLibraryInfo *i in info.inputLibraries) {
//        if (i != defaultInfo) {
//
//            NSMutableDictionary *clsDic2 = [NSMutableDictionary dictionaryWithCapacity:i.lib.data.objcClassList.count];
//            for (DDIRObjCClass *cls in i.lib.data.objcClassList) {
//                [clsDic2 setObject:cls forKey:cls.className];
//            }
//            NSMutableDictionary *catDic2 = [NSMutableDictionary dictionaryWithCapacity:i.lib.data.objcClassList.count];
//            for (DDIRObjCCategory *cat in i.lib.data.objcCategoryList) {
//                [catDic2 setObject:cat forKey:[NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName]];
//            }
//
//            NSMutableArray<DDIRObjCClass *> *comClsArray = [NSMutableArray array];
//            NSMutableArray<DDIRObjCClass *> *clsArray1   = [NSMutableArray array];
//            NSMutableArray<DDIRObjCClass *> *clsArray2   = [NSMutableArray array];
//            NSMutableArray<DDIRObjCCategory *> *comCatArray = [NSMutableArray array];
//            NSMutableArray<DDIRObjCCategory *> *catArray1   = [NSMutableArray array];
//            NSMutableArray<DDIRObjCCategory *> *catArray2   = [NSMutableArray array];
//
//            /*
//              compare
//             */
//            // class
//            for (NSString *key in classDic.allKeys) {
//                if (nil != [clsDic2 objectForKey:key]) {
//                    [comClsArray addObject:[classDic objectForKey:key]];
//                } else {
//                    [clsArray1 addObject:[classDic objectForKey:key]];
//                }
//            }
//            for (NSString *key in clsDic2.allKeys) {
//                if (nil == [classDic objectForKey:key]) {
//                    [clsArray2 addObject:[clsDic2 objectForKey:key]];
//                }
//            }
//            // category
//            for (NSString *key in categoryDic.allKeys) {
//                if (nil != [catDic2 objectForKey:key]) {
//                    [comCatArray addObject:[categoryDic objectForKey:key]];
//                } else {
//                    [catArray1 addObject:[categoryDic objectForKey:key]];
//                }
//            }
//            for (NSString *key in catDic2.allKeys) {
//                if (nil == [categoryDic objectForKey:key]) {
//                    [catArray2 addObject:[catDic2 objectForKey:key]];
//                }
//            }
//
//            /*
//              conpute
//             */
//            NSString *t = [NSString stringWithFormat:@"%4lu", [i.tag hash] % 10000];
//            NSString *clsSectionName = [NSString stringWithFormat:@"__%@_clslist",t];
//            NSString *catSectionName = [NSString stringWithFormat:@"__%@_catlist", t];
//            NSMutableArray *clsArray = [NSMutableArray array];
//            NSMutableArray *catArray = [NSMutableArray array];
//            NSMutableDictionary *c = [NSMutableDictionary dictionary];
//            [config setObject:c forKey:i.tag];
//            [c setObject:clsSectionName forKey:DDModuleClassSectionKey];
//            [c setObject:catSectionName forKey:DDModuleCategorySectionKey];
//            [c setObject:clsArray forKey:DDModuleClassKey];
//            [c setObject:catArray forKey:DDModuleCategoryKey];
//            DDIRModule *m = i.lib.module;
//            NSString *n = [m.path lastPathComponent];
//            NSString *p = [[m.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[n stringByDeletingPathExtension] stringByAppendingString:@"_tmp.ll"]];
//            [llfilePathes addObject:p];
//            [m executeChangesWithSavePath:p block:^(DDIRModule * _Nullable module) {
//                // class
//                for (DDIRObjCClass *cls in comClsArray) {
//                    NSString *newName = [cls.className stringByAppendingFormat:@"_%@", i.tag];
//                    if ([module replaceObjcClass:cls.className  withNewComponentName:newName]) {
//                        [module moveClass:cls.className to:[NSString stringWithFormat:@"__DATA,%@", clsSectionName]];
//                        [clsArray addObject:@{DDItemSrcKey: cls.className,
//                                              DDItemDstKey: cls.className}];
//                    }
//                }
//                for (int i = 0; i < clsArray2.count; ++i) {
//                    DDIRObjCClass *cls = clsArray2[i];
//                    NSString *targetName = (i < clsArray1.count ? [clsArray1[i] className] : emptyClasses[i - clsArray1.count]);
//                    if ([module moveClass:cls.className to:[NSString stringWithFormat:@"__DATA,%@", clsSectionName]]) {
//                        [clsArray addObject:@{DDItemSrcKey: targetName,
//                                              DDItemDstKey: cls.className}];
//                    }
//                }
//                // category
//                for (DDIRObjCCategory *cat in comCatArray) {
//                    NSString *newName = [cat.categoryName stringByAppendingFormat:@"_%@", i.tag];
//                    if ([module replaceCategory:cat.categoryName forObjcClass:cat.isa.className withNewComponentName:newName]) {
//                        [module moveCategory:cat.categoryName forObjcClass:cat.isa.className to:[NSString stringWithFormat:@"__DATA,%@", catSectionName]];
//                        [catArray addObject:@{DDItemSrcKey: [NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName],
//                                              DDItemDstKey: [NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName]}];
//                    }
//                }
//                for (int i = 0; i < catArray2.count; ++i) {
//                    DDIRObjCCategory *cat = catArray2[i];
//                    NSString *targetName = (i < catArray1.count ? [NSString stringWithFormat:@"%@(%@)", [[catArray1[i] isa] className], [catArray1[i] categoryName]] : emptyCategories[i - catArray1.count]);
//                    if ([module moveCategory:cat.categoryName forObjcClass:cat.isa.className to:[NSString stringWithFormat:@"__DATA,%@", catSectionName]]) {
//                        [catArray addObject:@{DDItemSrcKey: targetName,
//                                              DDItemDstKey: [NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName]}];
//                    }
//                }
//            }];
//        }
//    }
    
    NSMutableArray *llfilePathes = [NSMutableArray array];
    [llfilePathes addObject:defaultInfo.lib.module.path];
    for (DDStaticLibraryInfo *i in info.inputLibraries) {
        if (i != defaultInfo) {
            [llfilePathes addObject:i.lib.module.path];
        }
    }
    NSString *llfile = [info.tempDirectory stringByAppendingPathComponent:[info.moduleName stringByAppendingPathExtension:@"ll"]];
    [DDIRModule mergeLLFiles:llfilePathes withControlId:4 toLLFile:llfile];
    
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
//        for (NSString *path in llfilePathes) {
//            NSString *name = [path lastPathComponent];
//            system([[NSString stringWithFormat:@"xcrun clang -O1 -target %@ -fembed-bitcode -c %@ -o %@", target, path, [tmpDir stringByAppendingPathComponent:[[name stringByDeletingPathExtension] stringByAppendingString:@".o"]]] cStringUsingEncoding:NSUTF8StringEncoding]);
//        }
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
    
    for (DDStaticLibraryInfo *i in info.inputLibraries) {
        [i.lib clear];
    }
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
