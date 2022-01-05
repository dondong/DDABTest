//
//  DDStaticLibrary+Private.h
//  DDToolKit
//
//  Created by dondong on 2021/12/1.
//

#import "DDStaticLibrary.h"

NS_ASSUME_NONNULL_BEGIN

@interface DDStaticLibrary()
@property(nonatomic,strong,readwrite,nonnull) NSString *path;
@property(nonatomic,strong,readwrite,nonnull) NSString *tmpPath;
@end

NS_ASSUME_NONNULL_END
