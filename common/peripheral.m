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
#import "config.h"
#import "central.h"
#import "logging.h"
#import "service.h"
#import "scan.h"
#import "central.h"
#import "characteristic.h"
#import "options.h"
#import "peripheral.h"

@interface GWPeripheral (private)

- (NSArray *) undiscoveredServiceUuids;
- (BOOL) shouldBeConnected;
- (void) connect;
- (void) reset;
- (void) discoverServices;
- (void) disconnect;

@end

@implementation GWPeripheral
@synthesize cfg = _cfg;
@synthesize cbPeripheral = _cbPeripheral;
@synthesize services = _services;

/*****************************************************************************
 * Find                                                                      *
 *****************************************************************************/

- (GWService *)
findServiceWithUuid:(CBUUID *)serviceId
{
    GWService *service;
    NSUInteger numServices;
    NSUInteger i;

    numServices = _services.count;
    for (i = 0; i < numServices; i++) {
        service = [_services objectAtIndex:i];
        if ([service.cfg.uuid isEqualToString:serviceId.UUIDString]) {
            return service;
        }
    }

    return nil;
}

- (GWService *)
findServiceWithCbService:(CBService *)cbService
{
    GWService *service;
    NSUInteger numServices;
    NSUInteger i;

    assert(cbService != nil);

    numServices = _services.count;
    for (i = 0; i < numServices; i++) {
        service = [_services objectAtIndex:i];
        if (service.cbService == cbService) {
            return service;
        }
    }

    return nil;
}

/*****************************************************************************
 * Service Discovery                                                         *
 *****************************************************************************/

- (NSArray *)
serviceUuids
{
    NSMutableArray *cbUuids;
    GWService *service;
    NSUInteger numServices;
    NSUInteger i;

    cbUuids = nil;

    numServices = _services.count;
    for (i = 0; i < numServices; i++) {
        service = [_services objectAtIndex:i];
        if (cbUuids == nil) {
            cbUuids = [NSMutableArray new];
        }
        [cbUuids addObject:[CBUUID UUIDWithString:service.cfg.uuid]];
    }

    return cbUuids;
}

- (NSArray *)
undiscoveredServiceUuids
{
    NSMutableArray *cbUuids;
    GWService *service;
    NSUInteger numServices;
    NSUInteger i;

    cbUuids = [NSMutableArray new];

    numServices = _services.count;
    for (i = 0; i < numServices; i++) {
        service = [_services objectAtIndex:i];
        if (service.cbService == nil) {
            [cbUuids addObject:[CBUUID UUIDWithString:service.cfg.uuid]];
        }
    }

    return cbUuids;
}

- (void)
refreshServices
{
    GWService *gwService;
    CBService *cbService;

    for (gwService in _services) {
        [gwService reset];
    }

    for (cbService in _cbPeripheral.services) {
        logDebug(@"Discovered service: %@", cbService.UUID.UUIDString);

        gwService = [self findServiceWithUuid:cbService.UUID];
        if (gwService == nil) {
            if (optionPromiscuous) {
                gwService = [GWService new];
                [_services addObject:gwService];
            }
        }
        if (gwService != nil) {
            gwService.cbService = cbService;
        }
    }
}

- (void)
discoverServices
{
    NSArray *uuids;

    assert(_state == GWPeripheralStateConnected);
    _state = GWPeripheralStateDiscoveringServices;

    [self refreshServices];

    if (optionPromiscuous) {
        [_cbPeripheral discoverServices:nil];
    } else {
        uuids = [self undiscoveredServiceUuids];
        if (uuids.count == 0) {
            [self onDiscoverServicesSuccess];
        } else {
            logDebug(@"Discovering services: %@", uuids);
            [_cbPeripheral discoverServices:uuids];
        }
    }
}

- (void)
onDiscoverServicesSuccess
{
    NSUInteger numServices;
    NSUInteger i;
    GWService *gwService;
    NSArray *unsupportedServices;
    CBUUID *uuid;

    if (_state != GWPeripheralStateDiscoveringServices) {
        return;
    }
    _state = GWPeripheralStateDiscoveredServices;

    [self refreshServices];

    if (!optionPromiscuous) {
        /* Log unsupported services. */
        unsupportedServices = [self undiscoveredServiceUuids];
        for (uuid in unsupportedServices) {
            logNotice(@"Unsupported service: %@", uuid.UUIDString);
        }
    }

    numServices = _services.count;
    for (i = 0; i < numServices; i++) {
        gwService = [_services objectAtIndex:i];
        if (gwService.cbService != nil) {
            [gwService discoverCharacteristics];
        }
    }
}

