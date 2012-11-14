//
//  TDMultipartWriter.m
//  TouchDB
//
//  Created by Jens Alfke on 2/2/12.
//  Copyright (c) 2012 Couchbase, Inc. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file
//  except in compliance with the License. You may obtain a copy of the License at
//    http://www.apache.org/licenses/LICENSE-2.0
//  Unless required by applicable law or agreed to in writing, software distributed under the
//  License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
//  either express or implied. See the License for the specific language governing permissions
//  and limitations under the License.

#import "TDMultipartWriter.h"
#import "TDMisc.h"
#import "CollectionUtils.h"
#import "Test.h"


@implementation TDMultipartWriter


- (id) initWithContentType: (NSString*)type boundary: (NSString*)boundary {
    self = [super init];
    if (self) {
        _contentType = [type copy];
        _boundary = [(boundary ?: TDCreateUUID()) copy];
        // Account for the final boundary to be written by -opened. Add its length now, because the
        // client is probably going to ask for my .length *before* it calls -open.
        NSString* finalBoundaryStr = $sprintf(@"\r\n--%@--", _boundary);
        _finalBoundary = [finalBoundaryStr dataUsingEncoding: NSUTF8StringEncoding];
        _length += _finalBoundary.length;
    }
    return self;
}




@synthesize boundary=_boundary;


- (NSString*) contentType {
    return $sprintf(@"%@; boundary=\"%@\"", _contentType, _boundary);
}


- (void) setNextPartsHeaders: (NSDictionary*)headers {
    _nextPartsHeaders = headers;
}


- (void) addInput: (id)part length:(UInt64)length {
    NSMutableString* headers = [NSMutableString stringWithFormat: @"\r\n--%@\r\n", _boundary];
    [headers appendFormat: @"Content-Length: %llu\r\n", length];
    for (NSString* name in _nextPartsHeaders) {
        // Strip any CR or LF in the header value. This isn't real quoting, just enough to ensure
        // a spoofer can't add bogus headers by putting CRLF into a header value!
        NSMutableString* value = [_nextPartsHeaders[name] mutableCopy];
        [value replaceOccurrencesOfString: @"\r" withString: @""
                                  options: 0 range: NSMakeRange(0, value.length)];
        [value replaceOccurrencesOfString: @"\n" withString: @""
                                  options: 0 range: NSMakeRange(0, value.length)];
        [headers appendFormat: @"%@: %@\r\n", name, value];
    }
    [headers appendString: @"\r\n"];
    NSData* separator = [headers dataUsingEncoding: NSUTF8StringEncoding];
    [self setNextPartsHeaders: nil];

    [super addInput: separator length: separator.length];
    [super addInput: part length: length];
}


- (void) opened {
    if (_finalBoundary) {
        // Append the final boundary:
        [super addInput: _finalBoundary length: 0];
        // _length was already adjusted for this in -init
        _finalBoundary = nil;
    }
    [super opened];
}


- (void) openForURLRequest: (NSMutableURLRequest*)request;
{
    request.HTTPBodyStream = [self openForInputStream];
    [request setValue: self.contentType forHTTPHeaderField: @"Content-Type"];
}


@end





TestCase(TDMultipartWriter) {
    NSString* expectedOutput = @"\r\n--BOUNDARY\r\nContent-Length: 16\r\n\r\n<part the first>\r\n--BOUNDARY\r\nContent-Length: 10\r\nContent-Type: something\r\n\r\n<2nd part>\r\n--BOUNDARY--";
    RequireTestCase(TDMultiStreamWriter);
    for (unsigned bufSize = 1; bufSize < expectedOutput.length+1; ++bufSize) {
        TDMultipartWriter* mp = [[TDMultipartWriter alloc] initWithContentType: @"foo/bar" 
                                                                           boundary: @"BOUNDARY"];
        CAssertEqual(mp.contentType, @"foo/bar; boundary=\"BOUNDARY\"");
        CAssertEqual(mp.boundary, @"BOUNDARY");
        [mp addData: [@"<part the first>" dataUsingEncoding: NSUTF8StringEncoding]];
        [mp setNextPartsHeaders: $dict({@"Content-Type", @"something"})];
        [mp addData: [@"<2nd part>" dataUsingEncoding: NSUTF8StringEncoding]];
        CAssertEq((NSUInteger)mp.length, expectedOutput.length);

        NSData* output = [mp allOutput];
        CAssertEqual(output.my_UTF8ToString, expectedOutput);
        [mp close];
    }
}
