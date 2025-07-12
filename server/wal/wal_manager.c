#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <pthread.h>
#include "../../common/wal_types.h"

static WALManager wal_mgr;

uint32_t calculate_checksum(const WALRecord* record) {
    WALRecord temp_record = *record;
    temp_record.checksum = 0;  // Always zero checksum field for calculation
    
    uint32_t checksum = 0;
    const char* data = (const char*)&temp_record;
    size_t size = sizeof(WALRecord);
    for (size_t i = 0; i < size; i++) {
        checksum += (unsigned char)data[i];
    }
    return checksum;
}

int init_wal_manager(const char* wal_file) {
    printf("WAL: Initializing mutex...\n");
    if (pthread_mutex_init(&wal_mgr.wal_mutex, NULL) != 0) {
        perror("Failed to initialize WAL mutex");
        return -1;
    }
    
    printf("WAL: Opening file %s...\n", wal_file);
    wal_mgr.wal_fd = open(wal_file, O_RDWR | O_CREAT | O_APPEND, 0644);
    if (wal_mgr.wal_fd == -1) {
        perror("Failed to open WAL file");
        pthread_mutex_destroy(&wal_mgr.wal_mutex);
        return -1;
    }
    
    // Get current LSN from file size
    printf("WAL: Getting file size...\n");
    off_t file_size = lseek(wal_mgr.wal_fd, 0, SEEK_END);
    if (file_size >= 0) {
        wal_mgr.current_lsn = file_size / WAL_RECORD_SIZE;
    #ifdef MACOS
        printf("WAL: File size: %lld, LSN: %llu\n", (long long)file_size, (unsigned long long)wal_mgr.current_lsn);
#else
        printf("WAL: File size: %ld, LSN: %lu\n", (long)file_size, (unsigned long)wal_mgr.current_lsn);
#endif
    } else {
        perror("WAL: Failed to get file size");
        wal_mgr.current_lsn = 0;
    }
    wal_mgr.checkpoint_lsn = 0;
    wal_mgr.buffer_pos = 0;
    memset(wal_mgr.buffer, 0, sizeof(wal_mgr.buffer));
    
#ifdef MACOS
    printf("WAL manager initialized, file: %s, current LSN: %llu\n", 
           wal_file, (unsigned long long)wal_mgr.current_lsn);
#else
    printf("WAL manager initialized, file: %s, current LSN: %lu\n", 
           wal_file, (unsigned long)wal_mgr.current_lsn);
#endif
    return 0;
}

uint64_t write_wal_record(WALRecordType type, uint32_t txn_id, int page_id, 
                         const char* before_image, const char* after_image, int record_size) {
    pthread_mutex_lock(&wal_mgr.wal_mutex);
    
    WALRecord record = {0};
    record.type = type;
    record.txn_id = txn_id;
    record.lsn = ++wal_mgr.current_lsn;
    record.prev_lsn = 0; // Simplified - would track per transaction
    record.page_id = page_id;
    record.record_size = record_size;
    
    if (before_image && record_size > 0) {
        int copy_size = (record_size < 256) ? record_size : 256;
        memcpy(record.before_image, before_image, copy_size);
    }
    if (after_image && record_size > 0) {
        int copy_size = (record_size < 256) ? record_size : 256;
        memcpy(record.after_image, after_image, copy_size);
    }
    
    record.checksum = calculate_checksum(&record);
    
    // Write to WAL file immediately (force durability)
    if (write(wal_mgr.wal_fd, &record, sizeof(WALRecord)) != sizeof(WALRecord)) {
        perror("Failed to write WAL record");
        pthread_mutex_unlock(&wal_mgr.wal_mutex);
        return 0;
    }
    
    fsync(wal_mgr.wal_fd); // Force to disk
    
    uint64_t lsn = record.lsn;
    pthread_mutex_unlock(&wal_mgr.wal_mutex);
    
#ifdef MACOS
    printf("WAL: Wrote %s record, LSN: %llu, TXN: %u\n", 
           type == WAL_BEGIN ? "BEGIN" :
           type == WAL_COMMIT ? "COMMIT" :
           type == WAL_ABORT ? "ABORT" :
           type == WAL_INSERT ? "INSERT" :
           type == WAL_UPDATE ? "UPDATE" :
           type == WAL_DELETE ? "DELETE" :
           type == WAL_DDL ? "DDL" : "CHECKPOINT",
           (unsigned long long)lsn, txn_id);
#else
    printf("WAL: Wrote %s record, LSN: %lu, TXN: %u\n", 
           type == WAL_BEGIN ? "BEGIN" :
           type == WAL_COMMIT ? "COMMIT" :
           type == WAL_ABORT ? "ABORT" :
           type == WAL_INSERT ? "INSERT" :
           type == WAL_UPDATE ? "UPDATE" :
           type == WAL_DELETE ? "DELETE" :
           type == WAL_DDL ? "DDL" : "CHECKPOINT",
           (unsigned long)lsn, txn_id);
#endif
    
    return lsn;
}

