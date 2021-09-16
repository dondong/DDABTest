//
//  DDTestObjectA.m
//  DDTestDemo
//
//  Created by dondong on 2021/9/6.
//

#import "DDTestObjectA.h"
#import "DDTestObjectB.h"

@interface DDTestObjectA()
@property(nonatomic,strong) DDTestObjectA *aa;
@property(nonatomic,strong) DDTestObjectB *bb;
+ (void)staticMethodTestForObjectA_Category;
- (void)instanceMethodTestForObjectA_Category;
@end

@interface DDTestObjectA(Other)
+ (void)staticMethodTestForObjectA_Category_Other;
- (void)instanceMethodTestForObjectA_Category_Other;
@end

@implementation DDTestObjectA
+ (void)staticMethodTest
{
    [super staticMethodTest];
    NSLog(@"DDTestObjectA  staticMethodTest");
}

- (void)instanceMethodTest
{
    [super instanceMethodTest];
    self.aa = [[DDTestObjectA alloc] init];
    self.bb = [[DDTestObjectB alloc] init];
    NSLog(@"DDTestObjectA  instanceMethodTest");
}

+ (void)staticMethodTestForObjectA
{
    NSLog(@"DDTestObjectA  staticMethodTestForObjectA");
}

- (void)instanceMethodTestForObjectA
{
    NSLog(@"DDTestObjectA  instanceMethodTestForObjectA");
}

+ (void)staticMethodTestForObjectAProtocol
{
    NSLog(@"DDTestObjectA  staticMethodTestForObjectAProtocol");
}

- (void)instanceMethodTestForObjectAProtocol
{
    NSLog(@"DDTestObjectA  instanceMethodTestForObjectAProtocol");
}

+ (void)staticMethodTestForObjectA_Category
{
    NSLog(@"DDTestObjectA  staticMethodTestForObjectA_Category");
}

- (void)instanceMethodTestForObjectA_Category
{
    NSLog(@"DDTestObjectA  instanceMethodTestForObjectA_Category");
}
@end


@implementation DDTestObjectA(Other)
+ (void)staticMethodTestForObjectA_Category_Other
{
    NSLog(@"DDTestObjectA(Other)  staticMethodTestForObjectA_Category_Other");
}

- (void)instanceMethodTestForObjectA_Category_Other
{
    NSLog(@"DDTestObjectA(Other)  instanceMethodTestForObjectA_Category_Other");
}
@end

@implementation NSObject(ObjectA)
- (NSString *)description
{
    return @"NSObject(ObjectA) description";
}
@end
