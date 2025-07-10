#include <stdio.h>
#include <string.h>
#include "../../common/types.h"
#include "../../common/wal_types.h"
#include "../../common/row_format.h"

// DataPage structure definition
typedef struct {
    int record_count;
    int next_page;
    int deleted_count;
    char records[PAGE_SIZE - 12];
} DataPage;

extern Page* get_page(int page_id, uint32_t txn_id);
extern void unpin_page(Page* page);

void dump_page_contents(int page_id, const char* label) {
    printf("\n=== PAGE DUMP: %s (Page ID: %d) ===\n", label, page_id);
    
    Page* page = get_page(page_id, 1);
    if (!page) {
        printf("ERROR: Could not get page %d\n", page_id);
        return;
    }
    
    DataPage* data_page = (DataPage*)page->data;
    
    printf("Record Count: %d\n", data_page->record_count);
    printf("Next Page: %d\n", data_page->next_page);
    printf("Deleted Count: %d\n", data_page->deleted_count);
    
    // Dump first 200 bytes of records area as hex
    printf("Records Data (first 200 bytes):\n");
    for (int i = 0; i < 200 && i < sizeof(data_page->records); i += 16) {
        printf("%04x: ", i);
        for (int j = 0; j < 16 && (i + j) < 200; j++) {
            printf("%02x ", (unsigned char)data_page->records[i + j]);
        }
        printf(" | ");
        for (int j = 0; j < 16 && (i + j) < 200; j++) {
            char c = data_page->records[i + j];
            printf("%c", (c >= 32 && c <= 126) ? c : '.');
        }
        printf("\n");
    }
    
    // Generic record display without assumptions
    if (data_page->record_count > 0) {
        printf("\nRecord Count: %d (use dump_data_row() for detailed parsing)\n", data_page->record_count);
    }
    
    printf("=== END PAGE DUMP ===\n\n");
    unpin_page(page);
}

void dump_wal_record(WALRecord* record, const char* label) {
    printf("\n=== WAL RECORD DUMP: %s ===\n", label);
    printf("Type: %d, TXN ID: %u, LSN: %llu\n", record->type, record->txn_id, (unsigned long long)record->lsn);
    printf("Page ID: %d, Record Size: %d\n", record->page_id, record->record_size);
    
    if (record->record_size > 0 && record->record_size <= 256) {
        printf("After Image (first 64 bytes):\n");
        for (int i = 0; i < 64 && i < record->record_size; i += 16) {
            printf("%04x: ", i);
            for (int j = 0; j < 16 && (i + j) < record->record_size; j++) {
                printf("%02x ", (unsigned char)record->after_image[i + j]);
            }
            printf(" | ");
            for (int j = 0; j < 16 && (i + j) < record->record_size; j++) {
                char c = record->after_image[i + j];
                printf("%c", (c >= 32 && c <= 126) ? c : '.');
            }
            printf("\n");
        }
    }
    printf("=== END WAL RECORD DUMP ===\n\n");
}

