//
//  JBindWayStorage.m
//  JAPP-BingWays
//
//  Created by 蔡杰 on 16/7/13.
//  Copyright © 2016年 蔡杰. All rights reserved.
//

#import "JBindWayStorage.h"

#import <objc/runtime.h>

@interface JBindWayStorage ()

@property  void *ctx;

@end

@implementation JBindWayStorage{
    
    NSMutableDictionary *_bindict;
}

+(instancetype)sharedBindWayStorageInstance{
    
    static JBindWayStorage *sharedBindWay = nil;
    static dispatch_once_t once_t;
    dispatch_once(&once_t, ^{
        sharedBindWay = [[JBindWayStorage alloc] init];
    });
    
    return sharedBindWay;
}

-(instancetype)init{
    self = [super init];
    if (self) {
        static void *ctx = &ctx;
        self.ctx = ctx;
        _bindict = [NSMutableDictionary dictionary];
    }
    return self;
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context{
    
    NSMutableDictionary *target_dict = [_bindict objectForKey:mem_address(object)];
    if (!target_dict)  return;
    
    NSPointerArray *events_arr = [target_dict objectForKey:keyPath];
    if (!events_arr) return  ;
    
    UInt16 l = (UInt16)events_arr.count;
    
    for (int i = 0; i < l; i+=2) {
        
        id target = [events_arr pointerAtIndex:i];
        NSString *key = [events_arr pointerAtIndex:i+1];
        
        if ([target valueForKey:key] != [object valueForKey:keyPath])
            [target setValue:[object valueForKey:keyPath] forKey:key];
    }
    
}

- (void)setUpFor:(id) source
             and:(id) target
         withKey:(NSString *)key_source
          andKey:(NSString *)key_target{
    
    NSString *address = mem_address(source);
    if (!key_target) {
        key_target = key_source;
    }
    
    //以观察者地址作为key 获取监听者
    NSMutableDictionary *events_dict = [_bindict objectForKey:address];
    if (!events_dict) {
        events_dict = [NSMutableDictionary dictionary];
        [_bindict setObject:events_dict forKey:address];
        [self attachToDealloc:source];
    }
    
    //观察者 有很多监听者
    NSPointerArray *events_arr = [events_dict objectForKey:key_source];
    
    if (!events_arr)
    {
        events_arr = [[NSPointerArray alloc] initWithOptions:NSPointerFunctionsWeakMemory];
        [events_dict setObject:events_arr forKey:key_source];
    }
    else
        clean_array_from_nil (events_arr);
    
    
    [events_arr addPointer:(__bridge void * _Nullable)(target)];
    [events_arr addPointer:(__bridge void * _Nullable)(key_target)];
}

- (void)attachToDealloc:(id)obj
{
    Class class = [obj class];
    
    SEL dealloc_sel = NSSelectorFromString (@"dealloc");
    Method dealloc_meth = class_getInstanceMethod (class, dealloc_sel);
    IMP dealloc_imp = method_getImplementation (dealloc_meth);
    
    IMP dealloc_imp_swizz = imp_implementationWithBlock (^(void *el) {
        @autoreleasepool
        {
            [self unbindAll:(__bridge id)el];
            ((void (*)(void *, SEL))dealloc_imp) (el, dealloc_sel);
        }
    });
    
    class_replaceMethod(class,
                        dealloc_sel,
                        dealloc_imp_swizz,
                        method_getTypeEncoding (dealloc_meth));
}
- (void)unbindAll:(id)obj
{
    NSString *address = mem_address (obj);
    NSDictionary *dict = [_bindict objectForKey:address];
    for (NSString * key in dict)
        [obj removeObserver:self forKeyPath:key context:self.ctx];
    
    [_bindict removeObjectForKey:address];
}

- (void)unbindAll:(id)obj ofProperty:(NSString *)property
{
    NSString *address = mem_address (obj);
    NSMutableDictionary *dict = [_bindict objectForKey:address];
    
    [dict removeObjectForKey:property];
    [obj removeObserver:self forKeyPath:property context:self.ctx];
}


#pragma mark --private
static inline NSString * mem_address (id o){
    return ([NSString stringWithFormat:@"%p", o]);
}
static inline void clean_array_from_nil (NSPointerArray *arr)
{
    int l = (int)arr.count - 2;
    if (l < 1) return ;
    
    for (;l > 0;l -= 2)
    {
        if ([arr pointerAtIndex:l] == nil)
        {
            [arr removePointerAtIndex:l];
            [arr removePointerAtIndex:l];
        }
    }
}



@end
