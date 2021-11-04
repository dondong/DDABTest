//
//  DDCommonDefine.h
//  DDABTest
//
//  Created by dondong on 2021/9/17.
//

#ifndef DDCommonDefine_h
#define DDCommonDefine_h

struct dd_control {
    uint32_t module_id;
    uint32_t index;
};

struct dd_class_map_t {
    uintptr_t *cls;
    uintptr_t *super_cls;
    uintptr_t *ro;
    uintptr_t *meta_ro;
    uintptr_t *method_header;
    uintptr_t *property_header;
    uintptr_t *protocol_header;
    uintptr_t *meta_method_header;
    uintptr_t *meta_property_header;
    uintptr_t *meta_protocol_header;
};

struct dd_class_map_list_t {
    uint32_t module_id;
    uint32_t index;
    uint32_t count;
    struct dd_class_map_t map[];
};

struct dd_category_map_t {
    uintptr_t *cls;
    uintptr_t *category;
    uintptr_t *instance_method_header;
    uintptr_t *class_method_header;
    uintptr_t *protocol_header;
    uintptr_t *instace_property_header;
    uintptr_t *class_property_header;
};

struct dd_category_map_list_t {
    uint32_t module_id;
    uint32_t index;
    uint32_t count;
    struct dd_category_map_t map[];
};

// configuration key
#define DDConfigModuleNameKey    @"module_name"
#define DDConfigModuleIdKey      @"module_id"
#define DDConfigComponentsKey    @"components"
#define DDConfigTagKey           @"tag"
#define DDConfigIndexKey         @"index"

// macho
#define DDDefaultClsMapSection   @"__dddd_clsmap"
#define DDDefaultCatMapSection   @"__dddd_catmap"
#define DDControlSection @"__dddd_control"

#endif /* DDCommonDefine_h */
