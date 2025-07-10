#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <signal.h>
#include "../common/types.h"
#include "../common/wal_types.h"

extern int start_server(int port);
extern int init_buffer_manager();
extern void cleanup_buffer_manager();
extern int init_disk_manager(const char* db_file);
extern void close_disk_manager();
extern void flush_all_pages();
extern int init_system_catalog();
extern void cleanup_catalog();
extern int init_wal_manager(const char* wal_file);
extern void close_wal_manager();
extern int perform_crash_recovery();
extern int checkpoint_recovery();
extern void flush_wal();

extern int execute_create_table(const char* table_name, Column* columns, int column_count, uint32_t txn_id, QueryResult* result);
extern int execute_drop_table(const char* table_name, uint32_t txn_id, QueryResult* result);
extern int execute_insert(const char* table_name, Value* values, int value_count, uint32_t txn_id, QueryResult* result);
extern int execute_update(const char* table_name, const char* column, Value* value, const char* where_clause, uint32_t txn_id, QueryResult* result);
extern int execute_delete(const char* table_name, const char* where_clause, uint32_t txn_id, QueryResult* result);
extern int execute_select(const char* table_name, bool select_all, char columns[][MAX_NAME_LEN], int column_count, uint32_t txn_id, QueryResult* result);
extern int execute_create_index(const char* index_name, const char* table_name, const char* column_name, int index_type, uint32_t txn_id, QueryResult* result);
extern int execute_drop_index(const char* index_name, uint32_t txn_id, QueryResult* result);
extern int execute_describe(const char* table_name, uint32_t txn_id, QueryResult* result);
extern int execute_show_tables(uint32_t txn_id, QueryResult* result);

DataType parse_datatype(const char* type_str, int* size) {
    char upper_type[64];
    strcpy(upper_type, type_str);
    for (int i = 0; upper_type[i]; i++) {
        if (upper_type[i] >= 'a' && upper_type[i] <= 'z') {
            upper_type[i] = upper_type[i] - 'a' + 'A';
        }
    }
    
    if (strcmp(upper_type, "INT") == 0) {
        *size = 4;
        return TYPE_INT;
    } else if (strcmp(upper_type, "BIGINT") == 0) {
        *size = 8;
        return TYPE_BIGINT;
    } else if (strcmp(upper_type, "FLOAT") == 0) {
        *size = 4;
        return TYPE_FLOAT;
    } else if (strncmp(upper_type, "CHAR", 4) == 0) {
        sscanf(upper_type, "CHAR(%d)", size);
        return TYPE_CHAR;
    } else if (strncmp(upper_type, "VARCHAR", 7) == 0) {
        sscanf(upper_type, "VARCHAR(%d)", size);
        return TYPE_VARCHAR;
    }
    
    *size = 0;
    return TYPE_INT;
}

