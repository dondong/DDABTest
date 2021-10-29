//
//  DDCommonDefine.h
//  DDABTest
//
//  Created by dondong on 2021/9/17.
//

#ifndef DDCommonDefine_h
#define DDCommonDefine_h

struct dd_class_map_t {
    uintptr_t *cls;
    uintptr_t *super_cls;
    uintptr_t *ro;
    uintptr_t *meta_ro;
};

struct dd_class_map_list_t {
    uint32_t module_id;
    uint32_t index;
    uint32_t count;
    struct dd_class_map_t map[];
};
// configuration key
#define DDConfigModuleNameKey    @"module_name"
#define DDConfigTagKey           @"tag"
// module key
#define DDModuleClassSectionKey    @"cls_section"
#define DDModuleCategorySectionKey @"cat_section"
#define DDModuleClassKey           @"objc_class"
#define DDModuleCategoryKey        @"objc_category"
// item key
#define DDItemDstKey @"dst"
#define DDItemSrcKey @"src"

// macho
#define DDDefaultCategorySection @"__dddd_clslist"
#define DDDefaultClassSection    @"__dddd_clslist"
#define DDDefaultClsMapSection   @"__dddd_clsmap"
#define DDControlSection @"__dddd_control"

#endif /* DDCommonDefine_h */