void dump_data_row(int page_id, int row_index, int record_size, const char* label) {
    printf("\n=== DATA ROW DUMP: %s (Page %d, Row %d) ===\n", label, page_id, row_index);
    
    Page* page = get_page(page_id, 1);
    if (!page) {
        printf("ERROR: Could not get page %d\n", page_id);
        return;
    }
    
    DataPage* data_page = (DataPage*)page->data;
    
    if (row_index >= data_page->record_count) {
        printf("ERROR: Row %d does not exist (page has %d records)\n", row_index, data_page->record_count);
        unpin_page(page);
        return;
    }
    
    char* record_ptr = data_page->records + (row_index * record_size);
    
    printf("Record Size: %d bytes\n", record_size);
    printf("Raw Data:\n");
    
    // Hex dump of the record
    for (int i = 0; i < record_size; i += 16) {
        printf("%04x: ", i);
        for (int j = 0; j < 16 && (i + j) < record_size; j++) {
            printf("%02x ", (unsigned char)record_ptr[i + j]);
        }
        printf(" | ");
        for (int j = 0; j < 16 && (i + j) < record_size; j++) {
            char c = record_ptr[i + j];
            printf("%c", (c >= 32 && c <= 126) ? c : '.');
        }
        printf("\n");
    }
    
    // Row header interpretation
    RowHeader* header = ROW_HEADER_PTR(record_ptr);
    printf("\nRow Header:\n");
    printf("Flags: 0x%02x\n", header->flags);
    printf("  Deleted: %s\n", ROW_IS_DELETED(header) ? "YES" : "NO");
    printf("  Updated: %s\n", ROW_IS_UPDATED(header) ? "YES" : "NO");
    
    // Field data interpretation
    char* data_ptr = ROW_DATA_PTR(record_ptr);
    printf("\nField Data:\n");
    if (record_size >= 5) {
        int* int_field = (int*)data_ptr;
        printf("Field 1 (int): %d\n", *int_field);
        data_ptr += 4;
    }
    if (record_size > 5) {
        printf("Field 2+ (string): '%.20s'\n", data_ptr);
    }
    
    printf("=== END DATA ROW DUMP ===\n\n");
    unpin_page(page);
}

void dump_row_header(const char* row_ptr, int record_size, const char* label) {
    printf("\n=== ROW HEADER DUMP: %s ===\n", label);
    
    RowHeader* header = ROW_HEADER_PTR(row_ptr);
    printf("Row Size: %d bytes\n", record_size);
    printf("Header Flags: 0x%02x\n", header->flags);
    printf("  Deleted: %s\n", ROW_IS_DELETED(header) ? "YES" : "NO");
    printf("  Updated: %s\n", ROW_IS_UPDATED(header) ? "YES" : "NO");
    
    // Quick hex dump of first 32 bytes
    printf("Raw Data (first 32 bytes):\n");
    for (int i = 0; i < 32 && i < record_size; i += 8) {
        printf("%04x: ", i);
        for (int j = 0; j < 8 && (i + j) < record_size && (i + j) < 32; j++) {
            printf("%02x ", (unsigned char)row_ptr[i + j]);
        }
        printf("\n");
    }
    
    printf("=== END ROW HEADER DUMP ===\n\n");
}

void dump_index_row(const char* row_ptr, int row_type, const char* label) {
    printf("\n=== INDEX ROW DUMP: %s ===\n", label);
    
    RowHeader* header = ROW_HEADER_PTR(row_ptr);
    printf("Header Flags: 0x%02x\n", header->flags);
    printf("  Deleted: %s\n", ROW_IS_DELETED(header) ? "YES" : "NO");
    printf("  Updated: %s\n", ROW_IS_UPDATED(header) ? "YES" : "NO");
    printf("  Leaf Node: %s\n", ROW_IS_INDEX_LEAF(header) ? "YES" : "NO");
    printf("  Overflow: %s\n", ROW_IS_INDEX_OVERFLOW(header) ? "YES" : "NO");
    
    if (row_type == INDEX_BTREE) {
        BTreeIndexRow* btree_row = (BTreeIndexRow*)row_ptr;
        printf("\nB-Tree Index Row:\n");
        printf("Key Value (int): %d\n", btree_row->key.int_val);
        printf("Key Value (str): '%.20s'\n", btree_row->key.string_val);
        printf("Page ID: %d\n", btree_row->page_id);
        printf("Next Entry: %d\n", btree_row->next_entry);
    } else if (row_type == INDEX_HASH) {
        HashIndexRow* hash_row = (HashIndexRow*)row_ptr;
        printf("\nHash Index Row:\n");
        printf("Key Value (int): %d\n", hash_row->key.int_val);
        printf("Key Value (str): '%.20s'\n", hash_row->key.string_val);
        printf("Record ID: %d\n", hash_row->record_id);
        printf("Next Bucket: %d\n", hash_row->next_bucket);
        printf("Hash Value: 0x%08x\n", hash_row->hash_value);
    }
    
    printf("=== END INDEX ROW DUMP ===\n\n");
}