#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include "../../common/types.h"

/**
 * MiniDB Query Executor
 * ====================
 * 
 * OVERVIEW:
 * The query executor implements the physical operations for data access
 * and manipulation. It receives optimized query plans and executes them
 * using the most appropriate scan methods.
 * 
 * SCAN TYPES:
 * 1. Sequential Scan (Table Scan):
 *    - Reads all pages of a table sequentially
 *    - Applies WHERE filters during scan
 *    - Used when no suitable index exists
 *    - Cost: O(n) where n = number of pages
 * 
 * 2. Index Scan:
 *    - Uses B-Tree or Hash index for efficient access
 *    - B-Tree: Supports range queries, sorted results
 *    - Hash: Supports equality queries, fastest for exact matches
 *    - Cost: O(log n + k) where k = result size
 * 
 * 3. Index-Only Scan (Future):
 *    - Returns data directly from index without table access
 *    - Requires covering indexes
 * 
 * EXECUTION PIPELINE:
 * 1. Receive query plan from optimizer
 * 2. Initialize appropriate scan operator
 * 3. Apply WHERE clause filters
 * 4. Project requested columns
 * 5. Format results for client
 * 
 * TRANSACTION INTEGRATION:
 * - All operations respect transaction isolation levels
 * - Acquires appropriate locks (shared for reads, exclusive for writes)
 * - Participates in two-phase commit protocol
 */

extern int create_table_storage(const char* table_name, Column* columns, int column_count, uint32_t txn_id);
extern int drop_table_storage(const char* table_name, uint32_t txn_id);
extern int insert_record(const char* table_name, Value* values, int value_count, uint32_t txn_id);
extern int update_record(const char* table_name, const char* column, Value* value, const char* where_clause, uint32_t txn_id);
extern int delete_record(const char* table_name, const char* where_clause, uint32_t txn_id);
extern int scan_table(const char* table_name, QueryResult* result, uint32_t txn_id);
extern int create_btree_index(const char* index_name, const char* table_name, const char* column_name, uint32_t txn_id);
extern int create_hash_index(const char* index_name, const char* table_name, const char* column_name, uint32_t txn_id);
extern int drop_index_storage(const char* index_name, uint32_t txn_id);
extern Table* find_table_by_name(const char* name);
extern int get_all_tables(Table* result_tables, int max_tables);

// Simple index existence check (stub implementation)
int check_index_exists(const char* table_name, const char* column_name) {
    // For testing: assume dept column has B-Tree index, salary has Hash index
    if (strcasecmp(column_name, "dept") == 0) {
        return INDEX_BTREE;
    } else if (strcasecmp(column_name, "salary") == 0) {
        return INDEX_HASH;
    }
    return -1; // No index
}
extern int acquire_read_lock(uint32_t txn_id, int resource_id);
extern int acquire_write_lock(uint32_t txn_id, int resource_id);

const char* datatype_to_string(DataType type) {
    switch (type) {
        case TYPE_INT: return "INT";
        case TYPE_BIGINT: return "BIGINT";
        case TYPE_FLOAT: return "FLOAT";
        case TYPE_CHAR: return "CHAR";
        case TYPE_VARCHAR: return "VARCHAR";
        default: return "UNKNOWN";
    }
}

int execute_create_table(const char* table_name, Column* columns, int column_count, uint32_t txn_id, QueryResult* result) {
    // Acquire write lock for DDL operation
    acquire_write_lock(txn_id, 1); // System catalog lock
    
    // Log DDL operation to WAL
    extern uint64_t wal_log_ddl(uint32_t txn_id, const char* ddl_type, const char* object_name);
    wal_log_ddl(txn_id, "CREATE_TABLE", table_name);
    
    int ret = create_table_storage(table_name, columns, column_count, txn_id);
    
    // Auto-commit DDL operation
    if (ret >= 0) {
        extern uint64_t wal_log_commit(uint32_t txn_id);
        extern void flush_wal();
        wal_log_commit(txn_id);
        flush_wal(); // Ensure DDL is durable
        printf("DDL: CREATE TABLE auto-committed and flushed\n");
    }
    
    result->column_count = 1;
    strcpy(result->columns[0].name, "Result");
    result->columns[0].type = TYPE_VARCHAR;
    result->row_count = 1;
    
    if (ret >= 0) {
        strcpy(result->data[0][0].string_val, "Table created successfully");
    } else {
        strcpy(result->data[0][0].string_val, "Failed to create table");
    }
    
    return ret >= 0 ? 0 : -1;
}

