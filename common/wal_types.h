#ifndef WAL_TYPES_H
#define WAL_TYPES_H

#include "types.h"

#define WAL_RECORD_SIZE 512
#define WAL_BUFFER_SIZE 4096

typedef enum {
    WAL_BEGIN,
    WAL_COMMIT,
    WAL_ABORT,
    WAL_INSERT,
    WAL_UPDATE,
    WAL_DELETE,
    WAL_CHECKPOINT
} WALRecordType;

typedef struct {
    WALRecordType type;
    uint32_t txn_id;
    uint64_t lsn;          // Log Sequence Number
    uint64_t prev_lsn;     // Previous LSN for this transaction
    int page_id;
    int record_size;
    char before_image[256]; // For UNDO
    char after_image[256];  // For REDO
    uint32_t checksum;
} 
#ifdef MACOS
__attribute__((packed, aligned(PLATFORM_ALIGNMENT)))
#else
__attribute__((packed))
#endif
WALRecord;

typedef struct {
    uint64_t current_lsn;
    uint64_t checkpoint_lsn;
    int wal_fd;
    char buffer[WAL_BUFFER_SIZE];
    int buffer_pos;
    pthread_mutex_t wal_mutex;
} WALManager;

#endif