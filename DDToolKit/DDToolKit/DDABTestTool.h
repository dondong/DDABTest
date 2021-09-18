//
//  DDABTestTool.h
//  DDToolKit
//
//  Created by dondong on 2021/9/10.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DDStaticLibraryInfo : NSObject
@property(nonatomic,strong,nonnull) NSString *path;
@property(nonatomic,strong,nonnull) NSString *tag;
@property(nonatomic,assign) BOOL isDefault;
+ (nonnull instancetype)infoWithPath:(nonnull NSString *)path tag:(nonnull NSString *)tag;
@end

@interface DDABTestInfo : NSObject
@property(nonatomic,strong,nullable) NSString *moduleName;
@property(nonatomic,strong,nullable) NSString *tempDirectory;
@property(nonatomic,strong,nullable) NSArray<DDStaticLibraryInfo *> *inputLibraries;
@property(nonatomic,strong,nullable) NSString *outputPath;
@property(nonatomic,strong,nullable) NSString *configPath;
@end

@interface DDABTestTool : NSObject
+ (void)mergeStaticLibrariesWithInfo:(nonnull DDABTestInfo *)info;
@end

NS_ASSUME_NONNULL_END
