//
//  DDTestDefine.h
//  DDTestDemo
//
//  Created by dondong on 2021/9/22.
//

#ifndef DDTestDefine_h
#define DDTestDefine_h

#if DemoTarget==1
#define DemoName @"Demo A"
#else
#define DemoName @"Demo B"
#endif

#define DDLog(fmt, ...) NSLog((@"%@: " fmt), DemoName, ##__VA_ARGS__);

#endif /* DDTestDefine_h */
