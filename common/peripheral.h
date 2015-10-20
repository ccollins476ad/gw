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

#import "network.h"

@class GWService;
@class CfgPeripheral;
@class CBPeripheral;
@class CBService;
@class CBUUID;

typedef NS_ENUM(NSInteger, GWPeripheralState) {
    GWPeripheralStateUnconnected,
    GWPeripheralStateConnecting,
    GWPeripheralStateConnected,
    GWPeripheralStateDiscoveringServices,
    GWPeripheralStateDiscoveredServices,
};

@interface GWPeripheral : NSObject

@property CfgPeripheral *cfg;
@property CBPeripheral *cbPeripheral;
@property GWPeripheralState state;
@property (readonly) NSMutableArray *services;

- (id) initFromCfg:(CfgPeripheral *)cfgPeripheral;
- (GWService *) findServiceWithUuid:(CBUUID *)serviceId;
- (GWService *) findServiceWithCbService:(CBService *)cbService;
- (void) prepareForRead;
- (NSArray *) serviceUuids;
- (void) stop;

- (void) readComplete;
- (void) onDiscoveredWithCb:(CBPeripheral *)cbPeripheral;
- (void) onConnectSuccess;
- (void) onConnectFailureWithError:(NSError *)error;
- (void) onDisconnectWithError:(NSError *)error;
- (void) onDiscoverServicesSuccess;
- (void) onDiscoverServicesFailure:(NSError *)error;
@end