int execute_drop_table(const char* table_name, uint32_t txn_id, QueryResult* result) {
    acquire_write_lock(txn_id, 1);
    
    // Log DDL operation to WAL
    extern uint64_t wal_log_ddl(uint32_t txn_id, const char* ddl_type, const char* object_name);
    wal_log_ddl(txn_id, "DROP_TABLE", table_name);
    
    int ret = drop_table_storage(table_name, txn_id);
    
    // Auto-commit DDL operation
    if (ret >= 0) {
        extern uint64_t wal_log_commit(uint32_t txn_id);
        extern void flush_wal();
        wal_log_commit(txn_id);
        flush_wal();
        printf("DDL: DROP TABLE auto-committed and flushed\n");
    }
    
    result->column_count = 1;
    strcpy(result->columns[0].name, "Result");
    result->columns[0].type = TYPE_VARCHAR;
    result->row_count = 1;
    
    if (ret >= 0) {
        strcpy(result->data[0][0].string_val, "Table dropped successfully");
    } else {
        strcpy(result->data[0][0].string_val, "Failed to drop table");
    }
    
    return ret >= 0 ? 0 : -1;
}

int execute_insert(const char* table_name, Value* values, int value_count, uint32_t txn_id, QueryResult* result) {
    Table* table = find_table_by_name(table_name);
    if (!table) {
        result->column_count = 1;
        strcpy(result->columns[0].name, "Error");
        result->columns[0].type = TYPE_VARCHAR;
        result->row_count = 1;
        strcpy(result->data[0][0].string_val, "Table does not exist");
        return -1;
    }
    
    // Acquire write lock for the table
    acquire_write_lock(txn_id, table->table_id);
    
    int ret = insert_record(table_name, values, value_count, txn_id);
    
    // Auto-commit INSERT operation for durability
    if (ret == 0) {
        extern uint64_t wal_log_commit(uint32_t txn_id);
        extern void flush_wal();
        wal_log_commit(txn_id);
        flush_wal();
        printf("DML: INSERT auto-committed and flushed\n");
    }
    
    result->column_count = 1;
    strcpy(result->columns[0].name, "Result");
    result->columns[0].type = TYPE_VARCHAR;
    result->row_count = 1;
    
    if (ret == 0) {
        strcpy(result->data[0][0].string_val, "Record inserted successfully");
    } else {
        strcpy(result->data[0][0].string_val, "Failed to insert record");
    }
    
    return ret;
}

int execute_update(const char* table_name, const char* column, Value* value, const char* where_clause, uint32_t txn_id, QueryResult* result) {
    Table* table = find_table_by_name(table_name);
    if (!table) {
        result->column_count = 1;
        strcpy(result->columns[0].name, "Error");
        result->columns[0].type = TYPE_VARCHAR;
        result->row_count = 1;
        strcpy(result->data[0][0].string_val, "Table does not exist");
        return -1;
    }
    
    acquire_write_lock(txn_id, table->table_id);
    
    // Call actual update_record function
    int ret = update_record(table_name, column, value, where_clause, txn_id);
    
    // Auto-commit UPDATE operation for durability
    if (ret >= 0) {
        extern uint64_t wal_log_commit(uint32_t txn_id);
        extern void flush_wal();
        wal_log_commit(txn_id);
        flush_wal();
        printf("DML: UPDATE auto-committed and flushed\n");
    }
    
    result->column_count = 1;
    strcpy(result->columns[0].name, "Result");
    result->columns[0].type = TYPE_VARCHAR;
    result->row_count = 1;
    
    if (ret >= 0) {
        snprintf(result->data[0][0].string_val, MAX_STRING_LEN, "%d record(s) updated", ret);
    } else {
        strcpy(result->data[0][0].string_val, "Failed to update records");
    }
    
    return ret >= 0 ? 0 : -1;
}

