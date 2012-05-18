//
//  TDPuller.h
//  TouchDB
//
//  Created by Jens Alfke on 12/2/11.
//  Copyright (c) 2011 Couchbase, Inc. All rights reserved.
//

#import "TDReplicator.h"
#import <TouchDB/TDRevision.h>
@class TDChangeTracker, TDSequenceMap;


/** Replicator that pulls from a remote CouchDB. */
@interface TDPuller : TDReplicator
{
    @private
    TDChangeTracker* _changeTracker;
    TDSequenceMap* _pendingSequences;
    NSMutableArray* _revsToPull;
    NSMutableArray* _deletedRevsToPull;
    NSMutableArray* _bulkRevsToPull;
    NSUInteger _httpConnectionCount;
    TDBatcher* _downloadsToInsert;
}

@end



/** A revision received from a remote server during a pull. Tracks the opaque remote sequence ID. */
@interface TDPulledRevision : TDRevision
{
@private
    bool _conflicted;
}

@property (nonatomic) NSUInteger remoteSequenceID;
@property bool conflicted;

@end
