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
    struct dd_macho *macho = NULL;
    int index = 0;
    for (int i = 0; i < _dyld_image_count(); ++i) {
        NSString *name = [NSString stringWithFormat:@"%s", _dyld_get_image_name(i)];
        if ([[name stringByDeletingLastPathComponent] hasSuffix:@".app"]) {
            macho = dd_copy_macho_at_index(i);
            index = i;
            break;
        }
    }
    if (NULL == macho) {
        return;
    }
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    NSArray *settings = [NSArray arrayWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"DDABTestSettings" ofType:@"plist"]];
    for (NSDictionary *d in settings) {
        NSNumber *val = [d objectForKey:DDConfigIndexKey];
        NSNumber *key = [d objectForKey:DDConfigModuleIdKey];
        if (nil == val || nil == key) {
            // error, disable settings
            return;
        }
        [dic setObject:val forKey:key];
    }
    for (int i = 0; i < macho->msegments; ++i) {
        struct dd_macho_segment segment = macho->segments[i];
        if (0 == strcmp(segment.seg_name, "__DATA")) {
            for (int j = 0; j < segment.msections; ++j) {
                if (0 == strcmp(segment.sections[j].sect_name, [DDControlSection cStringUsingEncoding:NSUTF8StringEncoding])) {
                    struct dd_control *bast_ptr = (struct dd_control *)segment.sections[j].addr;
                    int count = (int)segment.sections[j].size / sizeof(struct dd_control);
                    for (int k = 0; k < count; ++k) {
                        NSNumber *val = [dic objectForKey:@(bast_ptr[k].module_id)];
                        if (nil != val) {
                            bast_ptr[k].index = (uint32_t)[val integerValue];
                        }
                    }
                    
                } else if (0 == strcmp(segment.sections[j].sect_name, [DDDefaultClsMapSection cStringUsingEncoding:NSUTF8StringEncoding])) {
                    uintptr_t *bast_ptr = (uintptr_t *)segment.sections[j].addr;
                    int map_count = (int)segment.sections[j].size / sizeof(uintptr_t);
                    for (int k = 0; k < map_count; ++k) {
                        struct dd_class_map_list_t *map_ptr = (struct dd_class_map_list_t *)(char *)*(bast_ptr + k);
                        NSNumber *val = [dic objectForKey:@(map_ptr->module_id)];
                        if (nil != val && [val integerValue] == map_ptr->index) {
                            _updateClass(map_ptr);
                        }
                    }
                }
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
static void _updateClass(struct dd_class_map_list_t *list)
{
    for (int i = 0; i < list->count; ++i) {
        struct dd_class_map_t *map = &list->map[i];
        struct objc_class_t *cls = (struct objc_class_t *)map->cls;
        struct objc_class_t *superCls = (struct objc_class_t *)map->super_cls;
        struct class_ro_t *ro = (struct class_ro_t *)map->ro;
        struct class_ro_t *metaRo = (struct class_ro_t *)map->meta_ro;
        cls->data = (uintptr_t)ro;
        ((struct objc_class_t *)cls->isa)->data = (uintptr_t)metaRo;
        cls->superclass = (uintptr_t *)superCls;
        ((struct objc_class_t *)cls->isa)->superclass = superCls->isa;
    }
}
@end
