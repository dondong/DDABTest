//
//  DDStaticLibrary+Merge.h
//  DDToolKit
//
//  Created by dondong on 2021/12/1.
//

#import "DDStaticLibrary.h"

NS_ASSUME_NONNULL_BEGIN

@interface DDStaticLibrary(Merge)
+ (nullable DDStaticLibrary *)mergeLibraries:(nonnull NSArray<DDStaticLibrary *> *)libraries
                               withControlId:(UInt32)controlId
                                 toLibraries:(nonnull NSString *)outputLibrary
                                   directory:(nonnull NSString *)outputDirectory;
@end

NS_ASSUME_NONNULL_END
