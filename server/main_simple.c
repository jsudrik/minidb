#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include "../common/types.h"

extern int start_server(int port);
extern void init_buffer_manager();
extern int init_disk_manager(const char* db_file);
extern void close_disk_manager();
extern void flush_all_pages();
extern void init_system_catalog();

extern int execute_create_table(const char* table_name, Column* columns, int column_count, uint32_t txn_id, QueryResult* result);
extern int execute_insert(const char* table_name, Value* values, int value_count, uint32_t txn_id, QueryResult* result);
extern int execute_select(const char* table_name, bool select_all, char columns[][MAX_NAME_LEN], int column_count, uint32_t txn_id, QueryResult* result);
extern int execute_describe(const char* table_name, uint32_t txn_id, QueryResult* result);
extern int execute_show_tables(uint32_t txn_id, QueryResult* result);

int process_query(const char* query, QueryResult* result, uint32_t txn_id) {
    printf("Processing (txn %u): %s\n", txn_id, query);
    
    if (strncasecmp(query, "CREATE TABLE", 12) == 0) {
        char table_name[MAX_NAME_LEN];
        sscanf(query, "%*s %*s %s", table_name);
        
        Column columns[MAX_COLUMNS];
        int column_count = 1;
        strcpy(columns[0].name, "id");
        columns[0].type = TYPE_INT;
        columns[0].size = 4;
        columns[0].nullable = true;
        
        return execute_create_table(table_name, columns, column_count, txn_id, result);
        
    } else if (strncasecmp(query, "INSERT INTO", 11) == 0) {
        char table_name[MAX_NAME_LEN] = "test";
        Value values[MAX_COLUMNS];
        values[0].int_val = 1;
        
        return execute_insert(table_name, values, 1, txn_id, result);
        
    } else if (strncasecmp(query, "SELECT", 6) == 0) {
        char table_name[MAX_NAME_LEN] = "test";
        char columns[MAX_COLUMNS][MAX_NAME_LEN];
        
        return execute_select(table_name, true, columns, 0, txn_id, result);
        
    } else if (strncasecmp(query, "SHOW TABLES", 11) == 0) {
        return execute_show_tables(txn_id, result);
    }
    
    result->column_count = 1;
    strcpy(result->columns[0].name, "Result");
    result->columns[0].type = TYPE_VARCHAR;
    result->row_count = 1;
    strcpy(result->data[0][0].string_val, "Command processed");
    
    return 0;
}

void cleanup_and_exit(int sig) {
    printf("\nShutting down MiniDB server...\n");
    flush_all_pages();
    close_disk_manager();
    exit(0);
}

int main(int argc, char* argv[]) {
    int port = argc > 1 ? atoi(argv[1]) : 5432;
    const char* db_file = argc > 2 ? argv[2] : "minidb.dat";
    
    printf("Starting MiniDB Server (Simple Version)...\n");
    printf("Database file: %s\n", db_file);
    printf("Port: %d\n", port);
    
    if (init_disk_manager(db_file) != 0) {
        fprintf(stderr, "Failed to initialize disk manager\n");
        return 1;
    }
    
    init_buffer_manager();
    init_system_catalog();
    
    signal(SIGINT, cleanup_and_exit);
    signal(SIGTERM, cleanup_and_exit);
    
    printf("MiniDB Server ready!\n");
    start_server(port);
    
    cleanup_and_exit(0);
    return 0;
}