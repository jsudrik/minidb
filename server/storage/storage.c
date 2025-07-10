#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include "../../common/types.h"
#include "../../common/wal_types.h"
#include "../../common/row_format.h"

/*
 * Row Storage Format:
 * See common/row_format.h for detailed documentation
 * 
 * Current implementation uses simple format:
 * [FLAGS:1][FIELD1:4][FIELD2:VAR]...
 * 
 * FLAGS byte contains delete/update status
 * Fields are stored in column order as defined in table schema
 */

extern Page* get_page(int page_id, uint32_t txn_id);
extern void unpin_page(Page* page);
extern void mark_dirty(Page* page);
extern int allocate_page();
extern int create_table_catalog(const char* table_name, Column* columns, int column_count);
extern int drop_table_catalog(const char* table_name);
extern int create_index_catalog(const char* index_name, int table_id, const char* column_name, int index_type, int root_page_id);
extern int drop_index_catalog(const char* index_name);
extern Table* find_table_by_name(const char* name);

typedef struct {
    int record_count;
    int next_page;
    int deleted_count;
    char records[PAGE_SIZE - 12];
} DataPage;

typedef struct {
    int key_count;
    int is_leaf;
    int parent;
    struct {
        Value key;
        int page_id;
    } entries[100];
    int children[101];
} BTreePage;

typedef struct {
    int bucket_count;
    struct {
        Value key;
        int record_id;
        int next_bucket;
        bool deleted;
    } buckets[200];
} HashPage;

int write_system_table_record(int table_id, const void* record, int record_size) {
    static int sys_page_ids[5] = {1, 2, 3, 4, 5};
    
    Page* page = get_page(sys_page_ids[table_id], 1); // System transaction
    if (!page) return -1;
    
    DataPage* data_page = (DataPage*)page->data;
    
    if (data_page->record_count * record_size >= sizeof(data_page->records)) {
        unpin_page(page);
        return -1;
    }
    
    memcpy(data_page->records + (data_page->record_count * record_size), 
           record, record_size);
    data_page->record_count++;
    
    mark_dirty(page);
    unpin_page(page);
    return 0;
}

int create_table_storage(const char* table_name, Column* columns, int column_count, uint32_t txn_id) {
    int table_id = create_table_catalog(table_name, columns, column_count);
    if (table_id < 0) return -1;
    
    int page_id = allocate_page();
    Page* page = get_page(page_id, txn_id);
    if (!page) return -1;
    
    DataPage* data_page = (DataPage*)page->data;
    data_page->record_count = 0;
    data_page->next_page = -1;
    data_page->deleted_count = 0;
    
    mark_dirty(page);
    unpin_page(page);
    
    printf("Table %s created with table_id %d, data_page_id %d\n", 
           table_name, table_id, page_id);
    return table_id;
}

int drop_table_storage(const char* table_name, uint32_t txn_id) {
    Table* table = find_table_by_name(table_name);
    if (!table) return -1;
    
    // In real system would deallocate all pages
    int ret = drop_table_catalog(table_name);
    
    printf("Table %s dropped\n", table_name);
    return ret;
}

int calculate_record_size(Column* columns, int column_count) {
    int size = 1; // Delete flag
    for (int i = 0; i < column_count; i++) {
        switch (columns[i].type) {
            case TYPE_INT:
                size += 4;
                break;
            case TYPE_BIGINT:
                size += 8;
                break;
            case TYPE_FLOAT:
                size += 4;
                break;
            case TYPE_CHAR:
            case TYPE_VARCHAR:
                size += columns[i].size + 1;
                break;
        }
    }
    return size;
}

int serialize_record(Column* columns, int column_count, Value* values, char* buffer) {
    int offset = 0;
    
    // Delete flag
    buffer[offset++] = 0; // Not deleted
    
    for (int i = 0; i < column_count; i++) {
        switch (columns[i].type) {
            case TYPE_INT:
                memcpy(buffer + offset, &values[i].int_val, 4);
                offset += 4;
                break;
            case TYPE_BIGINT:
                memcpy(buffer + offset, &values[i].bigint_val, 8);
                offset += 8;
                break;
            case TYPE_FLOAT:
                memcpy(buffer + offset, &values[i].float_val, 4);
                offset += 4;
                break;
            case TYPE_CHAR:
            case TYPE_VARCHAR:
                strcpy(buffer + offset, values[i].string_val);
                offset += strlen(values[i].string_val) + 1;
                break;
        }
    }
    
    return offset;
}

