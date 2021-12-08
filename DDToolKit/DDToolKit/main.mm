//
//  main.m
//  DDToolKit
//
//  Created by dondong on 2021/8/13.
//

#import <Foundation/Foundation.h>
#import "DDABTestTool.h"
#import "DDStaticLibrary.h"
#import "DDIRModule.h"
#import "DDIRModule+Merge.h"
#import "DDToolKitDefine.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (argc >= 7) {
            DDABTestInfo *info = [[DDABTestInfo alloc] init];
            NSMutableArray *libraries = [NSMutableArray array];
            for (int i = 1; i + 1 < argc; i += 2) {
                if (0 == strcmp(argv[i], "--name")) {
                    info.moduleName = [NSString stringWithCString:argv[i + 1] encoding:NSUTF8StringEncoding];
                } else if (0 == strcmp(argv[i], "--id")) {
                    info.moduleId = (UInt32)[[NSString stringWithCString:argv[i + 1] encoding:NSUTF8StringEncoding] integerValue];
                } else if (0 == strcmp(argv[i], "--output")) {
                    info.outputPath = [NSString stringWithCString:argv[i + 1] encoding:NSUTF8StringEncoding];
                } else if (0 == strcmp(argv[i], "--tmp")) {
                    info.tempDirectory = [NSString stringWithCString:argv[i + 1] encoding:NSUTF8StringEncoding];
                } else if (0 == strcmp(argv[i], "--output_config")) {
                    info.configPath = [NSString stringWithCString:argv[i + 1] encoding:NSUTF8StringEncoding];
                } else {
                    NSString *path = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
                    NSString *tag = [NSString stringWithCString:argv[i + 1] encoding:NSUTF8StringEncoding];
                    DDStaticLibraryInfo *lib = [DDStaticLibraryInfo infoWithPath:path tag:tag];
                    [libraries addObject:lib];
                }
            }
            if (libraries.count >= 1 && nil != info.moduleName && info.moduleId > 0 && nil != info.outputPath) {
                if (nil == info.tempDirectory) {
                    info.tempDirectory = [[info.outputPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"tmp"];
                }
                if (nil == info.configPath) {
                    info.configPath = [[info.outputPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"DDABTestConfiguration.plist"];
                }

                if (NO == [[NSFileManager defaultManager] fileExistsAtPath:info.tempDirectory]) {
                    [[NSFileManager defaultManager] createDirectoryAtPath:info.tempDirectory withIntermediateDirectories:YES attributes:nil error:NULL];
                }
                [libraries[0] setIsDefault:true];
                info.inputLibraries = libraries;
                [DDABTestTool mergeStaticLibrariesWithInfo:info];
#if CleanTempFiles
                [[NSFileManager defaultManager] removeItemAtPath:info.tempDirectory error:NULL];
#endif
            }
        }
    }
    return 0;
}
