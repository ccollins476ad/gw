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
#import "logging.h"
#import "service.h"
#import "peripheral.h"
#import "options.h"
#import "characteristic.h"

@interface GWService (private)

- (NSArray *) characteristicUuids;

@end

@implementation GWService
@synthesize cfg = _cfg;
@synthesize cbService = _cbService;
@synthesize characteristics = _characteristics;
@synthesize state = _state;
@synthesize peripheral = _peripheral;

/*****************************************************************************
 * Find                                                                      *
 *****************************************************************************/

- (GWCharacteristic *)
findCharacteristicWithUuid:(CBUUID *)uuid
{
    GWCharacteristic *characteristic;
    NSUInteger numCharacteristics;
    NSUInteger i;

    numCharacteristics = _characteristics.count;
    for (i = 0; i < numCharacteristics; i++) {
        characteristic = [_characteristics objectAtIndex:i];
        if ([characteristic.cfg.uuid isEqualToString:uuid.UUIDString]) {
            return characteristic;
        }
    }

    return nil;
}

/*****************************************************************************
 * Characteristic Discovery                                                  *
 *****************************************************************************/

- (NSArray *)
characteristicUuids
{
    GWCharacteristic *characteristic;
    NSMutableArray *cbUuids;
    NSUInteger numCharacteristics;
    NSUInteger i;

    cbUuids = [NSMutableArray new];

    numCharacteristics = _characteristics.count;
    for (i = 0; i < numCharacteristics; i++) {
        characteristic = [_characteristics objectAtIndex:i];
        [cbUuids addObject:[CBUUID UUIDWithString:characteristic.cfg.uuid]];
    }

    return cbUuids;
}

- (NSArray *)
undiscoveredCharacteristicUuids
{
    GWCharacteristic *characteristic;
    NSMutableArray *cbUuids;
    NSUInteger numCharacteristics;
    NSUInteger i;

    cbUuids = [NSMutableArray new];

    numCharacteristics = _characteristics.count;
    for (i = 0; i < numCharacteristics; i++) {
        characteristic = [_characteristics objectAtIndex:i];
        if (characteristic.cbCharacteristic == nil) {
            [cbUuids
                addObject:[CBUUID UUIDWithString:characteristic.cfg.uuid]];
        }
    }

    return cbUuids;
}

- (void)
refreshCharacteristics
{
    GWCharacteristic *gwCharacteristic;
    CBCharacteristic *cbCharacteristic;
    CBUUID *uuid;

    for (gwCharacteristic in _characteristics) {
        [gwCharacteristic reset];
    }

    for (cbCharacteristic in _cbService.characteristics) {
        uuid = cbCharacteristic.UUID;
        logDebug(@"Discovered characteristic: %@", uuid.UUIDString);

        gwCharacteristic = [self findCharacteristicWithUuid:uuid];
        if (gwCharacteristic == nil) {
            if (optionPromiscuous) {
                gwCharacteristic = [GWCharacteristic new];
                [_characteristics addObject:gwCharacteristic];
            }
        }
        if (gwCharacteristic != nil) {
            gwCharacteristic.cbCharacteristic = cbCharacteristic;
        }
    }
}

- (void)
discoverCharacteristics
{
    NSArray *uuids;

    logDebug(@"discovering characteristics for service %@",
             _cbService.UUID.UUIDString);

    assert(_state == GWServiceStateSleep);
    _state = GWServiceStateDiscoveringCharacteristics;

    [self refreshCharacteristics];

    if (optionPromiscuous) {
        [_peripheral.cbPeripheral discoverCharacteristics:nil
                                               forService:_cbService];
    } else {
        uuids = [self undiscoveredCharacteristicUuids];
        if (uuids.count == 0) {
            [self onDiscoverCharacteristicsSuccess];
        } else {
            [_peripheral.cbPeripheral discoverCharacteristics:uuids
                                                   forService:_cbService];
        }
    }
}

- (void)
onDiscoverCharacteristicsSuccess
{
    GWCharacteristic *gwCharacteristic;
    BOOL anySupported;

    if (_state != GWServiceStateDiscoveringCharacteristics) {
        return;
    }

    [self refreshCharacteristics];

    /* Log unsupported characteristics. */
    anySupported = FALSE;
    for (gwCharacteristic in _characteristics) {
        if (gwCharacteristic.cbCharacteristic == nil) {
            if (!optionPromiscuous) {
                logNotice(@"Unsupported characteristic: %@",
                          gwCharacteristic.cfg.uuid);
            }
        } else {
            anySupported = true;
            if (optionNetworkActive) {
                [gwCharacteristic wakeUp];
            }
        }
    }

    if (!anySupported) {
        logNotice(@"No supported characteristics for periph=%@ service=%@",
                  _peripheral.cfg.uuid, _cfg.uuid);
    }

    _state = GWServiceStateDiscoveredCharacteristics;
}

- (void)
onDiscoverCharacteristicsFailureWithError:(NSError *)error
{
    if (_state != GWServiceStateDiscoveringCharacteristics) {
        return;
    }

    logError(@"Error discovering characteristics: %@",
             error.localizedDescription);

    /* Retry characteristic discovery. */
    [self discoverCharacteristics];
}

/*****************************************************************************
 * Misc                                                                      *
 *****************************************************************************/

- (BOOL)
anyPendingResponses
{
    GWCharacteristic *characteristic;
    NSUInteger numCharacteristics;
    NSUInteger i;

    numCharacteristics = _characteristics.count;
    for (i = 0; i < numCharacteristics; i++) {
        characteristic = [_characteristics objectAtIndex:i];
        if (characteristic.state == GWCharacteristicStatePending ||
            characteristic.state == GWCharacteristicStateSent) {

            return TRUE;
        }
    }

    return FALSE;
}

- (void)
reset
{
    GWCharacteristic *characteristic;
    NSUInteger numCharacteristics;
    NSUInteger i;

    /* XXX: Cancel characteristic discovery. */

    _cbService = nil;
    _state = GWServiceStateSleep;

    numCharacteristics = _characteristics.count;
    for (i = 0; i < numCharacteristics; i++) {
        characteristic = [_characteristics objectAtIndex:i];
        [characteristic reset];
    }
}

- (void)
stop
{
    GWCharacteristic *characteristic;

    for (characteristic in _characteristics) {
        [characteristic stop];
    }
}

- (id)
initFromCfg:(CfgService *)cfgService
    peripheral:(GWPeripheral *)peripheral
{
    GWCharacteristic *gwCharacteristic;

    self = [super init];
    if (self == nil) {
        return nil;
    }

    _cfg = cfgService;
    _cbService = nil;
    _peripheral = peripheral;
    _characteristics = [NSMutableArray new];
    _state = GWServiceStateSleep;

    for (CfgCharacteristic *cfgCharacteristic in cfgService.characteristics) {
        gwCharacteristic =
            [[GWCharacteristic alloc]
             initFromCfg:cfgCharacteristic
              peripheral:peripheral
                 service:self];

        [_characteristics addObject:gwCharacteristic];
    }

    return self;
}

@end
