#import <React/RCTBridgeModule.h>

// Same empty-`moduleName` bug as view managers unless the JS module name is explicit.
@interface RCT_EXTERN_REMAP_MODULE(SimulaAdSDK, SimulaAdSDK, NSObject)

RCT_EXTERN_METHOD(configure:(NSString *)apiKey
                  devMode:(BOOL)devMode
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(bootstrapSession:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(loadCatalog:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

@end