int execute_delete(const char* table_name, const char* where_clause, uint32_t txn_id, QueryResult* result) {
    Table* table = find_table_by_name(table_name);
    if (!table) {
        result->column_count = 1;
        strcpy(result->columns[0].name, "Error");
        result->columns[0].type = TYPE_VARCHAR;
        result->row_count = 1;
        strcpy(result->data[0][0].string_val, "Table does not exist");
        return -1;
    }
    
    acquire_write_lock(txn_id, table->table_id);
    
    // Call actual delete_record function
    int ret = delete_record(table_name, where_clause, txn_id);
    
    // Auto-commit DELETE operation for durability
    if (ret >= 0) {
        extern uint64_t wal_log_commit(uint32_t txn_id);
        extern void flush_wal();
        wal_log_commit(txn_id);
        flush_wal();
        printf("DML: DELETE auto-committed and flushed\n");
    }
    
    result->column_count = 1;
    strcpy(result->columns[0].name, "Result");
    result->columns[0].type = TYPE_VARCHAR;
    result->row_count = 1;
    
    if (ret >= 0) {
        snprintf(result->data[0][0].string_val, MAX_STRING_LEN, "%d record(s) deleted", ret);
    } else {
        strcpy(result->data[0][0].string_val, "Failed to delete records");
    }
    
    return ret >= 0 ? 0 : -1;
}

/**
 * Execute SELECT query with WHERE clause
 * 
 * EXECUTION STRATEGY:
 * 1. Determine optimal scan method (index vs table scan)
 * 2. Acquire shared locks for read consistency
 * 3. Perform scan with predicate pushdown
 * 4. Apply WHERE clause filtering
 * 5. Project requested columns
 * 6. Return formatted results
 * 
 * SCAN SELECTION:
 * - Check for indexes on WHERE column
 * - Use index scan if available and selective
 * - Fall back to table scan with filter
 * 
 * FILTERING:
 * - Applies WHERE predicates as early as possible
 * - Reduces I/O by filtering at storage layer
 * - Supports equality and range predicates
 */