- (void)
onDiscoverServicesFailure:(NSError *)error
{
    if (_state != GWPeripheralStateDiscoveringServices) {
        return;
    }
    _state = GWPeripheralStateConnected;

    logError(@"Error discovering services: %@", error.localizedDescription);

    /* Retry service discovery. */
    [self discoverServices];
}

/*****************************************************************************
 * Connect                                                                   *
 *****************************************************************************/

- (void)
onDiscoveredWithCb:(CBPeripheral *)cbPeripheral
{
    if (_state != GWPeripheralStateUnconnected) {
        assert(_cbPeripheral == cbPeripheral);
        return;
    }

    _cbPeripheral = cbPeripheral;
    [self connect];
}

- (BOOL)
shouldBeConnected
{
    GWService *service;
    NSUInteger numServices;
    NSUInteger i;

    if (![central isEnabled]) {
        return FALSE;
    }

    if ([_cfg.stayConnected isEqual:@YES]) {
        return TRUE;
    }

    numServices = _services.count;
    for (i = 0; i < numServices; i++) {
        service = [_services objectAtIndex:i];
        if ([service anyPendingResponses]) {
            return TRUE;
        }
    }

    return FALSE;
}

- (void)
connect
{
    assert(_state == GWPeripheralStateUnconnected);

    if ([central isEnabled]) {
        logDebug(@"Connecting to %@", _cfg.uuid);
        _state = GWPeripheralStateConnecting;
        [central connectTo:self];
    }
}

- (void)
disconnect
{
    logDebug(@"Disconnecting from %@", _cfg.uuid);
    [central disconnectFrom:self];
}

- (void)
prepareForRead
{
    if (_state == GWPeripheralStateUnconnected && [central isEnabled]) {
        if (_cbPeripheral == nil) {
            _cbPeripheral = [central findCbForPeripheral:self];
        }

        if (_cbPeripheral == nil) {
            scanStart();
        } else {
            [self connect];
        }
    }
}

- (void)
reset
{
    GWService *service;
    NSUInteger numServices;
    NSUInteger i;

    numServices = _services.count;
    for (i = 0; i < numServices; i++) {
        service = [_services objectAtIndex:i];
        [service reset];
    }
}

- (void)
stop
{
    if (_state > GWPeripheralStateUnconnected) {
        [self disconnect];
    }
    _state = GWPeripheralStateUnconnected;
    _cbPeripheral = nil;
}

- (void)
onConnectSuccess
{
    if (_state != GWPeripheralStateConnecting) {
        return;
    }

    logInfo(@"Connected to: %@", self);

    _state = GWPeripheralStateConnected;
    [self discoverServices];
}

- (void)
onConnectFailureWithError:(NSError *)error
{
    if (_state != GWPeripheralStateConnecting) { // XXX
        return;
    }

    logNotice(@"Failed to connect to peripheral: %@ with error = %@", self,
              [error localizedDescription]);

    _state = GWPeripheralStateUnconnected;
    [self reset];

    if ([self shouldBeConnected]) {
        [self connect];
    }
}

- (void)
onDisconnectWithError:(NSError *)error
{
    NSString *msg;

    msg = [@"" stringByAppendingFormat:@"Disconnected from peripheral: %@",
                                       self];
    if (error != nil) {
        msg = [msg stringByAppendingFormat:@" with error: %@", 
                                           [error localizedDescription]];
    }
    logInfo(@"%@", msg);

    _state = GWPeripheralStateUnconnected;
    [self reset];

    if ([self shouldBeConnected]) {
        [self connect];
    }
}

/*****************************************************************************
 * Misc                                                                      *
 *****************************************************************************/

- (void)
readComplete
{
    if (_state >= GWPeripheralStateConnected && ![self shouldBeConnected]) {
        [self disconnect];
    }
}

- (id)
initFromCfg:(CfgPeripheral *)cfgPeripheral
{
    GWService *gwService;

    self = [super init];
    if (self == nil) {
        return nil;
    }

    _cfg = cfgPeripheral;
    _cbPeripheral = nil;
    _services = [NSMutableArray new];

    for (CfgService *cfgService in cfgPeripheral.services) {
        gwService = [[GWService alloc]
                      initFromCfg:cfgService peripheral:self];
        [_services addObject:gwService];
    }

    return self;
}

@end
