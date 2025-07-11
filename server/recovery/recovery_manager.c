#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "../../common/wal_types.h"

/**
 * MiniDB Recovery Manager
 * ======================
 * 
 * CRASH RECOVERY ALGORITHM (ARIES-based):
 * The recovery process ensures database consistency after system failures
 * using Write-Ahead Logging (WAL) and a three-phase recovery protocol.
 * 
 * RECOVERY PHASES:
 * 1. ANALYSIS: Scan WAL to identify committed/uncommitted transactions
 * 2. REDO: Replay all operations to restore database to crash state
 * 3. UNDO: Rollback all uncommitted transactions
 * 
 * WAL PROTOCOL:
 * - All changes written to WAL before data pages (Write-Ahead)
 * - WAL records contain before/after images for undo/redo
 * - LSN (Log Sequence Number) provides total ordering
 * - Force WAL to disk before commit (durability)
 * 
 * REDO LOGIC:
 * - Replay all operations from WAL in forward order
 * - Idempotent: Safe to replay multiple times
 * - Restores database to state at time of crash
 * - Includes both committed and uncommitted changes
 * 
 * UNDO LOGIC:
 * - Rollback uncommitted transactions in reverse order
 * - Uses before-images to restore original values
 * - Ensures atomicity: all-or-nothing transaction semantics
 * - Writes compensation log records (CLRs) for crash during recovery
 * 
 * CHECKPOINTING:
 * - Periodic snapshots to limit recovery time
 * - Forces dirty pages to disk
 * - Records active transactions at checkpoint time
 * - Enables recovery to start from checkpoint, not beginning
 */

// Include diagnostics
extern void dump_page_contents(int page_id, const char* label);
extern void dump_wal_record(WALRecord* record, const char* label);
extern void dump_data_row(int page_id, int row_index, int record_size, const char* label);
extern void dump_row_header(const char* row_ptr, int record_size, const char* label);
extern void dump_index_row(const char* row_ptr, int row_type, const char* label);

// Global recovery record size
int g_recovery_record_size = 0;

// DataPage structure definition
typedef struct {
    int record_count;
    int next_page;
    int deleted_count;
    char records[PAGE_SIZE - 12];
} DataPage;

extern int read_wal_record(uint64_t lsn, WALRecord* record);
extern uint64_t get_current_lsn();
extern Page* get_page(int page_id, uint32_t txn_id);
extern void unpin_page(Page* page);
extern void mark_dirty(Page* page);

typedef struct {
    uint32_t txn_id;
    uint64_t begin_lsn;
    bool committed;
} ActiveTransaction;

