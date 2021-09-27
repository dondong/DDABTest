//
//  DDABTest.m
//  DDABTest
//
//  Created by dondong on 2021/9/13.
//

#import "DDABTest.h"
#import "DDCommonDefine.h"
#import <DDMemoryKit/dd_memory_kit.h>
#include <mach-o/dyld.h>
#include <objc/runtime.h>

@implementation DDABTest
+ (void)load
{
    NSArray *settings = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DDABTestSettings" ofType:@"plist"]];
    NSDictionary *configs = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DDABTestConfiguration" ofType:@"plist"]];
    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSValue *> *> *classDic    = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSMutableDictionary<NSString *, NSValue *> *> *categoryDic = [NSMutableDictionary dictionary];
    
    struct dd_macho *macho = NULL;
    for (int i = 0; i < _dyld_image_count(); ++i) {
        NSString *name = [NSString stringWithFormat:@"%s", _dyld_get_image_name(i)];
        if ([[name stringByDeletingLastPathComponent] hasSuffix:@".app"]) {
            macho = dd_copy_macho_at_index(i);
            break;
        }
    }
    if (NULL == macho) {
        return;
    }
    for (NSDictionary *dic in settings) {
        NSString *clsSection = configs[dic[DDConfigModuleNameKey]][dic[DDConfigTagKey]][DDModuleClassSectionKey];
        NSString *catSection = configs[dic[DDConfigModuleNameKey]][dic[DDConfigTagKey]][DDModuleCategorySectionKey];
        if (nil == clsSection && nil == catSection) {
            continue;
        }
        for (int i = 0; i < macho->msegments; ++i) {
            struct dd_macho_segment segment = macho->segments[i];
            if (0 == strcmp(segment.seg_name, "__DATA_CONST") ||
                0 == strcmp(segment.seg_name, "__DATA")) {
                for (int j = 0; j < segment.msections; ++j) {
                    // class
                    if (0 == strcmp(segment.sections[j].sect_name, "__objc_classlist") ||
                        0 == strcmp(segment.sections[j].sect_name, [clsSection cStringUsingEncoding:NSUTF8StringEncoding])) {
                        uintptr_t *bast_ptr = (uintptr_t *)segment.sections[j].addr;
                        int class_count = (int)segment.sections[j].size / sizeof(uintptr_t);
                        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:class_count];
                        [classDic setObject:d forKey:[NSString stringWithCString:segment.sections[j].sect_name encoding:NSUTF8StringEncoding]];
                        for (int k = 0; k < class_count; ++k) {
                            char *class_ptr = (char *)*(bast_ptr + k);
                            NSString *name = [NSString stringWithCString:_getClassName(class_ptr) encoding:NSUTF8StringEncoding];
                            if (nil != name) {
                                [d setObject:[NSValue valueWithPointer:class_ptr] forKey:name];
                            }
                        }
                    }
                    // category
                    if (0 == strcmp(segment.sections[j].sect_name, "__objc_catlist") ||
                        0 == strcmp(segment.sections[j].sect_name, [catSection cStringUsingEncoding:NSUTF8StringEncoding])) {
                        uintptr_t *bast_ptr = (uintptr_t *)segment.sections[j].addr;
                        int category_count = (int)segment.sections[j].size / sizeof(uintptr_t);
                        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:category_count];
                        [categoryDic setObject:d forKey:[NSString stringWithCString:segment.sections[j].sect_name encoding:NSUTF8StringEncoding]];
                        for (int k = 0; k < category_count; ++k) {
                            char *cat_ptr = (char *)*(bast_ptr + k);
                            NSString *name = [NSString stringWithFormat:@"%s(%s)", _getCategoryClassName(cat_ptr), _getCategoryName(cat_ptr)];
                            [d setObject:[NSValue valueWithPointer:cat_ptr] forKey:name];
                        }
                    }
                }
            }
        }
        for (NSDictionary<NSString *, NSString *> *c in configs[dic[DDConfigModuleNameKey]][dic[DDConfigTagKey]][DDModuleClassKey]) {
            char *dstClass = [classDic[@"__objc_classlist"][c[DDItemDstKey]] pointerValue];
            char *srcClass = [classDic[clsSection][c[DDItemSrcKey]] pointerValue];
            if (NULL != dstClass && NULL != srcClass) {
                _copyClass(srcClass, dstClass);
            }
        }
        return;
        for (NSDictionary<NSString *, NSString *> *c in configs[dic[DDConfigModuleNameKey]][dic[DDConfigTagKey]][DDModuleCategoryKey]) {
            char *dstCategory = [categoryDic[@"__objc_catlist"][c[DDItemDstKey]] pointerValue];
            char *srcCategory = [categoryDic[catSection][c[DDItemSrcKey]] pointerValue];
            if (NULL != dstCategory && NULL != srcCategory) {
                _copyCategory(srcCategory, dstCategory);
            }
        }
    }
    dd_delete_macho(macho);
}

