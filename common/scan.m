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
#import "peripheral.h"
#import "service.h"
#import "central.h"
#import "logging.h"
#import "options.h"
#import "scan.h"

static BOOL scanInProgress;

static NSArray *
scanInterestingServiceUuids(void)
{
    NSMutableArray *uuids;
    GWPeripheral *peripheral;
    GWService *service;
    CBUUID *uuid;
    int i;
    int j;

    uuids = [NSMutableArray new];
    for (i = 0; i < networkPeripherals.count; i++) {
        peripheral = [networkPeripherals objectAtIndex:i];
        if (peripheral.cbPeripheral == nil) {
            for (j = 0; j < peripheral.services.count; j++) {
                service = [peripheral.services objectAtIndex:j];
                uuid = [CBUUID UUIDWithString:service.cfg.uuid];
                [uuids addObject:uuid];
            }
        }
    }

    return uuids;
}

static BOOL
scanIsComplete(void)
{
    GWPeripheral *periph;
    NSUInteger numPeriphs;
    int i;

    if (optionPromiscuous) {
        return FALSE;
    }

    numPeriphs = networkPeripherals.count;
    if (numPeriphs == 0) {
        return FALSE;
    }

    for (i = 0; i < numPeriphs; i++) {
        periph = [networkPeripherals objectAtIndex:i];
        if (periph.cbPeripheral == nil) {
            return FALSE;
        }
    }

    return TRUE;
}

static void
scanStop(void)
{
    if (scanInProgress) {
        [central stopScan];
        scanInProgress = FALSE;
        /* XXX: Stop timer. */
    }
}

void
scanStart(void)
{
    NSArray *serviceUuids;

    /* Restart scan if it is already in progress. */
    scanStop();

    if (optionPromiscuous) {
        serviceUuids = nil;
    } else {
        serviceUuids = scanInterestingServiceUuids();
    }
    [central startScanForServiceUuids:serviceUuids];

    scanInProgress = TRUE;

    /* XXX: Start timer. */
}

void
scanOnSuccess(CBPeripheral *cbPeripheral, NSDictionary *advertisementData,
              NSNumber *rssi)
{
    GWPeripheral *gwPeripheral;

    /* XXX: Check if device already discovered / connected? */
    logDebug(@"scanOnSuccess(); peripheral=%@ rssi=%@ "
              "advertisementData=%@",
             cbPeripheral, rssi, advertisementData);

    gwPeripheral = networkFindPeripheral(cbPeripheral.identifier);
    if (gwPeripheral == nil) {
        if (optionPromiscuous) {
            gwPeripheral = [GWPeripheral new];
            [networkPeripherals addObject:gwPeripheral];
        }
    }

    if (gwPeripheral != nil) {
        [gwPeripheral onDiscoveredWithCb:cbPeripheral];
    }

    if (scanIsComplete()) {
        scanStop();
    }
}