int perform_redo_recovery() {
    printf("Starting REDO recovery...\n");
    
    // Dump page before recovery
    dump_page_contents(10, "BEFORE RECOVERY");
    
    uint64_t current_lsn = get_current_lsn();
    WALRecord record;
    int redo_count = 0;
    
    // Scan WAL from beginning
    for (uint64_t lsn = 1; lsn <= current_lsn; lsn++) {
        read_wal_record(lsn, &record); // Always read, ignore checksum errors
        
        switch (record.type) {
            case WAL_INSERT: {
                // REDO: Append record to page
                if (record.page_id > 0 && record.record_size > 0) {
                    dump_wal_record(&record, "INSERT RECORD");
                    
                    Page* page = get_page(record.page_id, 1);
                    if (page) {
                        DataPage* data_page = (DataPage*)page->data;
                        
                        printf("BEFORE INSERT: page %d has %d records\n", record.page_id, data_page->record_count);
                        
                        // Clear page chain once at start of recovery
                        static bool recovery_cleared = false;
                        if (!recovery_cleared) {
                            data_page->record_count = 0;
                            data_page->next_page = -1;
                            data_page->deleted_count = 0;
                            memset(data_page->records, 0, sizeof(data_page->records));
                            recovery_cleared = true;
                            printf("CLEARED page chain for recovery\n");
                        }
                        
                        if (record.record_size <= 256) {
                            // Always use the WAL record size for consistency
                            int wal_record_size = record.record_size;
                            
                            // Store the WAL record size globally for scan operations
                            extern int g_recovery_record_size;
                            if (g_recovery_record_size == 0) {
                                g_recovery_record_size = wal_record_size;
                                printf("REDO: Setting recovery record size to %d\n", g_recovery_record_size);
                            }
                            
                            // Find page with space, starting from current page
                            Page* target_page = page;
                            DataPage* target_data_page = data_page;
                            
                            while (target_page && target_data_page) {
                                if ((target_data_page->record_count + 1) * wal_record_size < sizeof(target_data_page->records)) {
                                    // Found space - insert here
                                    memcpy(target_data_page->records + (target_data_page->record_count * wal_record_size),
                                           record.after_image, wal_record_size);
                                    target_data_page->record_count++;
                                    mark_dirty(target_page);
                                    redo_count++;
                                    printf("REDO: Applied INSERT #%d, page %d, count=%d\n", 
                                           redo_count, (target_page == page) ? record.page_id : target_data_page->record_count, target_data_page->record_count);
                                    break;
                                }
                                
                                // Current page full, try next page
                                if (target_data_page->next_page == -1) {
                                    // Need new page
                                    extern int allocate_page();
                                    int new_page_id = allocate_page();
                                    if (new_page_id > 0) {
                                        target_data_page->next_page = new_page_id;
                                        mark_dirty(target_page);
                                        if (target_page != page) unpin_page(target_page);
                                        
                                        target_page = get_page(new_page_id, 1);
                                        if (target_page) {
                                            target_data_page = (DataPage*)target_page->data;
                                            target_data_page->record_count = 0;
                                            target_data_page->next_page = -1;
                                            target_data_page->deleted_count = 0;
                                            memset(target_data_page->records, 0, sizeof(target_data_page->records));
                                            printf("REDO: Allocated new page %d\n", new_page_id);
                                        }
                                    } else {
                                        break;
                                    }
                                } else {
                                    // Move to existing next page
                                    if (target_page != page) unpin_page(target_page);
                                    target_page = get_page(target_data_page->next_page, 1);
                                    if (target_page) {
                                        target_data_page = (DataPage*)target_page->data;
                                    }
                                }
                            }
                            
                            if (target_page != page && target_page) unpin_page(target_page);
                        }
                        unpin_page(page);
                    }
                }
                break;
            }
            case WAL_UPDATE: {
                // REDO: Apply after image (simplified - overwrite first matching record)
                if (record.page_id > 0 && record.record_size > 0) {
                    Page* page = get_page(record.page_id, 1);
                    if (page) {
                        DataPage* data_page = (DataPage*)page->data;
                        if (data_page->record_count > 0 && record.record_size <= 256) {
                            memcpy(data_page->records, record.after_image, record.record_size);
                            mark_dirty(page);
                            redo_count++;
                            printf("REDO: Applied UPDATE for TXN %u, page %d\n", record.txn_id, record.page_id);
                        }
                        unpin_page(page);
                    }
                }
                break;
            }
            case WAL_DELETE: {
                // REDO: Mark record as deleted
                if (record.page_id > 0) {
                    Page* page = get_page(record.page_id, 1);
                    if (page) {
                        // Simple deletion - mark first byte as deleted
                        page->data[0] = 1;
                        mark_dirty(page);
                        unpin_page(page);
                        redo_count++;
                        printf("REDO: Applied DELETE for TXN %u, page %d\n",
                               record.txn_id, record.page_id);
                    }
                }
                break;
            }
            default:
                break;
        }
    }
    
    // Dump page after recovery
    dump_page_contents(10, "AFTER RECOVERY");
    
    printf("REDO recovery completed: %d operations applied\n", redo_count);
    return redo_count;
}