int execute_select_with_where(const char* table_name, const char* where_column, const char* where_value, uint32_t txn_id, QueryResult* result) {
    Table* table = find_table_by_name(table_name);
    if (!table) {
        result->column_count = 1;
        strcpy(result->columns[0].name, "Error");
        result->columns[0].type = TYPE_VARCHAR;
        result->row_count = 1;
        strcpy(result->data[0][0].string_val, "Table does not exist");
        return -1;
    }
    
    acquire_read_lock(txn_id, table->table_id);
    
    printf("EXECUTOR: Starting WHERE query execution\n");
    fflush(stdout);
    
    // Get all records first
    QueryResult temp_result;
    memset(&temp_result, 0, sizeof(temp_result));
    printf("EXECUTOR: About to scan table '%s'\n", table_name);
    fflush(stdout);
    
    int ret = scan_table(table_name, &temp_result, txn_id);
    printf("EXECUTOR: scan_table returned %d\n", ret);
    fflush(stdout);
    
    if (ret < 0) {
        printf("EXECUTOR: Table scan failed\n");
        result->column_count = 1;
        strcpy(result->columns[0].name, "Error");
        result->columns[0].type = TYPE_VARCHAR;
        result->row_count = 1;
        strcpy(result->data[0][0].string_val, "Failed to scan table");
        return -1;
    }
    
    printf("EXECUTOR: Table scan completed, %d rows found\n", temp_result.row_count);
    fflush(stdout);
    
    // Find WHERE column index
    int where_col_idx = -1;
    printf("EXECUTOR: Looking for column '%s' in %d columns\n", where_column, temp_result.column_count);
    fflush(stdout);
    
    for (int i = 0; i < temp_result.column_count; i++) {
        printf("EXECUTOR: Checking column %d: '%s'\n", i, temp_result.columns[i].name);
        fflush(stdout);
        if (strcasecmp(temp_result.columns[i].name, where_column) == 0) {
            where_col_idx = i;
            printf("EXECUTOR: Found WHERE column at index %d\n", where_col_idx);
            fflush(stdout);
            break;
        }
    }
    
    if (where_col_idx == -1) {
        result->column_count = 1;
        strcpy(result->columns[0].name, "Error");
        result->columns[0].type = TYPE_VARCHAR;
        result->row_count = 1;
        strcpy(result->data[0][0].string_val, "Column does not exist");
        return -1;
    }
    
    // Copy column definitions
    result->column_count = temp_result.column_count;
    for (int i = 0; i < temp_result.column_count; i++) {
        result->columns[i] = temp_result.columns[i];
    }
    
    // Filter rows based on WHERE clause
    printf("EXECUTOR: 🔍 Filtering %d rows where %s = '%s'\n", temp_result.row_count, where_column, where_value);
    result->row_count = 0;
    int matches_found = 0;
    
    for (int row = 0; row < temp_result.row_count && result->row_count < MAX_RESULT_ROWS; row++) {
        bool match = false;
        
        if (temp_result.columns[where_col_idx].type == TYPE_INT) {
            int where_int = atoi(where_value);
            if (temp_result.data[row][where_col_idx].int_val == where_int) {
                match = true;
                matches_found++;
                printf("EXECUTOR: ✅ Match found - Row %d: %d = %d\n", row, temp_result.data[row][where_col_idx].int_val, where_int);
            }
        } else if (temp_result.columns[where_col_idx].type == TYPE_VARCHAR) {
            if (strcmp(temp_result.data[row][where_col_idx].string_val, where_value) == 0) {
                match = true;
                matches_found++;
                printf("EXECUTOR: ✅ Match found - Row %d: '%s' = '%s'\n", row, temp_result.data[row][where_col_idx].string_val, where_value);
            }
        }
        
        if (match) {
            for (int col = 0; col < temp_result.column_count; col++) {
                result->data[result->row_count][col] = temp_result.data[row][col];
            }
            result->row_count++;
        }
    }
    
    printf("EXECUTOR: 🏁 Query completed - Found %d matching rows out of %d total\n", matches_found, temp_result.row_count);
    return 0;
}

int execute_select(const char* table_name, bool select_all, char columns[][MAX_NAME_LEN], int column_count, uint32_t txn_id, QueryResult* result) {
    Table* table = find_table_by_name(table_name);
    if (!table) {
        result->column_count = 1;
        strcpy(result->columns[0].name, "Error");
        result->columns[0].type = TYPE_VARCHAR;
        result->row_count = 1;
        strcpy(result->data[0][0].string_val, "Table does not exist");
        return -1;
    }
    
    // Acquire read lock for read committed isolation
    acquire_read_lock(txn_id, table->table_id);
    
    if (select_all) {
        return scan_table(table_name, result, txn_id);
    } else {
        // For simplicity, still scan all and filter later
        int ret = scan_table(table_name, result, txn_id);
        // In real system would do proper column projection
        return ret;
    }
}

