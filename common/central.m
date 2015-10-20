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
#import "scan.h"
#import "network.h"
#import "central.h"
#import "peripheral.h"
#import "service.h"
#import "characteristic.h"
#import "logging.h"

Central *central;

@implementation Central

- (id)
init 
{
    self = [super init];
    if (self == nil) {
        return nil;
    }

    _manager = [[CBCentralManager alloc] initWithDelegate:self
                                                    queue:nil
                                                  options:nil];
    return self;
}

- (void)
startScanForServiceUuids:(NSArray *)serviceUuids
{
    [_manager scanForPeripheralsWithServices:serviceUuids options:nil];
}

- (void)
stopScan 
{
    [_manager stopScan];
}

- (void)
connectTo:(GWPeripheral *)peripheral
{
    [_manager connectPeripheral:peripheral.cbPeripheral options:nil];
}

- (void)
disconnectFrom:(GWPeripheral *)peripheral
{
    [_manager cancelPeripheralConnection:peripheral.cbPeripheral];
}

- (CBPeripheral *)
findCbForPeripheral:(GWPeripheral *)gwPeripheral
{
    CBPeripheral *cbPeriph;
    NSArray *cbPeriphs;
    NSArray *nsUuids;
    NSUUID *nsUuid;

    nsUuid = [[NSUUID alloc] initWithUUIDString:gwPeripheral.cfg.uuid];
    nsUuids = [NSArray arrayWithObject:nsUuid];

    cbPeriphs = [_manager retrievePeripheralsWithIdentifiers:nsUuids];
    if (cbPeriphs != nil && cbPeriphs.count != 0) {
        assert(cbPeriphs.count == 1);
        return cbPeriphs.firstObject;
    }

    nsUuids = [gwPeripheral serviceUuids];
    if (nsUuids != nil) {
        cbPeriphs =
            [_manager retrieveConnectedPeripheralsWithServices:nsUuids];
        if (cbPeriphs != nil) {
            for (cbPeriph in cbPeriphs) {
                if ([cbPeriph.identifier isEqual:nsUuid]) {
                    return cbPeriph;
                }
            }
        }
    }

    return nil;
}

- (BOOL)
isEnabled
{
    return [_manager state] == CBCentralManagerStatePoweredOn;
}

/*
 Invoked whenever the central manager's state is updated.
 */
- (void)
centralManagerDidUpdateState:(CBCentralManager *)centralManager
{
    NSString *msg;
    BOOL rc;

    assert(centralManager = _manager);

    switch ([_manager state]) {
    case CBCentralManagerStateUnsupported:
        msg = @"The platform/hardware doesn't support Bluetooth Low Energy.";
        rc = FALSE;
        break;
    case CBCentralManagerStateUnauthorized:
        msg = @"The app is not authorized to use Bluetooth Low Energy.";
        rc = FALSE;
        break;
    case CBCentralManagerStatePoweredOff:
        msg = @"Bluetooth is currently powered off.";
        rc = FALSE;
        break;
    case CBCentralManagerStatePoweredOn:
        msg = @"Bluetooth is currently powered on.";
        rc = TRUE;
        break;
    case CBCentralManagerStateUnknown:
        msg = @"Bluetooth state unknown.";
        rc = FALSE;
        break;
    default:
        msg = @"Bluetooth state invalid.";
        rc = FALSE;
        break;
    }
    
    logInfo(@"Bluetooth state: %@", msg);

    if ([self isEnabled]) {
        networkStart();
    } else {
        networkStop();
    }
}

- (void) centralManager:(CBCentralManager *)centralManager
didDiscoverPeripheral:(CBPeripheral *)aPeripheral
    advertisementData:(NSDictionary *)advertisementData
    RSSI:(NSNumber *)RSSI
{
    scanOnSuccess(aPeripheral, advertisementData, RSSI);
}

- (void) centralManager:(CBCentralManager *)centralManager
didConnectPeripheral:(CBPeripheral *)cbPeripheral 
{    
    GWPeripheral *gwPeripheral;

    gwPeripheral = networkFindPeripheral(cbPeripheral.identifier);
    if (gwPeripheral == nil) {
        logDebug(@"Unrecognized device connected: %@",
                 cbPeripheral.identifier.UUIDString);
        return;
    }

    [cbPeripheral setDelegate:self];
    [gwPeripheral onConnectSuccess];
}

