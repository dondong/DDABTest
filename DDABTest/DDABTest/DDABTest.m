//
//  DDABTest.m
//  DDABTest
//
//  Created by dondong on 2021/9/13.
//

#import "DDABTest.h"
#import <DDMemoryKit/dd_memory_kit.h>

@implementation DDABTest
+ (void)load
{
    NSArray *settings = [NSArray arrayWithContentsOfFile:@""];
    NSDictionary *configs = [NSDictionary dictionaryWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"" ofType:@"plist"]];
    NSMutableDictionary *classDic = [NSMutableDictionary dictionary];
    struct dd_macho *macho = dd_copy_macho_at_index(0);
    for (int i = 0; i < macho->msegments; ++i) {
        struct dd_macho_segment segment = macho->segments[i];
        if (strcmp(segment.seg_name, "__DATA")) {
            for (int j = 0; j < segment.msections; ++j) {
                if (strcmp(segment.sections[j].sect_name, "__objc_classlist") ||
                    strcmp(segment.sections[j].sect_name, "__ddobjcclass")) {
                    uintptr_t *bast_ptr = (uintptr_t *)segment.sections[j].addr;
                    int class_count = (int)segment.sections[j].size / sizeof(uintptr_t);
                    for (int k = 0; k < class_count; ++k) {
                        char *class_ptr = (char *)*(bast_ptr + k);
                        NSString *name = [NSString stringWithCString:_getClassName(class_ptr) encoding:NSUTF8StringEncoding];
                        [classDic setObject:[NSValue valueWithPointer:class_ptr] forKey:name];
                    }
                }
            }
            break;
        }
    }
    dd_delete_macho(macho);
    for (NSArray *s in settings) {
        for (NSDictionary<NSString *, NSString *> *c in configs[s][@"objc_class"]) {
            char *dstClass = [classDic[c[@"dst"]] pointerValue];
            char *srcClass = [classDic[c[@"src"]] pointerValue];
            if (NULL != dstClass && NULL != srcClass) {
                _copyClass(srcClass, dstClass);
            }
            
        }
    }
    
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

static const char *_getClassName(char *classPtr)
{
    struct objc_class_t *ptr = (struct objc_class_t *)classPtr;
    struct class_ro_t *roPtr = (struct class_ro_t *)(ptr->data & FAST_DATA_MASK);
    return roPtr->name;
}

static bool _copyClass(char *srcClassPtr, char *dstClassPtr)
{
    const char *name = _getClassName(dstClassPtr);
    struct objc_class_t *srcPtr = (struct objc_class_t *)srcClassPtr;
    struct objc_class_t *dstPtr = (struct objc_class_t *)dstClassPtr;
    struct class_ro_t *srcRoPtr = (struct class_ro_t *)(srcPtr->data & FAST_DATA_MASK);
    struct class_ro_t *dstRoPtr = (struct class_ro_t *)(dstPtr->data & FAST_DATA_MASK);
    memcpy(dstRoPtr, srcRoPtr, sizeof(struct class_ro_t));
    dstRoPtr->name = name;
    // metal
    struct objc_class_t *srcMetalPtr = (struct objc_class_t *)srcPtr->isa;
    struct objc_class_t *dstMetalPtr = (struct objc_class_t *)dstPtr->isa;
    struct class_ro_t *srcMetalRoPtr = (struct class_ro_t *)(srcMetalPtr->data & FAST_DATA_MASK);
    struct class_ro_t *dstMetalRoPtr = (struct class_ro_t *)(dstMetalPtr->data & FAST_DATA_MASK);
    memcpy(dstMetalRoPtr, srcMetalRoPtr, sizeof(struct class_ro_t));
    dstMetalRoPtr->name = name;
    return true;
}
@end
