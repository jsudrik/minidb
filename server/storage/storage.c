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
    
    printf("METADATA: Writing system table record to page %d, size %d\n", sys_page_ids[table_id], record_size);
    
    Page* page = get_page(sys_page_ids[table_id], 1); // System transaction
    if (!page) {
        printf("METADATA: Failed to get page %d\n", sys_page_ids[table_id]);
        return -1;
    }
    
    DataPage* data_page = (DataPage*)page->data;
    
    printf("METADATA: Page %d current record_count: %d\n", sys_page_ids[table_id], data_page->record_count);
    
    if (data_page->record_count * record_size >= sizeof(data_page->records)) {
        printf("METADATA: Page %d full, cannot add record\n", sys_page_ids[table_id]);
        unpin_page(page);
        return -1;
    }
    
    memcpy(data_page->records + (data_page->record_count * record_size), 
           record, record_size);
    data_page->record_count++;
    
    printf("METADATA: Added record to page %d, new count: %d\n", sys_page_ids[table_id], data_page->record_count);
    
    mark_dirty(page);
    
    // Force flush system catalog to disk for persistence
    extern void flush_all_pages();
    flush_all_pages();
    printf("METADATA: Flushed all pages to disk\n");
    
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
    
    int current_page_id = table->table_id;
    Page* page = get_page(current_page_id, txn_id);
    if (!page) return -1;
    
    DataPage* data_page = (DataPage*)page->data;
    int record_size = calculate_record_size(table->columns, table->column_count);
    
    // Find page with space
    while ((data_page->record_count + 1) * record_size >= sizeof(data_page->records)) {
        if (data_page->next_page == -1) {
            // Need new page
            int new_page_id = allocate_page();
            if (new_page_id < 0) {
                unpin_page(page);
                return -1;
            }
            
            data_page->next_page = new_page_id;
            mark_dirty(page);
            unpin_page(page);
            
            current_page_id = new_page_id;
            page = get_page(current_page_id, txn_id);
            if (!page) return -1;
            
            data_page = (DataPage*)page->data;
            data_page->record_count = 0;
            data_page->next_page = -1;
            data_page->deleted_count = 0;
            
            printf("INSERT: Allocated new page %d\n", new_page_id);
            break;
        } else {
            // Move to next page
            unpin_page(page);
            current_page_id = data_page->next_page;
            page = get_page(current_page_id, txn_id);
            if (!page) return -1;
            data_page = (DataPage*)page->data;
        }
    }
    
    char record_buffer[512];
    serialize_record(table->columns, table->column_count, values, record_buffer);
    
    // WAL log to correct current page
    extern uint64_t wal_log_insert(uint32_t txn_id, int page_id, const char* record, int record_size);
    if (record_size > 0 && record_size < 512) {
        wal_log_insert(txn_id, current_page_id, record_buffer, record_size);
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
    
    // Process WHERE clause if provided
    for (int row = 0; row < data_page->record_count; row++) {
        char* record_ptr = data_page->records + (row * record_size);
        Value record_values[MAX_COLUMNS];
        bool deleted;
        
        deserialize_record(table->columns, table->column_count, record_ptr, record_values, &deleted);
        
        if (!deleted) {
            bool should_update = true;
            
            // Apply WHERE clause filter if provided
            if (where_clause && strlen(where_clause) > 0) {
                should_update = false;
                // Parse WHERE clause with operators
                char where_col[64], where_val[256], op[3];
                if (sscanf(where_clause, "%s >= '%[^']'", where_col, where_val) == 2) { strcpy(op, ">="); }
                else if (sscanf(where_clause, "%s <= '%[^']'", where_col, where_val) == 2) { strcpy(op, "<="); }
                else if (sscanf(where_clause, "%s > '%[^']'", where_col, where_val) == 2) { strcpy(op, ">"); }
                else if (sscanf(where_clause, "%s < '%[^']'", where_col, where_val) == 2) { strcpy(op, "<"); }
                else if (sscanf(where_clause, "%s = '%[^']'", where_col, where_val) == 2) { strcpy(op, "="); }
                else if (sscanf(where_clause, "%s >= %s", where_col, where_val) == 2) { strcpy(op, ">="); }
                else if (sscanf(where_clause, "%s <= %s", where_col, where_val) == 2) { strcpy(op, "<="); }
                else if (sscanf(where_clause, "%s > %s", where_col, where_val) == 2) { strcpy(op, ">"); }
                else if (sscanf(where_clause, "%s < %s", where_col, where_val) == 2) { strcpy(op, "<"); }
                else if (sscanf(where_clause, "%s = %s", where_col, where_val) == 2) { strcpy(op, "="); }
                else { op[0] = '\0'; }
                
                if (op[0] != '\0') {
                    // Find WHERE column
                    for (int i = 0; i < table->column_count; i++) {
                        if (strcasecmp(table->columns[i].name, where_col) == 0) {
                            if (table->columns[i].type == TYPE_INT) {
                                int where_int = atoi(where_val);
                                int row_val = record_values[i].int_val;
                                if (strcmp(op, "=") == 0) should_update = (row_val == where_int);
                                else if (strcmp(op, ">") == 0) should_update = (row_val > where_int);
                                else if (strcmp(op, "<") == 0) should_update = (row_val < where_int);
                                else if (strcmp(op, ">=") == 0) should_update = (row_val >= where_int);
                                else if (strcmp(op, "<=") == 0) should_update = (row_val <= where_int);
                            } else {
                                if (strcmp(op, "=") == 0) {
                                    should_update = (strcmp(record_values[i].string_val, where_val) == 0);
                                }
                            }
                            break;
                        }
                    }
                }
            }
            
            if (should_update) {
                // Save before image for WAL
                char before_image[512];
                memcpy(before_image, record_ptr, record_size);
                
                record_values[col_idx] = *value;
                serialize_record(table->columns, table->column_count, record_values, record_ptr);
                
                // Enable WAL logging for UPDATE operations
                extern uint64_t wal_log_update(uint32_t txn_id, int page_id, const char* before, const char* after, int record_size);
                if (record_size > 0 && record_size < 512) {
                    wal_log_update(txn_id, data_page_id, before_image, record_ptr, record_size);
                }
                
                updated_count++;
            }
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
    
    // Process WHERE clause if provided
    for (int row = 0; row < data_page->record_count; row++) {
        char* record_ptr = data_page->records + (row * record_size);
        if (record_ptr[0] == 0) { // Not already deleted
            bool should_delete = true;
            
            // Apply WHERE clause filter if provided
            if (where_clause && strlen(where_clause) > 0) {
                should_delete = false;
                Value record_values[MAX_COLUMNS];
                bool deleted;
                
                deserialize_record(table->columns, table->column_count, record_ptr, record_values, &deleted);
                
                // Parse WHERE clause with operators
                char where_col[64], where_val[256], op[3];
                if (sscanf(where_clause, "%s >= '%[^']'", where_col, where_val) == 2) { strcpy(op, ">="); }
                else if (sscanf(where_clause, "%s <= '%[^']'", where_col, where_val) == 2) { strcpy(op, "<="); }
                else if (sscanf(where_clause, "%s > '%[^']'", where_col, where_val) == 2) { strcpy(op, ">"); }
                else if (sscanf(where_clause, "%s < '%[^']'", where_col, where_val) == 2) { strcpy(op, "<"); }
                else if (sscanf(where_clause, "%s = '%[^']'", where_col, where_val) == 2) { strcpy(op, "="); }
                else if (sscanf(where_clause, "%s >= %s", where_col, where_val) == 2) { strcpy(op, ">="); }
                else if (sscanf(where_clause, "%s <= %s", where_col, where_val) == 2) { strcpy(op, "<="); }
                else if (sscanf(where_clause, "%s > %s", where_col, where_val) == 2) { strcpy(op, ">"); }
                else if (sscanf(where_clause, "%s < %s", where_col, where_val) == 2) { strcpy(op, "<"); }
                else if (sscanf(where_clause, "%s = %s", where_col, where_val) == 2) { strcpy(op, "="); }
                else { op[0] = '\0'; }
                
                if (op[0] != '\0') {
                    // Find WHERE column
                    for (int i = 0; i < table->column_count; i++) {
                        if (strcasecmp(table->columns[i].name, where_col) == 0) {
                            if (table->columns[i].type == TYPE_INT) {
                                int where_int = atoi(where_val);
                                int row_val = record_values[i].int_val;
                                if (strcmp(op, "=") == 0) should_delete = (row_val == where_int);
                                else if (strcmp(op, ">") == 0) should_delete = (row_val > where_int);
                                else if (strcmp(op, "<") == 0) should_delete = (row_val < where_int);
                                else if (strcmp(op, ">=") == 0) should_delete = (row_val >= where_int);
                                else if (strcmp(op, "<=") == 0) should_delete = (row_val <= where_int);
                            } else {
                                if (strcmp(op, "=") == 0) {
                                    should_delete = (strcmp(record_values[i].string_val, where_val) == 0);
                                }
                            }
                            break;
                        }
                    }
                }
            }
            
            if (should_delete) {
                // Save before image for WAL
                char before_image[512];
                memcpy(before_image, record_ptr, record_size);
                
                // Enable WAL logging for DELETE operations
                extern uint64_t wal_log_delete(uint32_t txn_id, int page_id, const char* record, int record_size);
                if (record_size > 0 && record_size < 512) {
                    wal_log_delete(txn_id, data_page_id, before_image, record_size);
                }
                
                record_ptr[0] = 1; // Mark as deleted
                deleted_count++;
            }
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
    
    result->column_count = table->column_count;
    for (int i = 0; i < table->column_count; i++) {
        result->columns[i] = table->columns[i];
    }
    
    int record_size = calculate_record_size(table->columns, table->column_count);
    
    // Fix for recovery: always use WAL record size if available
    extern int g_recovery_record_size;
    if (g_recovery_record_size > 0) {
        record_size = g_recovery_record_size;
        printf("SELECT: Using recovery record_size=%d (calculated=%d)\n", record_size, calculate_record_size(table->columns, table->column_count));
    }
    
    int result_row = 0;
    int current_page_id = table->table_id;
    int page_count = 0;
    
    // Scan all pages in the chain
    while (current_page_id != -1 && result_row < MAX_RESULT_ROWS) {
        Page* page = get_page(current_page_id, txn_id);
        if (!page) break;
        
        DataPage* data_page = (DataPage*)page->data;
        page_count++;
        
        printf("SCAN: Page %d has %d records\n", current_page_id, data_page->record_count);
        
        for (int row = 0; row < data_page->record_count && result_row < MAX_RESULT_ROWS; row++) {
            const char* record_ptr = data_page->records + (row * record_size);
            bool deleted;
            
            deserialize_record(table->columns, table->column_count, record_ptr, result->data[result_row], &deleted);
            
            if (!deleted) {
                result_row++;
            }
        }
        
        current_page_id = data_page->next_page;
        unpin_page(page);
    }
    
    result->row_count = result_row;
    printf("scan_table: Found %d rows across %d pages for table %s\n", result_row, page_count, table_name);
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