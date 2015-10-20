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

#import <stdio.h>
#import <stdlib.h>
#import "util.h"

int
util_parse_int(char *s, int min, int max_plus_one)
{
    unsigned long ul;
    char *ep;

    ul = strtoul(s, &ep, 10);
    if (s[0] == '\0' || *ep != '\0') {
        return -1;
    }

    if (ul < min || ul >= max_plus_one) {
        return -1;
    }

    return (int)ul;
}

int
util_readline(char *buf, int buf_size)
{
    char *s;

    s = fgets(buf, buf_size, stdin);
    if (s == NULL || s[0] == '\0') {
        return -1;
    }

    /* Remove trailing newline. */
    buf[strlen(buf) - 1] = '\0';

    return 0;
}
