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

#import <unistd.h>
#import <Foundation/Foundation.h>
#import <IOBluetooth/IOBluetooth.h>
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
#import "common/options.h"
#import "devmgr.h"

#define STATIC_ASSERT(test, msg) \
    typedef char _static_assert_ ## msg [ ((test) ? 1 : -1) ]

STATIC_ASSERT(__has_feature(objc_arc), ARC_required);

#define GW_ACTION_NONE      (-1)
#define GW_ACTION_SNIFF      0
#define GW_ACTION_READ      1
#define GW_ACTION_DEVMGR    2
#define GW_ACTION_MAX       3

typedef int action_fn(void);

static int
parse_action(int argc, char **argv)
{
    if (argc <= 0) {
        return GW_ACTION_NONE;
    }

    if (strcmp(argv[0], "sniff") == 0) {
        return GW_ACTION_SNIFF;
    } else if (strcmp(argv[0], "read") == 0) {
        return GW_ACTION_READ;
    } else if (strcmp(argv[0], "devmgr") == 0) {
        return GW_ACTION_DEVMGR;
    } else {
        return GW_ACTION_NONE;
    }
}

static int
action_sniff(void)
{
    NSError *error;

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

    scanStart();

    [[NSRunLoop currentRunLoop] run];

    return 0;
}

static int
action_read(void)
{
    NSError *error;

    error = cfgInit();
    if (error != nil) {
        logError(error.localizedDescription);
        return EXIT_FAILURE;
    }

    error = persistInit();
    if (error != nil) {
        logError(error.localizedDescription);
        return EXIT_FAILURE;
    }

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

    if (networkPeripherals.count == 0) {
        logError(@"No devices configured.");
        return EXIT_FAILURE;
    }

    optionPromiscuous = FALSE;
    optionNetworkActive = TRUE;

    [[NSRunLoop currentRunLoop] run];

    return 0;
}

static action_fn *actions[GW_ACTION_MAX] = {
    [GW_ACTION_SNIFF]   = action_sniff,
    [GW_ACTION_READ]    = action_read,
    [GW_ACTION_DEVMGR]  = action_devmgr,
};

int
main(int argc, char **argv)
{
    action_fn *action_callback;
    NSError *error;
    int action_id;
    int arg;
    int rc;

    error = miscInit();
    if (error != nil) {
        logError(error.localizedDescription);
        return EXIT_FAILURE;
    }

    while ((arg = getopt(argc, argv, "v")) > 0) {
        switch (arg) {
        case 'v':
            log_level = ASL_LEVEL_DEBUG;
            break;

        default:
            assert(0);
            break;
        }
    }

    action_id = parse_action(argc + optind, argv + optind);
    if (action_id == GW_ACTION_NONE) {
        assert(0);
    }

    action_callback = actions[action_id];
    rc = action_callback();

    return rc;
}