int process_query(const char* query, QueryResult* result, uint32_t txn_id) {
    printf("Processing (txn %u): %s\n", txn_id, query);
    printf("DEBUG: Query length: %zu\n", strlen(query));
    fflush(stdout);
    
    char upper_query[MAX_QUERY_LEN];
    strcpy(upper_query, query);
    for (int i = 0; upper_query[i]; i++) {
        if (upper_query[i] >= 'a' && upper_query[i] <= 'z') {
            upper_query[i] = upper_query[i] - 'a' + 'A';
        }
    }
    
    if (strncmp(upper_query, "CREATE TABLE", 12) == 0) {
        char table_name[MAX_NAME_LEN];
        char *paren_start = strchr(query, '(');
        char *paren_end = strrchr(query, ')');
        
        if (!paren_start || !paren_end) {
            strcpy(result->data[0][0].string_val, "Invalid CREATE TABLE syntax");
            result->column_count = 1;
            result->row_count = 1;
            return -1;
        }
        
        sscanf(query, "%*s %*s %s", table_name);
        
        Column columns[MAX_COLUMNS];
        int column_count = 0;
        
        char col_defs[1024];
        strncpy(col_defs, paren_start + 1, paren_end - paren_start - 1);
        col_defs[paren_end - paren_start - 1] = '\0';
        
        char* token = strtok(col_defs, ",");
        while (token && column_count < MAX_COLUMNS) {
            while (*token == ' ') token++;
            
            char col_name[MAX_NAME_LEN], col_type[64];
            if (sscanf(token, "%s %s", col_name, col_type) == 2) {
                strcpy(columns[column_count].name, col_name);
                columns[column_count].type = parse_datatype(col_type, &columns[column_count].size);
                columns[column_count].nullable = true;
                column_count++;
            }
            token = strtok(NULL, ",");
        }
        
        return execute_create_table(table_name, columns, column_count, txn_id, result);
        
    } else if (strncmp(upper_query, "DROP TABLE", 10) == 0) {
        char table_name[MAX_NAME_LEN];
        sscanf(query, "%*s %*s %s", table_name);
        return execute_drop_table(table_name, txn_id, result);
        
    } else if (strncmp(upper_query, "INSERT INTO", 11) == 0) {
        char table_name[MAX_NAME_LEN];
        char *values_start = strstr(upper_query, "VALUES");
        if (!values_start) values_start = strstr(upper_query, "values");
        if (!values_start) {
            strcpy(result->data[0][0].string_val, "VALUES keyword not found");
            result->column_count = 1;
            result->row_count = 1;
            return -1;
        }
        // Adjust pointer to original query
        values_start = query + (values_start - upper_query);
        char *paren_start = strchr(values_start, '(');
        char *paren_end = strrchr(query, ')');
        
        if (!values_start || !paren_start || !paren_end) {
            strcpy(result->data[0][0].string_val, "Invalid INSERT syntax");
            result->column_count = 1;
            result->row_count = 1;
            return -1;
        }
        
        sscanf(query, "%*s %*s %s", table_name);
        
        Value values[MAX_COLUMNS];
        int value_count = 0;
        
        char val_list[1024];
        strncpy(val_list, paren_start + 1, paren_end - paren_start - 1);
        val_list[paren_end - paren_start - 1] = '\0';
        
        char* token = strtok(val_list, ",");
        while (token && value_count < MAX_COLUMNS) {
            while (*token == ' ') token++;
            
            if (token[0] == '\'' && token[strlen(token)-1] == '\'') {
                token[strlen(token)-1] = '\0';
                strcpy(values[value_count].string_val, token + 1);
            } else if (strchr(token, '.')) {
                values[value_count].float_val = atof(token);
            } else {
                values[value_count].int_val = atoi(token);
            }
            value_count++;
            token = strtok(NULL, ",");
        }
        
        return execute_insert(table_name, values, value_count, txn_id, result);
        
    } else if (strncmp(upper_query, "UPDATE", 6) == 0) {
        char table_name[MAX_NAME_LEN], column_name[MAX_NAME_LEN], value_str[256];
        if (sscanf(query, "%*s %s %*s %s = '%[^']'", table_name, column_name, value_str) == 3) {
            Value value;
            strcpy(value.string_val, value_str);
            return execute_update(table_name, column_name, &value, "", txn_id, result);
        }
        
    } else if (strncmp(upper_query, "DELETE FROM", 11) == 0) {
        char table_name[MAX_NAME_LEN];
        sscanf(query, "%*s %*s %s", table_name);
        return execute_delete(table_name, "", txn_id, result);
        
    } else if (strncmp(upper_query, "SELECT", 6) == 0) {
        printf("DEBUG: Processing SELECT query: %s\n", query);
        printf("DEBUG: Upper query: %s\n", upper_query);
        fflush(stdout);
        char table_names[MAX_COLUMNS][MAX_NAME_LEN];
        int table_count = 0;
        bool select_all = false;
        char columns[MAX_COLUMNS][MAX_NAME_LEN];
        int column_count = 0;
        
        // Simple WHERE clause detection
        char where_column[MAX_NAME_LEN] = "";
        char where_value[MAX_STRING_LEN] = "";
        bool has_where = false;
        
        // Look for WHERE pattern in original query (not upper case)
        char* where_start = strstr(query, " where ");
        if (!where_start) where_start = strstr(query, " WHERE ");
        
        if (where_start) {
            // Simple pattern: "where column = value" or "where column = 'value'"
            char temp[256];
            strncpy(temp, where_start + 7, sizeof(temp) - 1);
            temp[sizeof(temp) - 1] = '\0';
            
            // Find = sign
            char* eq = strchr(temp, '=');
            if (eq) {
                // Extract column (before =)
                *eq = '\0';
                char* col = temp;
                while (*col == ' ') col++; // skip spaces
                char* col_end = col + strlen(col) - 1;
                while (col_end > col && *col_end == ' ') *col_end-- = '\0'; // trim spaces
                
                if (strlen(col) > 0 && strlen(col) < MAX_NAME_LEN) {
                    strcpy(where_column, col);
                    
                    // Extract value (after =)
                    char* val = eq + 1;
                    while (*val == ' ') val++; // skip spaces
                    
                    // Remove quotes if present
                    if ((*val == '\'' || *val == '"') && strlen(val) > 1) {
                        val++; // skip opening quote
                        char* end = val + strlen(val) - 1;
                        if (*end == '\'' || *end == '"') *end = '\0'; // remove closing quote
                    }
                    
                    // Remove trailing spaces and semicolon
                    char* val_end = val + strlen(val) - 1;
                    while (val_end > val && (*val_end == ' ' || *val_end == ';')) *val_end-- = '\0';
                    
                    if (strlen(val) > 0 && strlen(val) < MAX_STRING_LEN) {
                        strcpy(where_value, val);
                        has_where = true;
                        printf("OPTIMIZER: WHERE clause detected - Column: '%s', Value: '%s'\n", where_column, where_value);
                    }
                }
            }
        }
        
        // Parse tables from FROM clause
        char* from_pos = strstr(upper_query, " FROM ");
        if (!from_pos) {
            result->column_count = 1;
            strcpy(result->columns[0].name, "Error");
            result->columns[0].type = TYPE_VARCHAR;
            result->row_count = 1;
            strcpy(result->data[0][0].string_val, "Missing FROM clause");
            return -1;
        }
        
        // Extract table names (simple parsing for single table)
        char temp_table[MAX_NAME_LEN * 2];
        sscanf(from_pos + 6, "%s", temp_table);
        
        // Handle WHERE clause in table name extraction
        char* where_in_table = strstr(temp_table, "WHERE");
        if (where_in_table) {
            *where_in_table = '\0';
        }
        
        // Clean up table name
        strcpy(table_names[0], temp_table);
        char* semicolon = strchr(table_names[0], ';');
        if (semicolon) *semicolon = '\0';
        
        // Trim whitespace from table name
        char* end = table_names[0] + strlen(table_names[0]) - 1;
        while (end > table_names[0] && *end == ' ') *end-- = '\0';
        
        table_count = 1;
        printf("DEBUG: Extracted table name: '%s'\n", table_names[0]);
        
        // Check table existence
        extern Table* find_table_by_name(const char* name);
        Table* table = find_table_by_name(table_names[0]);
        if (!table) {
            result->column_count = 1;
            strcpy(result->columns[0].name, "Error");
            result->columns[0].type = TYPE_VARCHAR;
            result->row_count = 1;
            strcpy(result->data[0][0].string_val, "Table does not exist");
            return -1;
        }
        
        // Parse columns
        if (strstr(upper_query, "SELECT *")) {
            select_all = true;
        } else {
            // Parse specific columns
            char* select_start = upper_query + 6;
            char* from_start = strstr(upper_query, " FROM");
            if (from_start) {
                int col_len = from_start - select_start;
                char col_str[512];
                strncpy(col_str, select_start, col_len);
                col_str[col_len] = '\0';
                
                // Simple column parsing (comma-separated)
                char* token = strtok(col_str, ",");
                while (token && column_count < MAX_COLUMNS) {
                    // Trim whitespace
                    while (*token == ' ') token++;
                    char* end = token + strlen(token) - 1;
                    while (end > token && *end == ' ') *end-- = '\0';
                    
                    strcpy(columns[column_count], token);
                    
                    // Validate column exists in table
                    bool found = false;
                    for (int i = 0; i < table->column_count; i++) {
                        if (strcasecmp(table->columns[i].name, token) == 0) {
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        result->column_count = 1;
                        strcpy(result->columns[0].name, "Error");
                        result->columns[0].type = TYPE_VARCHAR;
                        result->row_count = 1;
                        strcpy(result->data[0][0].string_val, "Column does not exist");
                        return -1;
                    }
                    
                    column_count++;
                    token = strtok(NULL, ",");
                }
            }
        }
        
        // Query optimization: check for index usage
        if (has_where) {
            // Check if there's an index on the WHERE column
            extern int check_index_exists(const char* table_name, const char* column_name);
            int index_type = check_index_exists(table_names[0], where_column);
            
            if (index_type == INDEX_BTREE) {
                printf("OPTIMIZER: ✅ CHOSE B-Tree index scan on column '%s'\n", where_column);
                printf("EXECUTOR: 🔍 Executing B-Tree index lookup for value '%s'\n", where_value);
            } else if (index_type == INDEX_HASH) {
                printf("OPTIMIZER: ✅ CHOSE Hash index scan on column '%s'\n", where_column);
                printf("EXECUTOR: 🔍 Executing Hash index lookup for value '%s'\n", where_value);
            } else {
                printf("OPTIMIZER: ⚠️ CHOSE table scan (no index on column '%s')\n", where_column);
                printf("EXECUTOR: 📋 Executing full table scan with filter\n");
            }
            
            printf("DEBUG: About to call execute_select_with_where\n");
            fflush(stdout);
            extern int execute_select_with_where(const char* table_name, const char* where_column, const char* where_value, uint32_t txn_id, QueryResult* result);
            printf("DEBUG: Calling execute_select_with_where('%s', '%s', '%s')\n", table_names[0], where_column, where_value);
            fflush(stdout);
            int rows = execute_select_with_where(table_names[0], where_column, where_value, txn_id, result);
            printf("DEBUG: execute_select_with_where returned %d\n", rows);
            fflush(stdout);
            return rows >= 0 ? 0 : -1;
        } else {
            printf("OPTIMIZER: Using full table scan (no WHERE clause)\n");
            int rows = execute_select(table_names[0], select_all, columns, column_count, txn_id, result);
            return rows >= 0 ? 0 : -1;
        }
        
    } else if (strncmp(upper_query, "CREATE INDEX", 12) == 0) {
        char index_name[MAX_NAME_LEN], table_name[MAX_NAME_LEN], column_name[MAX_NAME_LEN], index_type[MAX_NAME_LEN];
        
        if (sscanf(query, "%*s %*s %s %*s %s (%[^)]) %*s %s", 
                   index_name, table_name, column_name, index_type) == 4) {
            int type = (strcasecmp(index_type, "HASH") == 0) ? INDEX_HASH : INDEX_BTREE;
            return execute_create_index(index_name, table_name, column_name, type, txn_id, result);
        }
        
    } else if (strncmp(upper_query, "DROP INDEX", 10) == 0) {
        char index_name[MAX_NAME_LEN];
        sscanf(query, "%*s %*s %s", index_name);
        return execute_drop_index(index_name, txn_id, result);
        
    } else if (strncmp(upper_query, "DESCRIBE", 8) == 0 || strncmp(upper_query, "DESC", 4) == 0) {
        char table_name[MAX_NAME_LEN];
        sscanf(query, "%*s %s", table_name);
        return execute_describe(table_name, txn_id, result);
        
    } else if (strncmp(upper_query, "SHOW TABLES", 11) == 0) {
        return execute_show_tables(txn_id, result);
    }
    
    result->column_count = 1;
    strcpy(result->columns[0].name, "Error");
    result->columns[0].type = TYPE_VARCHAR;
    result->row_count = 1;
    strcpy(result->data[0][0].string_val, "Query execution failed");
    
    return -1;
}

void cleanup_and_exit(int sig) {
    printf("\nShutting down MiniDB server...\n");
    
    // Cleanup shared memory
    cleanup_buffer_manager();
    cleanup_catalog();
    close_disk_manager();
    
    exit(0);
}

int main(int argc, char* argv[]) {
    int port = argc > 1 ? atoi(argv[1]) : 5432;
    const char* db_file = argc > 2 ? argv[2] : "minidb.dat";
    
    printf("Starting MiniDB Server with WAL and Crash Recovery...\n");
    printf("Database file: %s\n", db_file);
    printf("Port: %d\n", port);
    
    // Initialize disk manager first
    if (init_disk_manager(db_file) != 0) {
        fprintf(stderr, "Failed to initialize disk manager\n");
        return 1;
    }
    
    // Initialize WAL for data persistence
    if (init_wal_manager("minidb.wal") != 0) {
        fprintf(stderr, "Failed to initialize WAL manager\n");
        return 1;
    }
    
    if (init_buffer_manager() < 0) {
        printf("Failed to initialize shared buffer manager\n");
        return -1;
    }
    
    // Perform crash recovery for data consistency
    if (perform_crash_recovery() != 0) {
        fprintf(stderr, "Failed to perform crash recovery\n");
        return 1;
    }
    
    if (init_system_catalog() < 0) {
        printf("Failed to initialize shared catalog\n");
        return -1;
    }
    
    signal(SIGINT, cleanup_and_exit);
    signal(SIGTERM, cleanup_and_exit);
    
    printf("MiniDB Server ready with WAL and transaction support!\n");
    start_server(port);
    
    cleanup_and_exit(0);
    return 0;
}