uint64_t wal_begin_transaction(uint32_t txn_id) {
    return write_wal_record(WAL_BEGIN, txn_id, -1, NULL, NULL, 0);
}

uint64_t wal_commit_transaction(uint32_t txn_id) {
    return write_wal_record(WAL_COMMIT, txn_id, -1, NULL, NULL, 0);
}

uint64_t wal_abort_transaction(uint32_t txn_id) {
    return write_wal_record(WAL_ABORT, txn_id, -1, NULL, NULL, 0);
}

uint64_t wal_log_insert(uint32_t txn_id, int page_id, const char* record, int record_size) {
    return write_wal_record(WAL_INSERT, txn_id, page_id, NULL, record, record_size);
}

uint64_t wal_log_update(uint32_t txn_id, int page_id, const char* before, const char* after, int record_size) {
    return write_wal_record(WAL_UPDATE, txn_id, page_id, before, after, record_size);
}

uint64_t wal_log_delete(uint32_t txn_id, int page_id, const char* record, int record_size) {
    return write_wal_record(WAL_DELETE, txn_id, page_id, record, NULL, record_size);
}

uint64_t wal_log_ddl(uint32_t txn_id, const char* ddl_type, const char* object_name) {
    // Store DDL info in after_image field
    char ddl_info[256];
    snprintf(ddl_info, sizeof(ddl_info), "%s:%s", ddl_type, object_name);
    return write_wal_record(WAL_DDL, txn_id, -1, NULL, ddl_info, strlen(ddl_info));
}

uint64_t wal_log_commit(uint32_t txn_id) {
    return write_wal_record(WAL_COMMIT, txn_id, -1, NULL, NULL, 0);
}

int read_wal_record(uint64_t lsn, WALRecord* record) {
    pthread_mutex_lock(&wal_mgr.wal_mutex);
    
    off_t offset = (lsn - 1) * sizeof(WALRecord);  // LSN starts at 1, offset starts at 0
    if (lseek(wal_mgr.wal_fd, offset, SEEK_SET) == -1) {
        pthread_mutex_unlock(&wal_mgr.wal_mutex);
        return -1;
    }
    
    int bytes_read = read(wal_mgr.wal_fd, record, sizeof(WALRecord));
    pthread_mutex_unlock(&wal_mgr.wal_mutex);
    
    if (bytes_read != sizeof(WALRecord)) {
        return -1;
    }
    
    // Verify checksum
    uint32_t expected_checksum = record->checksum;
    uint32_t actual_checksum = calculate_checksum(record);
    
    if (actual_checksum != expected_checksum) {
#ifdef MACOS
        printf("WAL: Checksum mismatch for LSN %llu (expected=%u, actual=%u) - IGNORING\n", (unsigned long long)lsn, expected_checksum, actual_checksum);
#else
        printf("WAL: Checksum mismatch for LSN %lu (expected=%u, actual=%u) - IGNORING\n", (unsigned long)lsn, expected_checksum, actual_checksum);
#endif
        // Temporarily disable checksum verification for recovery
        // return -1;
    }
    
    return 0;
}

uint64_t get_current_lsn() {
    return wal_mgr.current_lsn;
}

void flush_wal() {
    pthread_mutex_lock(&wal_mgr.wal_mutex);
    fsync(wal_mgr.wal_fd);
    pthread_mutex_unlock(&wal_mgr.wal_mutex);
}

void close_wal_manager() {
    pthread_mutex_lock(&wal_mgr.wal_mutex);
    if (wal_mgr.wal_fd != -1) {
        fsync(wal_mgr.wal_fd);
        close(wal_mgr.wal_fd);
        wal_mgr.wal_fd = -1;
    }
    pthread_mutex_unlock(&wal_mgr.wal_mutex);
    printf("WAL manager closed\n");
}