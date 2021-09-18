//
//  DDABTestTool.m
//  DDToolKit
//
//  Created by dondong on 2021/9/10.
//

#import "DDABTestTool.h"
#import "DDCommonDefine.h"
#import "DDStaticLibrary.h"

@interface DDStaticLibraryInfo()
@property(nonatomic,strong) DDStaticLibrary *lib;
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
        i.lib = [DDStaticLibrary libraryFromPath:i.path tempDir:[info.tempDirectory stringByAppendingPathComponent:i.tag]];
        maxClsCount = MAX(maxClsCount, i.lib.classList.count);
        maxCatCount = MAX(maxCatCount, i.lib.categoryList.count);
    }
    assert(NULL != defaultInfo && defaultInfo.lib.moduleList.count > 0);
    // add empty
    NSUInteger emptyClsCount = maxClsCount - defaultInfo.lib.classList.count;
    NSMutableArray<NSString *> *emptyClasses = [NSMutableArray arrayWithCapacity:emptyClsCount];
    NSUInteger emptyCatCount = maxCatCount - defaultInfo.lib.categoryList.count;
    NSMutableArray<NSString *> *emptyCategories = [NSMutableArray arrayWithCapacity:emptyCatCount];
    [defaultInfo.lib.moduleList[0] executeChangesWithBlock:^(DDIRModule * _Nullable module) {
        for (int i = 0; i < emptyClsCount; ++i) {
            NSString *n = [self getNewEmptyClassName];
            [module addEmptyClass:n];
            [emptyClasses addObject:n];
        }
        NSString *clsName = emptyClasses.count > 0 ? emptyClasses[0] : @"NSObject";
        for (int i = 0; i < emptyCatCount; ++i) {
            NSString *n = [self getNewEmptyCategoryName];
            [module addEmptyCategory:n toClass:clsName];
            [emptyCategories addObject:n];
        }
    }];
    
   NSMutableArray *llfilePathes = [NSMutableArray array];
   for (DDIRModule *m in defaultInfo.lib.moduleList) {
       [llfilePathes addObject:m.path];
   }
    NSMutableDictionary *config = [NSMutableDictionary dictionary];
    [outputConfig setObject:config forKey:info.moduleName];
    NSMutableDictionary *classDic = [NSMutableDictionary dictionaryWithCapacity:defaultInfo.lib.classList.count];
    for (DDIRObjCClass *cls in defaultInfo.lib.classList) {
        [classDic setObject:cls forKey:cls.className];
    }
    NSMutableDictionary *categoryDic = [NSMutableDictionary dictionaryWithCapacity:defaultInfo.lib.categoryList.count];
    for (DDIRObjCCategory *cat in defaultInfo.lib.categoryList) {
        [categoryDic setObject:cat forKey:[NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName]];
    }
    for (DDStaticLibraryInfo *i in info.inputLibraries) {
        if (i != defaultInfo) {
            
            NSMutableDictionary *clsDic2 = [NSMutableDictionary dictionaryWithCapacity:i.lib.classList.count];
            for (DDIRObjCClass *cls in i.lib.classList) {
                [clsDic2 setObject:cls forKey:cls.className];
            }
            NSMutableDictionary *catDic2 = [NSMutableDictionary dictionaryWithCapacity:i.lib.categoryList.count];
            for (DDIRObjCCategory *cat in i.lib.categoryList) {
                [catDic2 setObject:cat forKey:[NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName]];
            }
            
            NSMutableArray<DDIRObjCClass *> *comClsArray = [NSMutableArray array];
            NSMutableArray<DDIRObjCClass *> *clsArray1   = [NSMutableArray array];
            NSMutableArray<DDIRObjCClass *> *clsArray2   = [NSMutableArray array];
            NSMutableArray<DDIRObjCCategory *> *comCatArray = [NSMutableArray array];
            NSMutableArray<DDIRObjCCategory *> *catArray1   = [NSMutableArray array];
            NSMutableArray<DDIRObjCCategory *> *catArray2   = [NSMutableArray array];
            
            /*
              compare
             */
            // class
            for (NSString *key in classDic.allKeys) {
                if (nil != [clsDic2 objectForKey:key]) {
                    [comClsArray addObject:[classDic objectForKey:key]];
                } else {
                    [clsArray1 addObject:[classDic objectForKey:key]];
                }
            }
            for (NSString *key in clsDic2.allKeys) {
                if (nil == [classDic objectForKey:key]) {
                    [clsArray2 addObject:[clsDic2 objectForKey:key]];
                }
            }
            // category
            for (NSString *key in categoryDic.allKeys) {
                if (nil != [catDic2 objectForKey:key]) {
                    [comCatArray addObject:[categoryDic objectForKey:key]];
                } else {
                    [catArray1 addObject:[categoryDic objectForKey:key]];
                }
            }
            for (NSString *key in catDic2.allKeys) {
                if (nil == [categoryDic objectForKey:key]) {
                    [catArray2 addObject:[catDic2 objectForKey:key]];
                }
            }
            
            /*
              conpute
             */
            NSString *t = [NSString stringWithFormat:@"%4lu", [i.tag hash] % 10000];
            NSString *clsSectionName = [NSString stringWithFormat:@"__%@_clslist",t];
            NSString *catSectionName = [NSString stringWithFormat:@"__%@_catlist", t];
            NSMutableArray *clsArray = [NSMutableArray array];
            NSMutableArray *catArray = [NSMutableArray array];
            NSMutableDictionary *c = [NSMutableDictionary dictionary];
            [config setObject:c forKey:i.tag];
            [c setObject:[NSString stringWithFormat:@"__DATA,%@", clsSectionName] forKey:DDModuleClassSectionKey];
            [c setObject:[NSString stringWithFormat:@"__DATA,%@", catSectionName] forKey:DDModuleCategorySectionKey];
            [c setObject:clsArray forKey:DDModuleClassKey];
            [c setObject:catArray forKey:DDModuleCategoryKey];
            for (DDIRModule *m in i.lib.moduleList) {
                NSString *n = [m.path lastPathComponent];
                NSString *p = [[m.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:[[n stringByDeletingPathExtension] stringByAppendingString:@"_tmp.ll"]];
                [llfilePathes addObject:p];
                [m executeChangesWithSavePath:p block:^(DDIRModule * _Nullable module) {
                    // class
                    for (DDIRObjCClass *cls in comClsArray) {
                        NSString *newName = [cls.className stringByAppendingFormat:@"_%@", i.tag];
                        [clsArray addObject:@{DDItemSrcKey: cls.className,
                                              DDItemDstKey: cls.className}];
                        [module replaceObjcClass:cls.className  withNewComponentName:newName];
                        [module moveClass:cls.className to:clsSectionName];
                    }
                    for (int i = 0; i < clsArray2.count; ++i) {
                        DDIRObjCClass *cls = clsArray2[i];
                        NSString *targetName = (i < clsArray1.count ? [clsArray1[i] className] : emptyClasses[i - clsArray1.count]);
                        [module moveClass:cls.className to:clsSectionName];
                        [clsArray addObject:@{DDItemSrcKey: targetName,
                                              DDItemDstKey: cls.className}];
                    }
                    // category
                    for (DDIRObjCCategory *cat in comCatArray) {
                        NSString *newName = [cat.categoryName stringByAppendingFormat:@"_%@", i.tag];
                        [catArray addObject:@{DDItemSrcKey: [NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName],
                                              DDItemDstKey: [NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName]}];
                        [module replaceCategory:cat.categoryName forObjcClass:cat.isa.className withNewComponentName:newName];
                        [module moveCategory:cat.categoryName forObjcClass:cat.isa.className to:catSectionName];
                    }
                    for (int i = 0; i < catArray2.count; ++i) {
                        DDIRObjCCategory *cat = catArray2[i];
                        NSString *targetName = (i < catArray2.count ? [catArray1[i] className] : emptyCategories[i - catArray1.count]);
                        [module moveCategory:cat.categoryName forObjcClass:cat.isa.className to:catSectionName];
                        [catArray addObject:@{DDItemSrcKey: targetName,
                                              DDItemDstKey: [NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName]}];
                    }
                }];
            }
        }
    }
    
    NSString *tmpDir = [[info.outputPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"tmp"];
    [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:tmpDir withIntermediateDirectories:YES attributes:nil error:NULL];
    for (NSString *path in llfilePathes) {
        NSString *name = [path lastPathComponent];
        system([[NSString stringWithFormat:@"xcrun clang -O1 -target arm64-apple-ios9 -fembed-bitcode -c %@ -o %@", path, [tmpDir stringByAppendingPathComponent:[[name stringByDeletingPathExtension] stringByAppendingString:@".o"]]] cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    system([[NSString stringWithFormat:@"ar -rcs %@ %@/*.o", info.outputPath, tmpDir] cStringUsingEncoding:NSUTF8StringEncoding]);
    [[NSFileManager defaultManager] removeItemAtPath:tmpDir error:NULL];
    
    for (DDStaticLibraryInfo *i in info.inputLibraries) {
        [i.lib clear];
    }
    [outputConfig writeToFile:info.configPath atomically:YES];
}

+ (nonnull NSString *)getNewEmptyClassName
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

+ (nonnull NSString *)getNewEmptyCategoryName
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
