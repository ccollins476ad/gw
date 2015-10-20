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

/*
 logging. Simple wrapper macros/functions around ASL (Apple System
 Log)

 We support a compile-time log level through
 COMPILE_TIME_LOG_LEVEL. This will turn the associated log calls
 into NOPs.

 The log levels are the constants defined in asl.h:

 #define ASL_LEVEL_EMERG   0
 #define ASL_LEVEL_ALERT   1
 #define ASL_LEVEL_CRIT    2
 #define ASL_LEVEL_ERR     3
 #define ASL_LEVEL_WARNING 4
 #define ASL_LEVEL_NOTICE  5
 #define ASL_LEVEL_INFO    6
 #define ASL_LEVEL_DEBUG   7

 For a description of when to use each level, see here:

 http://developer.apple.com/library/mac/#documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/LoggingErrorsAndWarnings.html#//apple_ref/doc/uid/10000172i-SW8-SW1

 Emergency (level 0) - The highest priority, usually reserved for
                       catastrophic failures and reboot notices.

 Alert (level 1)     - A serious failure in a key system.

 Critical (level 2)  - A failure in a key system.

 Error (level 3)     - Something has failed.

 Warning (level 4)   - Something is amiss and might fail if not
                       corrected.

 Notice (level 5)    - Things of moderate interest to the user or
                       administrator.

 Info (level 6)      - The lowest priority that you would normally log, and
                       purely informational in nature.

 Debug (level 7)     - The lowest priority, and normally not logged except
                       for messages from the kernel.


 Note that by default the iOS syslog/console will only record items up
 to level ASL_LEVEL_NOTICE.

 */

/** @todo

 We want better multithread support. Default NULL client uses
 locking. Perhaps we can check for [NSThread mainThread] and associate
 an asl client object to that thread. Then we can specify
 ASL_OPT_STDERR and not need an extra call to add stderr.

 */

#import <Foundation/Foundation.h>

extern int log_level;

// By default, in non-debug mode we want to disable any logging
// statements except NOTICE and above.
#ifndef COMPILE_TIME_LOG_LEVEL
	#ifdef NDEBUG
		#define COMPILE_TIME_LOG_LEVEL ASL_LEVEL_NOTICE
	#else
		#define COMPILE_TIME_LOG_LEVEL ASL_LEVEL_DEBUG
	#endif
#endif

#include <asl.h>

#if COMPILE_TIME_LOG_LEVEL >= ASL_LEVEL_EMERG
void logEmergency(NSString *format, ...);
#else
#define logEmergency(...)
#endif

#if COMPILE_TIME_LOG_LEVEL >= ASL_LEVEL_ALERT
void logAlert(NSString *format, ...);
#else
#define logAlert(...)
#endif

#if COMPILE_TIME_LOG_LEVEL >= ASL_LEVEL_CRIT
void logCritical(NSString *format, ...);
#else
#define logCritical(...)
#endif

#if COMPILE_TIME_LOG_LEVEL >= ASL_LEVEL_ERR
void logError(NSString *format, ...);
#else
#define logError(...)
#endif

#if COMPILE_TIME_LOG_LEVEL >= ASL_LEVEL_WARNING
void logWarning(NSString *format, ...);
#else
#define logWarning(...)
#endif

#if COMPILE_TIME_LOG_LEVEL >= ASL_LEVEL_NOTICE
void logNotice(NSString *format, ...);
#else
#define logNotice(...)
#endif

#if COMPILE_TIME_LOG_LEVEL >= ASL_LEVEL_INFO
void logInfo(NSString *format, ...);
#else
#define logInfo(...)
#endif

#if COMPILE_TIME_LOG_LEVEL >= ASL_LEVEL_DEBUG
void logDebug(NSString *format, ...);
#else
#define logDebug(...)
#endif

