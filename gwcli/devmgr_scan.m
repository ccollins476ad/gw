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

#import <assert.h>
#import <stdio.h>
#import "common/network.h"
#import "common/service.h"
#import "common/peripheral.h"
#import "common/characteristic.h"
#import "util.h"
#import "devmgr.h"

#define DEVMGR_INPUT_SCAN_TOP_PERIPHERAL                0
#define DEVMGR_INPUT_SCAN_TOP_QUIT                      1

#define DEVMGR_INPUT_SCAN_PERIPHERAL_CHARACTERISTIC     0
#define DEVMGR_INPUT_SCAN_PERIPHERAL_QUIT               1

static GWPeripheral *devmgr_scan_peripheral;

static GWCharacteristic *
devmgr_scan_characteristic_at_idx(int idx)
{
    GWCharacteristic *characteristic;
    GWService *service;
    int char_idx;

    assert(devmgr_scan_peripheral.cbPeripheral != nil);

    char_idx = 0;
    for (service in devmgr_scan_peripheral.services) {
        if (service.cbService != nil) {
            for (characteristic in service.characteristics) {
                if (characteristic.cbCharacteristic != nil) {
                    if (char_idx == idx) {
                        return characteristic;
                    }

                    char_idx++;
                }
            }
        }
    }

    return nil;
}

static int
devmgr_scan_peripheral_read(int *arg)
{
    char buf[8];
    int rc;

    rc = util_readline(buf, sizeof buf);
    if (rc != 0) {
        return DEVMGR_INPUT_NONE;
    }

    if (strcmp(buf, "q") == 0) {
        return DEVMGR_INPUT_SCAN_PERIPHERAL_QUIT;
    }

    rc = util_parse_int(buf, 0, (int)networkPeripherals.count);
    if (rc == -1) {
        return DEVMGR_INPUT_NONE;
    }

    *arg = rc;
    return DEVMGR_INPUT_SCAN_PERIPHERAL_CHARACTERISTIC;
}

static void
devmgr_scan_peripheral_print(void)
{
    GWCharacteristic *characteristic;
    GWService *service;
    char idx_str[8];
    int char_idx;

    char_idx = 0;

    if (devmgr_scan_peripheral.cbPeripheral != nil) {
        printf("<%s>\n",
               devmgr_scan_peripheral.cbPeripheral.identifier.UUIDString.UTF8String);

        for (service in devmgr_scan_peripheral.services) {
            if (service.cbService != nil) {
                printf("    %s\n",
                       service.cbService.UUID.UUIDString.UTF8String);

                for (characteristic in service.characteristics) {
                    if (characteristic.cbCharacteristic != nil) {
                        if (characteristic.cfg == nil) {
                            snprintf(idx_str, sizeof idx_str, "%3d", char_idx);
                        } else {
                            snprintf(idx_str, sizeof idx_str, "  *");
                        }

                        printf("        %s) %s\n", idx_str,
                               characteristic.cbCharacteristic.UUID.UUIDString.UTF8String);
                        char_idx++;
                    }
                }
            }
        }
    }
}

void
devmgr_scan_peripheral_prompt(void)
{
    GWCharacteristic *characteristic;
    int input;
    int devid;

    while (1) {
        devmgr_scan_peripheral_print();
        input = devmgr_scan_peripheral_read(&devid);
        if (input != DEVMGR_INPUT_NONE) {
            break;
        }
    }

    switch (input) {
    case DEVMGR_INPUT_SCAN_PERIPHERAL_CHARACTERISTIC:
        characteristic = devmgr_scan_characteristic_at_idx(devid);
        if (characteristic != nil && characteristic.cfg == nil) {
            characteristic.cfg = [CfgCharacteristic new];
        }
        break;

    case DEVMGR_INPUT_SCAN_TOP_QUIT:
        devmgr_state = DEVMGR_STATE_SCAN_TOP;
        break;

    default:
        assert(0);
        break;
    }
}

static int
devmgr_scan_top_read(int *arg)
{
    char buf[8];
    int rc;

    rc = util_readline(buf, sizeof buf);
    if (rc != 0) {
        return DEVMGR_INPUT_NONE;
    }

    if (strcmp(buf, "q") == 0) {
        return DEVMGR_INPUT_SCAN_TOP_QUIT;
    }

    rc = util_parse_int(buf, 0, (int)networkPeripherals.count);
    if (rc == -1) {
        return DEVMGR_INPUT_NONE;
    }

    *arg = rc;
    return DEVMGR_INPUT_SCAN_TOP_PERIPHERAL;
}

static void
devmgr_scan_top_print(void)
{
    GWPeripheral *peripheral;
    int i;

    printf("Discovered peripherals ([*] = already configured):\n");
    for (i = 0; i < networkPeripherals.count; i++) {
        peripheral = [networkPeripherals objectAtIndex:i];
        printf("%5d) %s", i,
               peripheral.cbPeripheral.identifier.UUIDString.UTF8String);

        if (peripheral.cfg != nil) {
            printf(" [*]");
        }

        printf("\n");
    }

    printf("\n");

    printf("Enter device index: ");
    fflush(stdout);
}

void
devmgr_scan_top_prompt(void)
{
    int input;
    int devid;

    while (1) {
        devmgr_scan_top_print();
        input = devmgr_scan_top_read(&devid);
        if (input != DEVMGR_INPUT_NONE) {
            break;
        }
    }

    switch (input) {
    case DEVMGR_INPUT_SCAN_TOP_PERIPHERAL:
        printf("\n");
        devmgr_scan_peripheral = [networkPeripherals objectAtIndex:devid];
        devmgr_state = DEVMGR_STATE_SCAN_PERIPHERAL;
        break;

    case DEVMGR_INPUT_SCAN_TOP_QUIT:
        devmgr_state = DEVMGR_STATE_TOP;
        break;

    default:
        assert(0);
        break;
    }
}