int deserialize_record(Column* columns, int column_count, const char* buffer, Value* values, bool* deleted) {
    int offset = 0;
    
    // Delete flag
    *deleted = buffer[offset++];
    
    for (int i = 0; i < column_count; i++) {
        switch (columns[i].type) {
            case TYPE_INT:
                memcpy(&values[i].int_val, buffer + offset, 4);
                offset += 4;
                break;
            case TYPE_BIGINT:
                memcpy(&values[i].bigint_val, buffer + offset, 8);
                offset += 8;
                break;
            case TYPE_FLOAT:
                memcpy(&values[i].float_val, buffer + offset, 4);
                offset += 4;
                break;
            case TYPE_CHAR:
            case TYPE_VARCHAR:
                strcpy(values[i].string_val, buffer + offset);
                offset += strlen(buffer + offset) + 1;
                break;
        }
    }
    
    return offset;
}

int insert_record(const char* table_name, Value* values, int value_count, uint32_t txn_id) {
    Table* table = find_table_by_name(table_name);
    if (!table) return -1;
    
    int data_page_id = table->table_id;
    Page* page = get_page(data_page_id, txn_id);
    if (!page) return -1;
    
    DataPage* data_page = (DataPage*)page->data;
    int record_size = calculate_record_size(table->columns, table->column_count);
    
    if ((data_page->record_count + 1) * record_size >= sizeof(data_page->records)) {
        unpin_page(page);
        return -1;
    }
    
    char record_buffer[512];
    serialize_record(table->columns, table->column_count, values, record_buffer);
    
    // Enable WAL logging for data persistence
    extern uint64_t wal_log_insert(uint32_t txn_id, int page_id, const char* record, int record_size);
    if (record_size > 0 && record_size < 512) {
        wal_log_insert(txn_id, data_page_id, record_buffer, record_size);
    }
    
    memcpy(data_page->records + (data_page->record_count * record_size), 
           record_buffer, record_size);
    data_page->record_count++;
    
    mark_dirty(page);
    unpin_page(page);
    
    return 0;
}

int update_record(const char* table_name, const char* column, Value* value, const char* where_clause, uint32_t txn_id) {
    Table* table = find_table_by_name(table_name);
    if (!table) return -1;
    
    int data_page_id = table->table_id;
    Page* page = get_page(data_page_id, txn_id);
    if (!page) return -1;
    
    DataPage* data_page = (DataPage*)page->data;
    int record_size = calculate_record_size(table->columns, table->column_count);
    int updated_count = 0;
    
    // Find column index
    int col_idx = -1;
    for (int i = 0; i < table->column_count; i++) {
        if (strcasecmp(table->columns[i].name, column) == 0) {
            col_idx = i;
            break;
        }
    }
    
    if (col_idx == -1) {
        unpin_page(page);
        return -1;
    }
    
    // Simple update - update all records (no WHERE clause processing for simplicity)
    for (int row = 0; row < data_page->record_count; row++) {
        char* record_ptr = data_page->records + (row * record_size);
        Value record_values[MAX_COLUMNS];
        bool deleted;
        
        deserialize_record(table->columns, table->column_count, record_ptr, record_values, &deleted);
        
        if (!deleted) {
            // Save before image for WAL
            char before_image[512];
            memcpy(before_image, record_ptr, record_size);
            
            record_values[col_idx] = *value;
            serialize_record(table->columns, table->column_count, record_values, record_ptr);
            
            // Skip WAL logging for debugging
            // extern uint64_t wal_log_update(uint32_t txn_id, int page_id, const char* before, const char* after, int record_size);
            // if (record_size > 0 && record_size < 512) {
            //     wal_log_update(txn_id, data_page_id, before_image, record_ptr, record_size);
            // }
            
            updated_count++;
        }
    }
    
    if (updated_count > 0) {
        mark_dirty(page);
    }
    unpin_page(page);
    
    return updated_count;
}

