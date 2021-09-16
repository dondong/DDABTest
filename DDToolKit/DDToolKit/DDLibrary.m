//
//  DDLibrary.m
//  DDToolKit
//
//  Created by dondong on 2021/9/9.
//

#import "DDLibrary.h"

@interface DDLibrary()
@property(nonatomic,strong,readwrite,nonnull) NSString *path;
@property(nonatomic,strong,readwrite,nonnull) NSString *tmpPath;
@property(nonatomic,strong,readwrite,nonnull) NSArray<NSString *> *architectures;
@property(nonatomic,strong,readwrite,nonnull) NSArray<NSString *> *ofilePathes;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRModule *> *moduleList;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRObjCClass *> *classList;
@property(nonatomic,strong,readwrite,nonnull) NSArray<DDIRObjCCategory *> *categoryList;
@end

@implementation DDLibrary
+ (nullable instancetype)libraryFromPath:(nonnull NSString *)path tempDir:(nonnull NSString *)tempDir
{
    DDLibrary *library = [[self alloc] init];
    library.path = path;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:tempDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    library.tmpPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld", random()]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:library.tmpPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:library.tmpPath error:NULL];
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:library.tmpPath withIntermediateDirectories:YES attributes:nil error:NULL];
    
    NSMutableArray *architectures = [NSMutableArray array];
    NSString *archStrPath = [library.tmpPath stringByAppendingPathComponent:@"arch.txt"];
    system([[NSString stringWithFormat:@"lipo -info %@ > %@", path, archStrPath] cStringUsingEncoding:NSUTF8StringEncoding]);
    NSString *archStr = [NSString stringWithContentsOfFile:archStrPath encoding:NSUTF8StringEncoding error:NULL];
    for (NSString *a in [[[archStr componentsSeparatedByString:@" are:"] lastObject] componentsSeparatedByString:@" "]) {
        NSString *v = [a stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (v.length > 0) {
            [architectures addObject:v];
        }
    }
    library.architectures = [NSArray arrayWithArray:architectures];
    [[NSFileManager defaultManager] removeItemAtPath:archStrPath error:NULL];
    
    NSString *outputLibraryPath = [library.tmpPath stringByAppendingPathComponent:library.path.lastPathComponent];
    NSString *arch = [library.architectures containsObject:@"arm64"] ? @"arm64" : [architectures lastObject];
    system([[NSString stringWithFormat:@"lipo -thin %@ %@ -output %@", arch, library.path, outputLibraryPath] cStringUsingEncoding:NSUTF8StringEncoding]);
    system([[NSString stringWithFormat:@"tar -xf %@ -C %@", outputLibraryPath, library.tmpPath] cStringUsingEncoding:NSUTF8StringEncoding]);
    [[NSFileManager defaultManager] removeItemAtPath:outputLibraryPath error:NULL];
    
    NSMutableArray *moduleList = [[NSMutableArray alloc] init];
    for (NSString *p in [[NSFileManager defaultManager] subpathsAtPath:library.tmpPath]) {
        if ([[[p pathExtension] lowercaseString] isEqualToString:@"o"]) {
            NSString *ofilePath = [library.tmpPath stringByAppendingPathComponent:p];
            NSString *bcPath = [[ofilePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"bc"];
            NSString *llPath = [[ofilePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"ll"];
            system([[NSString stringWithFormat:@"segedit %@ -extract __LLVM __bitcode %@", ofilePath, bcPath] cStringUsingEncoding:NSUTF8StringEncoding]);
            system([[NSString stringWithFormat:@"/usr/local/bin/llvm-dis %@ %@", bcPath, llPath] cStringUsingEncoding:NSUTF8StringEncoding]);
            DDIRModule *module = [DDIRModule moduleFromLLPath:llPath];
            if (nil != module) {
                [moduleList addObject:module];
            }
            [[NSFileManager defaultManager] removeItemAtPath:ofilePath error:NULL];
            [[NSFileManager defaultManager] removeItemAtPath:bcPath error:NULL];
        }
    }
    library.moduleList = [NSArray arrayWithArray:moduleList];

    NSMutableArray *classList = [[NSMutableArray alloc] init];
    NSMutableArray *categoryList = [[NSMutableArray alloc] init];
    for (DDIRModule *module in library.moduleList) {
        [classList addObjectsFromArray:module.objcClassList];
        [categoryList addObjectsFromArray:module.objcCategoryList];
    }
    library.classList = [NSArray arrayWithArray:classList];
    library.categoryList = [NSArray arrayWithArray:categoryList];
    return library;
}

- (void)clear
{
    if (nil != self.tmpPath && [[NSFileManager defaultManager] fileExistsAtPath:self.tmpPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.tmpPath error:NULL];
    }
}
@end
