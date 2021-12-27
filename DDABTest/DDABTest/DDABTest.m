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
    
    struct category_t **catList = NULL;
    int categoryCount = 0;
    for (int i = 0; i < macho->msegments; ++i) {
        struct dd_macho_segment segment = macho->segments[i];
        if (0 == strcmp(segment.seg_name, "__DATA") ||
            0 == strcmp(segment.seg_name, "__DATA_CONST")) {
            for (int j = 0; j < segment.msections; ++j) {
                if (0 == strcmp(segment.sections[j].sect_name, "__objc_catlist")) {
                    catList = (struct category_t **)segment.sections[j].addr;
                    categoryCount = (int)segment.sections[j].size / sizeof(struct category_t *);
                }
            }
        }
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
                } else if (0 == strcmp(segment.sections[j].sect_name, [DDDefaultCatMapSection cStringUsingEncoding:NSUTF8StringEncoding])) {
                    uintptr_t *bast_ptr = (uintptr_t *)segment.sections[j].addr;
                    int map_count = (int)segment.sections[j].size / sizeof(uintptr_t);
                    for (int k = 0; k < map_count; ++k) {
                        struct dd_category_map_list_t *map_ptr = (struct dd_category_map_list_t *)(char *)*(bast_ptr + k);
                        NSNumber *val = [dic objectForKey:@(map_ptr->module_id)];
                        if (nil != val && [val integerValue] == map_ptr->index) {
                            _updateCategory(map_ptr, catList, categoryCount);
                        }
                    }
                } else if (0 == strcmp(segment.sections[j].sect_name, [DDInitFunctionSection cStringUsingEncoding:NSUTF8StringEncoding])) {
                    uintptr_t *bast_ptr = (uintptr_t *)segment.sections[j].addr;
                    int func_count = (int)segment.sections[j].size / sizeof(uintptr_t);
                    for (int k = 0; k < func_count; ++k) {
                        typedef void *(my_func)(void);
                        my_func* fun_ptr = (my_func *)(char *)*(bast_ptr + k);
                        fun_ptr();
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

struct protocol_list_t {
    uint64_t count;
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
    struct protocol_list_t * baseProtocols;
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
        struct class_ro_t *ro = NULL;
        struct class_rw_t *rw = (struct class_rw_t *)(cls->data & FAST_DATA_MASK);
        if ((rw->flags & RW_REALIZED) > 0) {
            assert("Unkown case! The class should not be realized");
        } else {
            ro = (struct class_ro_t *)rw;
        }
        struct objc_class_t *metaCls = (struct objc_class_t *)cls->isa;
        struct class_ro_t *metaRo = NULL;
        struct class_rw_t *metaRw = (struct class_rw_t *)(metaCls->data & FAST_DATA_MASK);
        if ((metaRw->flags & RW_REALIZED) > 0) {
            assert("Unkown case! The class should not be realized");
        } else {
            metaRo = (struct class_ro_t *)metaRw;
        }
        cls->superclass = (uintptr_t *)superCls;
        ((struct objc_class_t *)cls->isa)->superclass = superCls->isa;
        _updateClassRo((struct class_ro_t *)map->ro,
                       ro,
                       map->method_header,
                       map->property_header,
                       map->protocol_header);
        _updateClassRo((struct class_ro_t *)map->meta_ro,
                       metaRo,
                       map->meta_method_header,
                       map->meta_property_header,
                       map->meta_protocol_header);
    }
}

// ensize should use src. when the class is realized, the flag may set to entsizeAndFlags
static void _updateClassRo(struct class_ro_t *srcRo, struct class_ro_t *dstRo, uintptr_t *methodHeader, uintptr_t *propertyHeader, uintptr_t *protocolHeader)
{
    dstRo->flags = srcRo->flags;
    dstRo->instanceStart = srcRo->instanceStart;
    dstRo->instacneSize  = srcRo->instacneSize;
    dstRo->reserved      = srcRo->reserved;
    dstRo->ivarLayout     = srcRo->ivarLayout;
    dstRo->weakIvarLayout = srcRo->weakIvarLayout;
    dstRo->ivars          = srcRo->ivars;
    if (NULL != dstRo->baseMethodList && NULL != srcRo->baseMethodList) {
        uintptr_t dstPtr = (uintptr_t)&dstRo->baseMethodList->first;
        for (int i = 0; i <= dstRo->baseMethodList->count - srcRo->baseMethodList->count; ++i) {
            if (*(void **)dstPtr == methodHeader) {
                void *srcPtr = (void *)&srcRo->baseMethodList->first;
                memcpy((void *)dstPtr, srcPtr, srcRo->baseMethodList->count * srcRo->baseMethodList->entsizeAndFlags);
                break;
            }
            dstPtr += srcRo->baseMethodList->entsizeAndFlags;
        }
    }
    if (NULL != dstRo->baseProperties && NULL != srcRo->baseProperties) {
        uintptr_t dstPtr = (uintptr_t)&dstRo->baseProperties->first;
        for (int i = 0; i <= dstRo->baseProperties->count - srcRo->baseProperties->count; ++i) {
            if (*(void **)dstPtr == propertyHeader) {
                void *srcPtr = (void *)&srcRo->baseProperties->first;
                memcpy((void *)dstPtr, srcPtr, srcRo->baseProperties->count * sizeof(void *));
                break;
            }
            dstPtr += dstRo->baseProperties->entsizeAndFlags / sizeof(void *);
        }
    }
    if (NULL != dstRo->baseProtocols && NULL != srcRo->baseProtocols) {
        void *dstPtr = (void *)&dstRo->baseProtocols->first;
        for (int i = 0; i <= dstRo->baseProtocols->count - srcRo->baseProtocols->count; ++i) {
            if (dstPtr == protocolHeader) {
                void *srcPtr = (void *)&srcRo->baseProtocols->first;
                memcpy(dstPtr, srcPtr, srcRo->baseProtocols->count * sizeof(void *));
                break;
            }
            dstPtr += sizeof(void *);
        }
    }
}

struct category_t {
    const char *name;
    uintptr_t *cls;
    struct entsize_list_tt *instanceMethods;
    struct entsize_list_tt *classMethods;
    struct protocol_list_t *protocols;
    struct entsize_list_tt *instanceProperties;
    struct entsize_list_tt *_classProperties;
};

static void _updateCategory(struct dd_category_map_list_t *list, struct category_t **catList, int catCount)
{
    for (int i = 0; i < list->count; ++i) {
        bool ishit = false;
        struct dd_category_map_t *map = &list->map[i];
        struct category_t *category = (struct category_t *)map->category;
        for (int j = 0; j < catCount; ++j) {
            if (catList[j]->cls == map->cls) {
                if (NULL != catList[j]->instanceMethods && NULL != category->instanceMethods) {
                    uintptr_t dstPtr = (uintptr_t)&catList[j]->instanceMethods->first;
                    for (int i = 0; i <= catList[j]->instanceMethods->count - category->instanceMethods->count; ++i) {
                        if (*(void **)dstPtr == map->instance_method_header || 0 == strcmp(*(char **)dstPtr, (char *)map->instance_method_header)) {
                            void *srcPtr = (void *)&category->instanceMethods->first;
                            memcpy((void *)dstPtr, srcPtr, category->instanceMethods->count * category->instanceMethods->entsizeAndFlags);
                            ishit = true;
                            break;
                        }
                        dstPtr += category->instanceMethods->entsizeAndFlags;
                    }
                }
                if (NULL != catList[j]->classMethods && NULL != category->classMethods) {
                    uintptr_t dstPtr = (uintptr_t)&catList[j]->classMethods->first;
                    for (int i = 0; i <= catList[j]->classMethods->count - category->classMethods->count; ++i) {
                        if (*(void **)dstPtr == map->class_method_header || 0 == strcmp(*(char **)dstPtr, (char *)map->class_method_header)) {
                            void *srcPtr = (void *)&category->classMethods->first;
                            memcpy((void *)dstPtr, srcPtr, category->classMethods->count * category->classMethods->entsizeAndFlags);
                            ishit = true;
                            break;
                        }
                        dstPtr += category->classMethods->entsizeAndFlags;
                    }
                }
                if (NULL != catList[j]->protocols && NULL != category->protocols) {
                    uintptr_t dstPtr = (uintptr_t)&catList[j]->protocols->first;
                    for (int i = 0; i <= catList[j]->protocols->count - category->protocols->count; ++i) {
                        if (*(void **)dstPtr == map->protocol_header) {
                            void *srcPtr = (void *)&category->protocols->first;
                            memcpy((void *)dstPtr, srcPtr, category->protocols->count * sizeof(void *));
                            ishit = true;
                            break;
                        }
                        dstPtr += sizeof(void *);
                    }
                }
                if (NULL != catList[j]->instanceProperties && NULL != category->instanceProperties) {
                    uintptr_t dstPtr = (uintptr_t)&catList[j]->instanceProperties->first;
                    for (int i = 0; i <= catList[j]->instanceProperties->count - category->instanceProperties->count; ++i) {
                        if (*(void **)dstPtr == map->instace_property_header) {
                            void *srcPtr = (void *)&category->instanceProperties->first;
                            memcpy((void *)dstPtr, srcPtr, category->instanceProperties->count * category->instanceProperties->entsizeAndFlags);
                            ishit = true;
                            break;
                        }
                        dstPtr += category->instanceProperties->entsizeAndFlags;
                    }
                }
                if (NULL != catList[j]->_classProperties && NULL != category->_classProperties) {
                    uintptr_t dstPtr = (uintptr_t)&catList[j]->_classProperties->first;
                    for (int i = 0; i <= catList[j]->_classProperties->count - category->_classProperties->count; ++i) {
                        if (*(void **)dstPtr == map->class_property_header) {
                            void *srcPtr = (void *)&category->_classProperties->first;
                            memcpy((void *)dstPtr, srcPtr, category->_classProperties->count * category->_classProperties->entsizeAndFlags);
                            ishit = true;
                            break;
                        }
                        dstPtr += category->_classProperties->entsizeAndFlags;
                    }
                }
            }
            if (true == ishit) {
                break;
            }
        }
    }
}
@end
