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

// We need all the log functions visible so we set this to DEBUG
#ifdef COMPILE_TIME_LOG_LEVEL
#undef COMPILE_TIME_LOG_LEVEL
#endif

#define COMPILE_TIME_LOG_LEVEL ASL_LEVEL_DEBUG

#import "logging.h"

int log_level = ASL_LEVEL_INFO;

static void addStderrOnce()
{
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		asl_add_log_file(NULL, STDERR_FILENO);
	});
}

#define __MAKE_LOG_FUNCTION(LEVEL, NAME)                            \
void NAME (NSString *format, ...)                                   \
{                                                                   \
	va_list args;                                                   \
                                                                    \
    if (log_level < (LEVEL)) {                                      \
        return;                                                     \
    }                                                               \
                                                                    \
	addStderrOnce();                                                \
                                                                    \
	va_start(args, format);                                         \
	NSString *message =                                             \
        [[NSString alloc] initWithFormat:format arguments:args];    \
	asl_log(NULL, NULL, (LEVEL), "%s", [message UTF8String]);       \
	va_end(args);                                                   \
}

__MAKE_LOG_FUNCTION(ASL_LEVEL_EMERG, logEmergency)
__MAKE_LOG_FUNCTION(ASL_LEVEL_ALERT, logAlert)
__MAKE_LOG_FUNCTION(ASL_LEVEL_CRIT, logCritical)
__MAKE_LOG_FUNCTION(ASL_LEVEL_ERR, logError)
__MAKE_LOG_FUNCTION(ASL_LEVEL_WARNING, logWarning)
__MAKE_LOG_FUNCTION(ASL_LEVEL_NOTICE, logNotice)
__MAKE_LOG_FUNCTION(ASL_LEVEL_INFO, logInfo)
__MAKE_LOG_FUNCTION(ASL_LEVEL_DEBUG, logDebug)
