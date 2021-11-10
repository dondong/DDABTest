//
//  DDIRObjCClass.h
//  DDToolKit
//
//  Created by dondong on 2021/9/3.
//

#import "DDIRGlobalVariable.h"

NS_ASSUME_NONNULL_BEGIN

@interface DDIRObjCClassRo : DDIRGlobalVariable
@end

@interface DDIRObjCMethod : DDIRGlobalVariable
@property(nonatomic,strong,nonnull) NSString *methodName;
@property(nonatomic,strong,nonnull) NSString *functionName;
@end

@interface DDIRObjCProtocol : DDIRGlobalVariable
@property(nonatomic,strong,nonnull) NSString *protocolName;
@property(nonatomic,strong,nullable) NSArray<DDIRObjCProtocol *> *protocolList;
@property(nonatomic,strong,nullable) NSArray<DDIRObjCMethod *> *instanceMethodList;
@property(nonatomic,strong,nullable) NSArray<DDIRObjCMethod *> *classMethodList;
@property(nonatomic,strong,nullable) NSArray<DDIRObjCMethod *> *optionalInstanceMethodList;
@property(nonatomic,strong,nullable) NSArray<DDIRObjCMethod *> *optionalClassMethodList;
@end

typedef NS_ENUM(NSInteger, DDIRObjCClassType) {
    DDIRObjCClassType_Declare = 0,
    DDIRObjCClassType_Define  = 1
};

@interface DDIRObjCClass : DDIRGlobalVariable
@property(nonatomic,strong,nonnull) NSString *className;
@property(nonatomic,assign) DDIRObjCClassType type;
// Define
@property(nonatomic,strong,nullable) DDIRObjCClass *isa;
@property(nonatomic,strong,nullable) DDIRObjCClass *superObjCClass;
@property(nonatomic,strong,nullable) NSArray<DDIRObjCMethod *> *methodList;
@property(nonatomic,strong,nullable) NSArray<DDIRObjCProtocol *> *protocolList;
@end

@interface DDIRObjCCategory : DDIRGlobalVariable
@property(nonatomic,strong,nonnull) NSString *categoryName;
@property(nonatomic,strong,nonnull) DDIRObjCClass *isa;
@property(nonatomic,strong,nullable) NSArray<DDIRObjCMethod *> *instanceMethodList;
@property(nonatomic,strong,nullable) NSArray<DDIRObjCMethod *> *classMethodList;
@end

NS_ASSUME_NONNULL_END