struct cache_t {
    uint64_t _maskAndBuckets;
    uint32_t _mask_unused;
    uint16_t _flags;
    uint16_t _occupied;
};

#define FAST_DATA_MASK 0x00007ffffffffff8UL
struct objc_class_t {
    uintptr_t *isa;
    uintptr_t *superclass;
    struct cache_t    cache;
    uintptr_t  data;
};

struct entsize_list_tt {
    uint32_t entsizeAndFlags;
    uint32_t count;
    uintptr_t first;
};

struct class_ro_t {
    uint32_t flags;
    uint32_t instanceStart;
    uint32_t instacneSize;
    uint32_t reserved;
    const uint8_t *ivarLayout;
    const char *name;
    struct entsize_list_tt * baseMethodList;
    uintptr_t * baseProtocols;
    struct entsize_list_tt * ivars;
    uintptr_t * weakIvarLayout;
    struct entsize_list_tt * baseProperties;
};

struct class_rw_t {
    uint32_t flags;
    uint32_t version;
    struct class_ro_t *ro;
};

#define RW_REALIZED           (1<<31)
static const char *_getClassName(char *classPtr)
{
//    struct objc_class_t *ptr = (struct objc_class_t *)classPtr;
//    struct class_rw_t *rwPtr = (struct class_ro_t *)(ptr->data & FAST_DATA_MASK);
//    struct class_ro_t *roPtr = NULL;
//    if (0 != (RW_REALIZED & rwPtr->flags)) {
//        roPtr = rwPtr->ro;
//    } else {
//        roPtr = (struct class_ro_t *)rwPtr;
//    }
//    return roPtr->name;
    return class_getName((__bridge Class)(void *)classPtr);
}

static bool _copyClass(char *srcClassPtr, char *dstClassPtr)
{
//    const char *name = _getClassName(dstClassPtr);
    struct objc_class_t *srcPtr = (struct objc_class_t *)srcClassPtr;
    struct objc_class_t *dstPtr = (struct objc_class_t *)dstClassPtr;
    struct class_ro_t *srcRoPtr = (struct class_ro_t *)(srcPtr->data & FAST_DATA_MASK);
    struct class_ro_t *dstRoPtr = (struct class_ro_t *)(dstPtr->data & FAST_DATA_MASK);
    memcpy(dstRoPtr, srcRoPtr, sizeof(struct class_ro_t));
//    dstRoPtr->name = name;
    // metal
    struct objc_class_t *srcMetalPtr = (struct objc_class_t *)srcPtr->isa;
    struct objc_class_t *dstMetalPtr = (struct objc_class_t *)dstPtr->isa;
    struct class_ro_t *srcMetalRoPtr = (struct class_ro_t *)(srcMetalPtr->data & FAST_DATA_MASK);
    struct class_ro_t *dstMetalRoPtr = (struct class_ro_t *)(dstMetalPtr->data & FAST_DATA_MASK);
    memcpy(dstMetalRoPtr, srcMetalRoPtr, sizeof(struct class_ro_t));
//    dstMetalRoPtr->name = name;
    return true;
}

struct category_t {
    const char *name;
    uintptr_t *cls;
    struct entsize_list_tt *instanceMethods;
    struct entsize_list_tt *classMethods;
    uintptr_t *protocols;
    uintptr_t *instanceProperties;
    // Fields below this point are not always present on disk.
    struct entsize_list_tt *_classProperties;
};

static const char *_getCategoryClassName(char *categoryPtr)
{
    struct category_t *ptr = (struct category_t *)categoryPtr;
    return _getClassName((char *)ptr->cls);
}

static const char *_getCategoryName(char *categoryPtr)
{
    struct category_t *ptr = (struct category_t *)categoryPtr;
    for (int i = 0; i < ptr->instanceMethods->count; ++i) {
        uintptr_t v = (uintptr_t)(ptr->instanceMethods);
        char *n = *(char **)(v + 8 + i * 24);
        NSLog(@"Mehtod: %s  %s", ptr->name, n);
    }
    return ptr->name;
}

static bool _copyCategory(char *srcCategoryPtr, char *dstCategoryPtr)
{
    memcpy(dstCategoryPtr, srcCategoryPtr, sizeof(struct category_t));
    return true;
}

@end
