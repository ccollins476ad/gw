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
#import "common/config.h"
#import "common/network.h"
#import "common/service.h"
#import "common/peripheral.h"
#import "common/characteristic.h"
#import "common/scan.h"
#import "common/persist.h"
#import "common/misc.h"
#import "common/logging.h"
#import "common/central.h"
#import "common/scan.h"
#import "common/options.h"
#import "util.h"
#import "devmgr.h"

#define DEVMGR_INPUT_TOP_PERIPHERAL         0
#define DEVMGR_INPUT_TOP_SCAN               1
#define DEVMGR_INPUT_TOP_QUIT               2

#define DEVMGR_INPUT_PERIPHERAL_SERVICE     0
#define DEVMGR_INPUT_PERIPHERAL_DELETE      1
#define DEVMGR_INPUT_PERIPHERAL_BACK        2

#define DEVMGR_INPUT_SERVICE_CHARACTERISTIC 0
#define DEVMGR_INPUT_SERVICE_DELETE         1
#define DEVMGR_INPUT_SERVICE_BACK           2

#define DEVMGR_INPUT_CHARACTERISTIC_DELETE  0
#define DEVMGR_INPUT_CHARACTERISTIC_BACK    1

#define DEVMGR_SCAN_SECONDS                 5

typedef void devmgr_state_fn(void);

static void devmgr_top_prompt(void);
static void devmgr_peripheral_prompt(void);
static void devmgr_service_prompt(void);
static void devmgr_characteristic_prompt(void);

static devmgr_state_fn *devmgr_state_fns[DEVMGR_STATE_MAX] = {
    [DEVMGR_STATE_TOP] = devmgr_top_prompt,
    [DEVMGR_STATE_PERIPHERAL] = devmgr_peripheral_prompt,
    [DEVMGR_STATE_SERVICE] = devmgr_service_prompt,
    [DEVMGR_STATE_CHARACTERISTIC] = devmgr_characteristic_prompt,
    [DEVMGR_STATE_SCAN_TOP] = devmgr_scan_top_prompt,
    [DEVMGR_STATE_SCAN_PERIPHERAL] = devmgr_scan_peripheral_prompt,
};

int devmgr_state;

static CfgPeripheral *devmgr_peripheral;
static CfgService *devmgr_service;
static CfgCharacteristic *devmgr_characteristic;

static NSArray *
devmgr_sorted_set(NSSet *set)
{
    NSSortDescriptor *sort;
    NSArray *arr;

    sort = [NSSortDescriptor sortDescriptorWithKey:@"uuid" ascending:YES];

    arr = set.allObjects;
    arr = [arr sortedArrayUsingDescriptors:@[sort]];

    return arr;
}

static int
devmgr_characteristic_read(int *arg)
{
    char buf[8];
    int rc;

    rc = util_readline(buf, sizeof buf);
    if (rc != 0) {
        return DEVMGR_INPUT_NONE;
    }

    if (strcmp(buf, "d") == 0) {
        return DEVMGR_INPUT_CHARACTERISTIC_DELETE;
    } else if (strcmp(buf, "q") == 0) {
        return DEVMGR_INPUT_CHARACTERISTIC_BACK;
    }

    return DEVMGR_INPUT_NONE;
}

static void
devmgr_characteristic_print(CfgCharacteristic *characteristic)
{
    printf("uuid: %s\n", characteristic.uuid.UTF8String);

    printf("\n");

    printf("Enter 'd' to delete characteristic: ");
    fflush(stdout);
}

static void
devmgr_characteristic_prompt(void)
{
    int input;

    assert(devmgr_characteristic != nil);

    while (1) {
        devmgr_characteristic_print(devmgr_characteristic);
        input = devmgr_characteristic_read(NULL);
        if (input != DEVMGR_INPUT_NONE) {
            break;
        }
    }

    switch (input) {
    case DEVMGR_INPUT_CHARACTERISTIC_DELETE:
        [devmgr_service removeCharacteristicsObject:devmgr_characteristic];
        cfgSave();

        devmgr_characteristic = nil;
        devmgr_state = DEVMGR_STATE_SERVICE;
        break;

    case DEVMGR_INPUT_CHARACTERISTIC_BACK:
        devmgr_characteristic = nil;
        devmgr_state = DEVMGR_STATE_SERVICE;
        break;

    default:
        assert(0);
        break;
    }
}