int delete_record(const char* table_name, const char* where_clause, uint32_t txn_id) {
    Table* table = find_table_by_name(table_name);
    if (!table) return -1;
    
    int data_page_id = table->table_id;
    Page* page = get_page(data_page_id, txn_id);
    if (!page) return -1;
    
    DataPage* data_page = (DataPage*)page->data;
    int record_size = calculate_record_size(table->columns, table->column_count);
    int deleted_count = 0;
    
    // Simple delete - mark all records as deleted (no WHERE clause processing)
    for (int row = 0; row < data_page->record_count; row++) {
        char* record_ptr = data_page->records + (row * record_size);
        if (record_ptr[0] == 0) { // Not already deleted
            // Save before image for WAL
            char before_image[512];
            memcpy(before_image, record_ptr, record_size);
            
            // Skip WAL logging for debugging
            // extern uint64_t wal_log_delete(uint32_t txn_id, int page_id, const char* record, int record_size);
            // if (record_size > 0 && record_size < 512) {
            //     wal_log_delete(txn_id, data_page_id, before_image, record_size);
            // }
            
            record_ptr[0] = 1; // Mark as deleted
            deleted_count++;
        }
    }
    
    data_page->deleted_count += deleted_count;
    
    if (deleted_count > 0) {
        mark_dirty(page);
    }
    unpin_page(page);
    
    return deleted_count;
}

int scan_table(const char* table_name, QueryResult* result, uint32_t txn_id) {
    Table* table = find_table_by_name(table_name);
    if (!table) return -1;
    
    int data_page_id = table->table_id;
    Page* page = get_page(data_page_id, txn_id);
    if (!page) return -1;
    
    DataPage* data_page = (DataPage*)page->data;
    
    result->column_count = table->column_count;
    for (int i = 0; i < table->column_count; i++) {
        result->columns[i] = table->columns[i];
    }
    
    int record_size = calculate_record_size(table->columns, table->column_count);
    
    // Fix for recovery: use actual WAL record size if available
    extern int g_recovery_record_size;
    if (record_size < 15 && data_page->record_count > 0 && g_recovery_record_size > 0) {
        record_size = g_recovery_record_size;
        printf("SELECT: Using recovery record_size=%d\n", record_size);
    }
    
    int result_row = 0;
    
    for (int row = 0; row < data_page->record_count && result_row < MAX_RESULT_ROWS; row++) {
        const char* record_ptr = data_page->records + (row * record_size);
        bool deleted;
        
        deserialize_record(table->columns, table->column_count, record_ptr, result->data[result_row], &deleted);
        
        if (!deleted) {
            result_row++;
        }
    }
    
    result->row_count = result_row;
    printf("scan_table: Found %d rows for table %s\n", result_row, table_name);
    unpin_page(page);
    return result->row_count;
}

int create_btree_index(const char* index_name, const char* table_name, const char* column_name, uint32_t txn_id) {
    Table* table = find_table_by_name(table_name);
    if (!table) return -1;
    
    int root_page_id = allocate_page();
    Page* page = get_page(root_page_id, txn_id);
    if (!page) return -1;
    
    BTreePage* btree_page = (BTreePage*)page->data;
    btree_page->key_count = 0;
    btree_page->is_leaf = 1;
    btree_page->parent = -1;
    
    mark_dirty(page);
    unpin_page(page);
    
    int index_id = create_index_catalog(index_name, table->table_id, column_name, INDEX_BTREE, root_page_id);
    
    printf("B-Tree index %s created with index_id %d, root_page_id %d\n", 
           index_name, index_id, root_page_id);
    return index_id;
}

int create_hash_index(const char* index_name, const char* table_name, const char* column_name, uint32_t txn_id) {
    Table* table = find_table_by_name(table_name);
    if (!table) return -1;
    
    int root_page_id = allocate_page();
    Page* page = get_page(root_page_id, txn_id);
    if (!page) return -1;
    
    HashPage* hash_page = (HashPage*)page->data;
    hash_page->bucket_count = 0;
    
    mark_dirty(page);
    unpin_page(page);
    
    int index_id = create_index_catalog(index_name, table->table_id, column_name, INDEX_HASH, root_page_id);
    
    printf("Hash index %s created with index_id %d, root_page_id %d\n", 
           index_name, index_id, root_page_id);
    return index_id;
}

int drop_index_storage(const char* index_name, uint32_t txn_id) {
    // In real system would deallocate index pages
    int ret = drop_index_catalog(index_name);
    
    printf("Index %s dropped\n", index_name);
    return ret;
}