- (void)    centralManager:(CBCentralManager *)centralManager
didFailToConnectPeripheral:(CBPeripheral *)cbPeripheral
                     error:(NSError *)error
{
    GWPeripheral *gwPeripheral;

    gwPeripheral = networkFindPeripheral(cbPeripheral.identifier);
    if (gwPeripheral == nil) {
        logDebug(@"Unrecognized device failed to connect: %@",
                 cbPeripheral.identifier.UUIDString);
        return;
    }

    [gwPeripheral onConnectFailureWithError:error];
}

- (void) centralManager:(CBCentralManager *)centralManager
didDisconnectPeripheral:(CBPeripheral *)cbPeripheral
                  error:(NSError *)error
{
    GWPeripheral *gwPeripheral;

    assert(centralManager = _manager);

    gwPeripheral = networkFindPeripheral(cbPeripheral.identifier);
    if (gwPeripheral == nil) {
        logDebug(@"Unrecognized device disconnected: %@",
                 cbPeripheral.identifier.UUIDString);
        return;
    }

    [gwPeripheral onDisconnectWithError:error];
}

- (void) peripheral:(CBPeripheral *)aPeripheral
didDiscoverServices:(NSError *)error 
{
    GWPeripheral *gwPeripheral;

    gwPeripheral = networkFindPeripheral(aPeripheral.identifier);
    if (gwPeripheral == nil) {
        /* XXX: Log error. */
        return;
    }

    if (error != nil) {
        [gwPeripheral onDiscoverServicesFailure:error];
        return;
    }

    [gwPeripheral onDiscoverServicesSuccess];
}

- (void)                  peripheral:(CBPeripheral *)aPeripheral
didDiscoverCharacteristicsForService:(CBService *)service
                               error:(NSError *)error 
{
    GWPeripheral *gwPeripheral;
    GWService *gwService;

    gwPeripheral = networkFindPeripheral(aPeripheral.identifier);
    if (gwPeripheral == nil) {
        /* XXX: Log error. */
        return;
    }

    gwService = [gwPeripheral findServiceWithUuid:service.UUID];
    if (gwService == nil) {
        /* XXX: Log error. */
        return;
    }

    if (error != nil) {
        [gwService onDiscoverCharacteristicsFailureWithError:error];
        return;
    }

    [gwService onDiscoverCharacteristicsSuccess];
}

- (void)                     peripheral:(CBPeripheral *)peripheral
didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic
                                  error:(NSError *)error
{
    if (error != nil) {
        logNotice(@"Failed to read descriptors for characteristic %@ from "
                   "peripheral %@; error=%@",
                  characteristic, peripheral, error);
    } else {
        for (CBDescriptor *descriptor in characteristic.descriptors) {
            logDebug(@"Reading descriptor: %@", descriptor);
            [peripheral readValueForDescriptor:descriptor];
        }
    }
}

- (void) peripheral:(CBPeripheral *)peripheral
didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic
    error:(NSError *)error
{
    GWCharacteristic *gwCharacteristic;
    GWPeripheral *gwPeripheral;
    GWService *gwService;

    gwPeripheral = networkFindPeripheral(peripheral.identifier);
    if (gwPeripheral == nil) {
        /* XXX: Log error. */
        return;
    }

    gwService =
        [gwPeripheral findServiceWithCbService:characteristic.service];
    if (gwService == nil) {
        /* XXX: Log error. */
        return;
    }

    gwCharacteristic =
        [gwService findCharacteristicWithUuid:characteristic.UUID];
    if (gwCharacteristic == nil) {
        /* XXX: Log error. */
        return;
    }

    if (error != nil) {
        [gwCharacteristic onReadFailureWithError:error];
    } else {
        [gwCharacteristic onReadSuccess];
    }
}

- (void)         peripheral:(CBPeripheral *)peripheral
didUpdateValueForDescriptor:(CBDescriptor *)descriptor
                      error:(NSError *)error
{
    if (error != nil) {
        logNotice(@"Failed to read descriptor %@ from peripheral %@; error=%@",
                  descriptor, peripheral, error);
    } else {
        NSData *data = descriptor.value;
        logInfo(@"Read descriptor:%@", data);
    }
}

- (void)                         peripheral:(CBPeripheral *)peripheral
didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
                                      error:(NSError *)error
{
    /* XXX Retry on error? */
}

@end

NSError *
centralInit(void)
{
    central = [Central new];

    return nil;
}