static int
devmgr_service_read(NSArray *characteristics, int *arg)
{
    char buf[8];
    int rc;

    rc = util_readline(buf, sizeof buf);
    if (rc != 0) {
        return DEVMGR_INPUT_NONE;
    }

    if (strcmp(buf, "d") == 0) {
        return DEVMGR_INPUT_SERVICE_DELETE;
    } else if (strcmp(buf, "q") == 0) {
        return DEVMGR_INPUT_SERVICE_BACK;
    }

    rc = util_parse_int(buf, 0, (int)characteristics.count);
    if (rc == -1) {
        return DEVMGR_INPUT_NONE;
    }

    *arg = rc;
    return DEVMGR_INPUT_SERVICE_CHARACTERISTIC;
}

static void
devmgr_service_print(CfgService *service, NSArray *characteristics)
{
    CfgCharacteristic *characteristic;
    int i;

    printf("uuid: %s\n", service.uuid.UTF8String);

    if (service.characteristics.count == 0) {
        printf("no characteristics.\n");
    } else {
        printf("characteristics:\n");
        for (i = 0; i < characteristics.count; i++) {
            characteristic = [characteristics objectAtIndex:i];
            printf("%5d) %s\n", i, characteristic.uuid.UTF8String);
        }
    }
        
    printf("\n");

    printf("Enter characteristic index or 'd' to delete service: ");
    fflush(stdout);
}

static void
devmgr_service_prompt(void)
{
    NSArray *characteristics;
    int input;
    int chrid;

    assert(devmgr_service != nil);

    characteristics = devmgr_sorted_set(devmgr_service.characteristics);
    while (1) {
        devmgr_service_print(devmgr_service, characteristics);
        input = devmgr_service_read(characteristics, &chrid);
        if (input != DEVMGR_INPUT_NONE) {
            break;
        }
    }

    switch (input) {
    case DEVMGR_INPUT_SERVICE_CHARACTERISTIC:
        printf("\n");
        devmgr_characteristic = [characteristics objectAtIndex:chrid];
        devmgr_state = DEVMGR_STATE_CHARACTERISTIC;
        break;

    case DEVMGR_INPUT_SERVICE_DELETE:
        [devmgr_peripheral removeServicesObject:devmgr_service];
        cfgSave();

        devmgr_service = nil;
        devmgr_characteristic = nil;
        devmgr_state = DEVMGR_STATE_PERIPHERAL;
        break;

    case DEVMGR_INPUT_SERVICE_BACK:
        devmgr_service = nil;
        devmgr_state = DEVMGR_STATE_PERIPHERAL;
        break;

    default:
        assert(0);
        break;
    }
}

static int
devmgr_peripheral_read(NSArray *services, int *arg)
{
    char buf[8];
    int rc;

    rc = util_readline(buf, sizeof buf);
    if (rc != 0) {
        return DEVMGR_INPUT_NONE;
    }

    if (strcmp(buf, "d") == 0) {
        return DEVMGR_INPUT_PERIPHERAL_DELETE;
    } else if (strcmp(buf, "q") == 0) {
        return DEVMGR_INPUT_PERIPHERAL_BACK;
    }

    rc = util_parse_int(buf, 0, (int)services.count);
    if (rc == -1) {
        return DEVMGR_INPUT_NONE;
    }

    *arg = rc;
    return DEVMGR_INPUT_PERIPHERAL_SERVICE;
}

static void
devmgr_peripheral_print(CfgPeripheral *peripheral, NSArray *services)
{
    CfgService *service;
    int i;

    printf("uuid: %s\n", peripheral.uuid.UTF8String);
    printf("stay connected: %d\n", peripheral.stayConnected.intValue);

    if (peripheral.services.count == 0) {
        printf("no services.\n");
    } else {
        printf("services:\n");
        for (i = 0; i < services.count; i++) {
            service = [services objectAtIndex:i];
            printf("%5d) %s\n", i, service.uuid.UTF8String);
        }
    }
        
    printf("\n");

    printf("Enter service index or 'd' to delete peripheral: ");
    fflush(stdout);
}

