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

#import <stdarg.h>
#import <Foundation/Foundation.h>
#import "misc.h"

NSURL *miscGwUrl;

NSError *
miscError(int code, NSString *format, ...)
{
    NSDictionary *dict;
    NSString *message;
    NSError *error;
	va_list args;

	va_start(args, format);
	message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    dict = [NSDictionary dictionaryWithObject:message
                                       forKey:NSLocalizedDescriptionKey];
    error = [NSError errorWithDomain:@"gwDomain"
                                code:code
                            userInfo:dict];
    return error;
}

NSError *
miscInit(void)
{
    NSFileManager *fileManager;
    NSError *error;
    NSURL *url;

    fileManager = [NSFileManager defaultManager];

    url = [fileManager URLForDirectory:NSLibraryDirectory
                              inDomain:NSUserDomainMask
                     appropriateForURL:nil
                                create:NO
                                 error:&error];
    if (error != nil) {
        return error;
    }

    url = [url URLByAppendingPathComponent:@"gw"];
    [fileManager createDirectoryAtURL:url
          withIntermediateDirectories:YES
                           attributes:nil
                                error:&error];
    if (error != nil) {
        return error;
    }

    miscGwUrl = url;

    return nil;
}
