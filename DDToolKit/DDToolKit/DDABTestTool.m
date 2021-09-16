//
//  DDABTestTool.m
//  DDToolKit
//
//  Created by dondong on 2021/9/10.
//

#import "DDABTestTool.h"
#import "DDLibrary.h"

@implementation DDABTestTool

+ (void)mergeStaticLibraryWithFile:(nonnull NSString *)inputPath1
                           andFile:(nonnull NSString *)inputPath2
                            toFile:(nonnull NSString *)outputPath
{
    [self mergeStaticLibraryWithFile:inputPath1 verson:@"1" andFile:inputPath2 verson:@"2" toFile:outputPath defaultFile:inputPath1];
}

+ (void)mergeStaticLibraryWithFile:(nonnull NSString *)inputPath1 verson:(nonnull NSString *)version1
                           andFile:(nonnull NSString *)inputPath2 verson:(nonnull NSString *)version2
                            toFile:(nonnull NSString *)outputPath
{
    [self mergeStaticLibraryWithFile:inputPath1 verson:version1 andFile:inputPath2 verson:version2 toFile:outputPath defaultFile:inputPath1];
}

+ (void)mergeStaticLibraryWithFile:(nonnull NSString *)inputPath1 verson:(nonnull NSString *)version1
                           andFile:(nonnull NSString *)inputPath2 verson:(nonnull NSString *)version2
                            toFile:(nonnull NSString *)outputPath
                       defaultFile:(nonnull NSString *)defaultPath
{
    DDLibrary *lib1 = [DDLibrary libraryFromPath:inputPath1 tempDir:@""];
    NSMutableDictionary *classDic1 = [NSMutableDictionary dictionaryWithCapacity:lib1.classList.count];
    for (DDIRObjCClass *cls in lib1.classList) {
        [classDic1 setObject:cls forKey:cls.className];
    }
    NSMutableDictionary *categoryDic1 = [NSMutableDictionary dictionaryWithCapacity:lib1.categoryList.count];
    for (DDIRObjCCategory *cat in lib1.categoryList) {
        if (nil == [classDic1 objectForKey:cat.isa.className]) {
            [categoryDic1 setObject:cat forKey:[NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName]];
        }
    }
    
    DDLibrary *lib2 = [DDLibrary libraryFromPath:inputPath2 tempDir:@""];
    NSMutableDictionary *classDic2 = [NSMutableDictionary dictionaryWithCapacity:lib2.classList.count];
    for (DDIRObjCClass *cls in lib2.classList) {
        [classDic2 setObject:cls forKey:cls.className];
    }
    NSMutableDictionary *categoryDic2 = [NSMutableDictionary dictionaryWithCapacity:lib2.categoryList.count];
    for (DDIRObjCCategory *cat in lib2.categoryList) {
        if (nil == [classDic2 objectForKey:cat.isa.className]) {
            [categoryDic2 setObject:cat forKey:[NSString stringWithFormat:@"%@(%@)", cat.isa.className, cat.categoryName]];
        }
    }
    
}
@end