static void
devmgr_peripheral_prompt(void)
{
    NSArray *services;
    int input;
    int srvid;

    assert(devmgr_peripheral != nil);

    services = devmgr_sorted_set(devmgr_peripheral.services);
    while (1) {
        devmgr_peripheral_print(devmgr_peripheral, services);
        input = devmgr_peripheral_read(services, &srvid);
        if (input != DEVMGR_INPUT_NONE) {
            break;
        }
    }

    switch (input) {
    case DEVMGR_INPUT_PERIPHERAL_SERVICE:
        printf("\n");
        devmgr_service = [services objectAtIndex:srvid];
        devmgr_state = DEVMGR_STATE_SERVICE;
        break;

    case DEVMGR_INPUT_PERIPHERAL_DELETE:
        [cfg removePeripheralsObject:devmgr_peripheral];
        cfgSave();

        devmgr_peripheral = nil;
        devmgr_service = nil;
        devmgr_characteristic = nil;
        devmgr_state = DEVMGR_STATE_TOP;
        break;

    case DEVMGR_INPUT_PERIPHERAL_BACK:
        devmgr_peripheral = nil;
        devmgr_state = DEVMGR_STATE_TOP;
        break;

    default:
        assert(0);
        break;
    }
}

static int
devmgr_scan_start(void)
{
    NSError *error;
    NSDate *date;

    error = networkInit();
    if (error != nil) {
        logError(error.localizedDescription);
        return EXIT_FAILURE;
    }

    error = centralInit();
    if (error != nil) {
        logError(error.localizedDescription);
        return EXIT_FAILURE;
    }

    optionPromiscuous = TRUE;
    optionNetworkActive = FALSE;

    printf("scanning for %d seconds...\n", DEVMGR_SCAN_SECONDS);
    scanStart();

    date = [NSDate dateWithTimeIntervalSinceNow:DEVMGR_SCAN_SECONDS];
    [[NSRunLoop currentRunLoop] runUntilDate:date];
    [NSThread sleepForTimeInterval:DEVMGR_SCAN_SECONDS];

    //scanStop();

    return 0;
}

static int
devmgr_top_read(NSArray *peripherals, int *arg)
{
    char buf[8];
    int rc;

    rc = util_readline(buf, sizeof buf);
    if (rc != 0) {
        return DEVMGR_INPUT_NONE;
    }

    if (strcmp(buf, "s") == 0) {
        return DEVMGR_INPUT_TOP_SCAN;
    } else if (strcmp(buf, "q") == 0) {
        return DEVMGR_INPUT_TOP_QUIT;
    }

    rc = util_parse_int(buf, 0, (int)peripherals.count);
    if (rc == -1) {
        return DEVMGR_INPUT_NONE;
    }

    *arg = rc;
    return DEVMGR_INPUT_TOP_PERIPHERAL;
}

static void
devmgr_top_print(NSArray *peripherals)
{
    CfgPeripheral *peripheral;
    int i;

    if (cfg.peripherals.count == 0) {
        printf("No configured peripherals.\n");
    } else {
        printf("Configured peripherals:\n");
        for (i = 0; i < peripherals.count; i++) {
            peripheral = [peripherals objectAtIndex:i];
            printf("%5d) %s\n", i, peripheral.uuid.UTF8String);
        }
    }

    printf("\n");

    printf("Enter device index or 's' to scan: ");
    fflush(stdout);
}

static void
devmgr_top_prompt(void)
{
    NSArray *peripherals;
    int input;
    int devid;
    int rc;

    peripherals = devmgr_sorted_set(cfg.peripherals);
    while (1) {
        devmgr_top_print(peripherals);
        input = devmgr_top_read(peripherals, &devid);
        if (input != DEVMGR_INPUT_NONE) {
            break;
        }
    }

    switch (input) {
    case DEVMGR_INPUT_TOP_PERIPHERAL:
        printf("\n");
        devmgr_peripheral = [peripherals objectAtIndex:devid];
        devmgr_state = DEVMGR_STATE_PERIPHERAL;
        break;

    case DEVMGR_INPUT_TOP_SCAN:
        rc = devmgr_scan_start();
        assert(rc == 0);

        devmgr_state = DEVMGR_STATE_SCAN_TOP;
        break;

    case DEVMGR_INPUT_TOP_QUIT:
        devmgr_state = DEVMGR_STATE_NONE;
        break;

    default:
        assert(0);
        break;
    }
}

static void
devmgr_loop(void)
{
    devmgr_state_fn *fn;

    while (devmgr_state != DEVMGR_STATE_NONE) {
        fn = devmgr_state_fns[devmgr_state];
        fn();
    }
}

int
action_devmgr(void)
{
    NSError *error;

    error = cfgInit();
    if (error != nil) {
        logError(error.localizedDescription);
        return EXIT_FAILURE;
    }

    devmgr_state = DEVMGR_STATE_TOP;
    devmgr_loop();

    return 0;
}

