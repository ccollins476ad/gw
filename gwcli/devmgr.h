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

#define DEVMGR_STATE_NONE                   (-1)
#define DEVMGR_STATE_TOP                    0
#define DEVMGR_STATE_PERIPHERAL             1
#define DEVMGR_STATE_SERVICE                2
#define DEVMGR_STATE_CHARACTERISTIC         3
#define DEVMGR_STATE_SCAN_TOP               4
#define DEVMGR_STATE_SCAN_PERIPHERAL        5
#define DEVMGR_STATE_MAX                    6

#define DEVMGR_INPUT_NONE                   (-1)

int action_devmgr(void);
void devmgr_scan_top_prompt(void);
void devmgr_scan_peripheral_prompt(void);

extern int devmgr_state;
