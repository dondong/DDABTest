//
//  DDStaticLibrary.m
//  DDToolKit
//
//  Created by dondong on 2021/9/9.
//

#import "DDStaticLibrary.h"
#import "DDStaticLibrary+Private.h"
#import "DDToolKitDefine.h"
#import "DDIRModule+Merge.h"

@implementation DDStaticLibrary
+ (nullable instancetype)libraryFromPath:(nonnull NSString *)path tempDir:(nonnull NSString *)tempDir
{
    DDStaticLibrary *library = [[self alloc] init];
    library.path = path;
    if (NO == [[NSFileManager defaultManager] fileExistsAtPath:tempDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    library.tmpPath = [tempDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%u", arc4random()]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:library.tmpPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:library.tmpPath error:NULL];
    }
    [[NSFileManager defaultManager] createDirectoryAtPath:library.tmpPath withIntermediateDirectories:YES attributes:nil error:NULL];
    
    NSMutableArray *architectures = [NSMutableArray array];
    NSString *archStrPath = [library.tmpPath stringByAppendingPathComponent:@"arch.txt"];
    system([[NSString stringWithFormat:@"lipo -info %@ > %@", path, archStrPath] cStringUsingEncoding:NSUTF8StringEncoding]);
    NSString *archStr = [NSString stringWithContentsOfFile:archStrPath encoding:NSUTF8StringEncoding error:NULL];
    if ([archStr containsString:@" are:"]) {
        for (NSString *a in [[[archStr componentsSeparatedByString:@" are:"] lastObject] componentsSeparatedByString:@" "]) {
            NSString *v = [a stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (v.length > 0) {
                [architectures addObject:v];
            }
        }
    } else {
        [architectures addObject:[[[archStr componentsSeparatedByString:@"is architecture:"] lastObject] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    }
    library.architectures = [NSArray arrayWithArray:architectures];
    [[NSFileManager defaultManager] removeItemAtPath:archStrPath error:NULL];
    
    if (architectures.count > 1) {
        NSString *outputLibraryPath = [library.tmpPath stringByAppendingPathComponent:library.path.lastPathComponent];
        NSString *arch = [library.architectures containsObject:@"arm64"] ? @"arm64" : [architectures lastObject];
        system([[NSString stringWithFormat:@"lipo -thin %@ %@ -output %@", arch, library.path, outputLibraryPath] cStringUsingEncoding:NSUTF8StringEncoding]);
        system([[NSString stringWithFormat:@"tar -xf %@ -C %@", outputLibraryPath, library.tmpPath] cStringUsingEncoding:NSUTF8StringEncoding]);
        [[NSFileManager defaultManager] removeItemAtPath:outputLibraryPath error:NULL];
    } else {
        system([[NSString stringWithFormat:@"tar -xf %@ -C %@", path, library.tmpPath] cStringUsingEncoding:NSUTF8StringEncoding]);
    }
    
    NSMutableArray *pathList = [NSMutableArray array];
    for (NSString *p in [[NSFileManager defaultManager] subpathsAtPath:library.tmpPath]) {
        if ([[[p pathExtension] lowercaseString] isEqualToString:@"o"]) {
            NSString *ofilePath = [library.tmpPath stringByAppendingPathComponent:p];
            NSString *bcPath = [[ofilePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"bc"];
#if EnableDebug
            NSString *llPath = [[ofilePath stringByDeletingPathExtension] stringByAppendingPathExtension:@"ll"];
            system([[NSString stringWithFormat:@"segedit %@ -extract __LLVM __bitcode %@", ofilePath, bcPath] cStringUsingEncoding:NSUTF8StringEncoding]);
            system([[NSString stringWithFormat:@"/usr/local/bin/llvm-dis %@ %@", bcPath, llPath] cStringUsingEncoding:NSUTF8StringEncoding]);
            [pathList addObject:llPath];
            [[NSFileManager defaultManager] removeItemAtPath:ofilePath error:NULL];
            [[NSFileManager defaultManager] removeItemAtPath:bcPath error:NULL];
#else
            system([[NSString stringWithFormat:@"segedit %@ -extract __LLVM __bitcode %@", ofilePath, bcPath] cStringUsingEncoding:NSUTF8StringEncoding]);
            [pathList addObject:bcPath];
            [[NSFileManager defaultManager] removeItemAtPath:ofilePath error:NULL];
#endif
        }
    }
    library.pathList = [NSMutableArray arrayWithArray:pathList];
    return library;
}

- (void)clear
{
    if (nil != self.tmpPath && [[NSFileManager defaultManager] fileExistsAtPath:self.tmpPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.tmpPath error:NULL];
    }
}
@end
