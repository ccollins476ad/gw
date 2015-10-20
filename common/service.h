/**
 * Copyright (c) 2015 Runtime Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <Foundation/Foundation.h>
#import <IOBluetooth/IOBluetooth.h>
#import "network.h"

@class GWPeripheral;
@class GWCharacteristic;
@class CfgService;

typedef NS_ENUM(NSInteger, GWServiceState) {
    GWServiceStateSleep,
    GWServiceStateDiscoveringCharacteristics,
    GWServiceStateDiscoveredCharacteristics,
};

@interface GWService : NSObject {
};

@property CfgService *cfg;
@property CBService *cbService;
@property (readonly) NSMutableArray *characteristics;
@property GWServiceState state;
@property GWPeripheral *peripheral;

- (id) initFromCfg:(CfgService *)cfgService
        peripheral:(GWPeripheral *)peripheral;

- (GWCharacteristic *)findCharacteristicWithUuid:(CBUUID *)uuid;
- (BOOL) anyPendingResponses;
- (void) discoverCharacteristics;
- (void) reset;
- (void) stop;

- (void) onDiscoverCharacteristicsSuccess;

- (void) onDiscoverCharacteristicsFailureWithError:(NSError *)error;
@end