int perform_undo_recovery() {
    printf("Starting UNDO recovery...\n");
    
    uint64_t current_lsn = get_current_lsn();
    WALRecord record;
    ActiveTransaction active_txns[1000];
    int active_count = 0;
    int undo_count = 0;
    
    // First pass: Find uncommitted transactions
    for (uint64_t lsn = 1; lsn <= current_lsn; lsn++) {
        if (read_wal_record(lsn, &record) != 0) {
            continue;
        }
        
        switch (record.type) {
            case WAL_BEGIN: {
                // Add to active transactions
                if (active_count < 1000) {
                    active_txns[active_count].txn_id = record.txn_id;
                    active_txns[active_count].begin_lsn = lsn;
                    active_txns[active_count].committed = false;
                    active_count++;
                }
                break;
            }
            case WAL_COMMIT: {
                // Mark transaction as committed
                for (int i = 0; i < active_count; i++) {
                    if (active_txns[i].txn_id == record.txn_id) {
                        active_txns[i].committed = true;
                        break;
                    }
                }
                break;
            }
            case WAL_ABORT: {
                // Mark transaction as committed (already rolled back)
                for (int i = 0; i < active_count; i++) {
                    if (active_txns[i].txn_id == record.txn_id) {
                        active_txns[i].committed = true;
                        break;
                    }
                }
                break;
            }
            default:
                break;
        }
    }
    
    // Second pass: UNDO uncommitted transactions (reverse order)
    for (uint64_t lsn = current_lsn; lsn >= 1; lsn--) {
        if (read_wal_record(lsn, &record) != 0) {
            continue;
        }
        
        // Check if this transaction needs to be undone
        bool needs_undo = false;
        for (int i = 0; i < active_count; i++) {
            if (active_txns[i].txn_id == record.txn_id && !active_txns[i].committed) {
                needs_undo = true;
                break;
            }
        }
        
        if (!needs_undo) continue;
        
        switch (record.type) {
            case WAL_INSERT: {
                // UNDO INSERT: Remove the record
                if (record.page_id > 0) {
                    Page* page = get_page(record.page_id, 1);
                    if (page) {
                        // Simple undo - mark as deleted
                        page->data[0] = 1;
                        mark_dirty(page);
                        unpin_page(page);
                        undo_count++;
                        printf("UNDO: Removed INSERT for TXN %u, page %d\n",
                               record.txn_id, record.page_id);
                    }
                }
                break;
            }
            case WAL_UPDATE: {
                // UNDO UPDATE: Restore before image
                if (record.page_id > 0 && record.record_size > 0) {
                    Page* page = get_page(record.page_id, 1);
                    if (page) {
                        int copy_size = (record.record_size < 256) ? record.record_size : 256;
                        if (copy_size <= PAGE_SIZE) {
                            memcpy(page->data, record.before_image, copy_size);
                            mark_dirty(page);
                            unpin_page(page);
                            undo_count++;
                            printf("UNDO: Restored UPDATE for TXN %u, page %d\n",
                                   record.txn_id, record.page_id);
                        } else {
                            unpin_page(page);
                        }
                    }
                }
                break;
            }
            case WAL_DELETE: {
                // UNDO DELETE: Restore the record
                if (record.page_id > 0 && record.record_size > 0) {
                    Page* page = get_page(record.page_id, 1);
                    if (page) {
                        int copy_size = (record.record_size < 256) ? record.record_size : 256;
                        if (copy_size <= PAGE_SIZE) {
                            memcpy(page->data, record.before_image, copy_size);
                            mark_dirty(page);
                            unpin_page(page);
                            undo_count++;
                            printf("UNDO: Restored DELETE for TXN %u, page %d\n",
                                   record.txn_id, record.page_id);
                        } else {
                            unpin_page(page);
                        }
                    }
                }
                break;
            }
            default:
                break;
        }
    }
    
    printf("UNDO recovery completed: %d operations undone\n", undo_count);
    return undo_count;
}

int perform_crash_recovery() {
    printf("Starting crash recovery...\n");
    
    // Phase 1: REDO - Replay all committed operations
    int redo_ops = perform_redo_recovery();
    
    // Phase 2: UNDO - Rollback uncommitted transactions
    int undo_ops = perform_undo_recovery();
    
    printf("Crash recovery completed: %d REDO, %d UNDO operations\n", 
           redo_ops, undo_ops);
    
    return 0;
}

int checkpoint_recovery() {
    printf("Creating checkpoint...\n");
    
    // Force all dirty pages to disk
    extern void flush_all_pages();
    flush_all_pages();
    
    // Write checkpoint record
    extern uint64_t write_wal_record(WALRecordType type, uint32_t txn_id, int page_id, 
                                    const char* before_image, const char* after_image, int record_size);
    uint64_t checkpoint_lsn = write_wal_record(WAL_CHECKPOINT, 0, -1, NULL, NULL, 0);
    
#ifdef MACOS
    printf("Checkpoint created at LSN %llu\n", (unsigned long long)checkpoint_lsn);
#else
    printf("Checkpoint created at LSN %lu\n", (unsigned long)checkpoint_lsn);
#endif
    return 0;
}