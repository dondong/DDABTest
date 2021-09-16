//
//  DDABTestTool.h
//  DDToolKit
//
//  Created by dondong on 2021/9/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DDABTestTool : NSObject
+ (void)mergeStaticLibraryWithFile:(nonnull NSString *)inputPath1
                           andFile:(nonnull NSString *)inputPath2
                            toFile:(nonnull NSString *)outputPath;
+ (void)mergeStaticLibraryWithFile:(nonnull NSString *)inputPath1 verson:(nonnull NSString *)version1
                           andFile:(nonnull NSString *)inputPath2 verson:(nonnull NSString *)version2
                            toFile:(nonnull NSString *)outputPath;
+ (void)mergeStaticLibraryWithFile:(nonnull NSString *)inputPath1 verson:(nonnull NSString *)version1
                           andFile:(nonnull NSString *)inputPath2 verson:(nonnull NSString *)version2
                            toFile:(nonnull NSString *)outputPath
                       defaultFile:(nonnull NSString *)defaultPath;
@end

NS_ASSUME_NONNULL_END