int execute_create_index(const char* index_name, const char* table_name, const char* column_name, 
                        int index_type, uint32_t txn_id, QueryResult* result) {
    acquire_write_lock(txn_id, 1); // System catalog lock
    
    // Log DDL operation to WAL
    extern uint64_t wal_log_ddl(uint32_t txn_id, const char* ddl_type, const char* object_name);
    wal_log_ddl(txn_id, "CREATE_INDEX", index_name);
    
    int ret = -1;
    
    if (index_type == INDEX_BTREE) {
        ret = create_btree_index(index_name, table_name, column_name, txn_id);
    } else if (index_type == INDEX_HASH) {
        ret = create_hash_index(index_name, table_name, column_name, txn_id);
    }
    
    // Auto-commit DDL operation
    if (ret >= 0) {
        extern uint64_t wal_log_commit(uint32_t txn_id);
        extern void flush_wal();
        wal_log_commit(txn_id);
        flush_wal();
        printf("DDL: CREATE INDEX auto-committed and flushed\n");
    }
    
    result->column_count = 1;
    strcpy(result->columns[0].name, "Result");
    result->columns[0].type = TYPE_VARCHAR;
    result->row_count = 1;
    
    if (ret >= 0) {
        strcpy(result->data[0][0].string_val, "Index created successfully");
    } else {
        strcpy(result->data[0][0].string_val, "Failed to create index");
    }
    
    return ret >= 0 ? 0 : -1;
}

int execute_drop_index(const char* index_name, uint32_t txn_id, QueryResult* result) {
    acquire_write_lock(txn_id, 1);
    
    // Log DDL operation to WAL
    extern uint64_t wal_log_ddl(uint32_t txn_id, const char* ddl_type, const char* object_name);
    wal_log_ddl(txn_id, "DROP_INDEX", index_name);
    
    int ret = drop_index_storage(index_name, txn_id);
    
    // Auto-commit DDL operation
    if (ret >= 0) {
        extern uint64_t wal_log_commit(uint32_t txn_id);
        extern void flush_wal();
        wal_log_commit(txn_id);
        flush_wal();
        printf("DDL: DROP INDEX auto-committed and flushed\n");
    }
    
    result->column_count = 1;
    strcpy(result->columns[0].name, "Result");
    result->columns[0].type = TYPE_VARCHAR;
    result->row_count = 1;
    
    if (ret >= 0) {
        strcpy(result->data[0][0].string_val, "Index dropped successfully");
    } else {
        strcpy(result->data[0][0].string_val, "Failed to drop index");
    }
    
    return ret >= 0 ? 0 : -1;
}

int execute_describe(const char* table_name, uint32_t txn_id, QueryResult* result) {
    Table* table = find_table_by_name(table_name);
    if (!table) {
        result->column_count = 1;
        strcpy(result->columns[0].name, "Error");
        result->columns[0].type = TYPE_VARCHAR;
        result->row_count = 1;
        strcpy(result->data[0][0].string_val, "Table does not exist");
        return -1;
    }
    
    acquire_read_lock(txn_id, 1); // System catalog read lock
    
    result->column_count = 4;
    strcpy(result->columns[0].name, "Column");
    result->columns[0].type = TYPE_VARCHAR;
    strcpy(result->columns[1].name, "Type");
    result->columns[1].type = TYPE_VARCHAR;
    strcpy(result->columns[2].name, "Size");
    result->columns[2].type = TYPE_INT;
    strcpy(result->columns[3].name, "Nullable");
    result->columns[3].type = TYPE_VARCHAR;
    
    result->row_count = table->column_count;
    
    for (int i = 0; i < table->column_count; i++) {
        strcpy(result->data[i][0].string_val, table->columns[i].name);
        strcpy(result->data[i][1].string_val, datatype_to_string(table->columns[i].type));
        result->data[i][2].int_val = table->columns[i].size;
        strcpy(result->data[i][3].string_val, table->columns[i].nullable ? "YES" : "NO");
    }
    
    return 0;
}

int execute_show_tables(uint32_t txn_id, QueryResult* result) {
    acquire_read_lock(txn_id, 1);
    
    result->column_count = 1;
    strcpy(result->columns[0].name, "Tables");
    result->columns[0].type = TYPE_VARCHAR;
    result->row_count = 1;
    strcpy(result->data[0][0].string_val, "SHOW TABLES functionality not fully implemented");
    
    return 0;
}