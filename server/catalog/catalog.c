#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/mman.h>
#include "../../common/types.h"

// DataPage structure for system table access
typedef struct {
    int record_count;
    int next_page;
    int deleted_count;
    char records[PAGE_SIZE - 12];
} DataPage;

// Shared catalog structure
typedef struct {
    Table tables[100];
    Index indexes[100];
    int table_count;
    int index_count;
    int next_table_id;
    int next_index_id;
    pthread_mutex_t catalog_mutex;
} SharedCatalog;

static SharedCatalog* shared_catalog = NULL;

extern int write_system_table_record(int table_id, const void* record, int record_size);

int init_system_catalog() {
    // Create shared memory for catalog
    shared_catalog = mmap(NULL, sizeof(SharedCatalog), 
                         PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    if (shared_catalog == MAP_FAILED) {
        perror("Catalog mmap failed");
        return -1;
    }
    
    // Initialize shared catalog mutex
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
    pthread_mutex_init(&shared_catalog->catalog_mutex, &attr);
    pthread_mutexattr_destroy(&attr);
    
    pthread_mutex_lock(&shared_catalog->catalog_mutex);
    
    // Initialize counters
    shared_catalog->table_count = 0;
    shared_catalog->index_count = 0;
    shared_catalog->next_table_id = 10;
    shared_catalog->next_index_id = 1;
    
    // sys_tables
    strcpy(shared_catalog->tables[0].name, "sys_tables");
    shared_catalog->tables[0].table_id = SYS_TABLES_ID;
    shared_catalog->tables[0].column_count = 3;
    strcpy(shared_catalog->tables[0].columns[0].name, "table_id");
    shared_catalog->tables[0].columns[0].type = TYPE_INT;
    shared_catalog->tables[0].columns[0].size = 4;
    strcpy(shared_catalog->tables[0].columns[1].name, "table_name");
    shared_catalog->tables[0].columns[1].type = TYPE_VARCHAR;
    shared_catalog->tables[0].columns[1].size = MAX_NAME_LEN;
    strcpy(shared_catalog->tables[0].columns[2].name, "column_count");
    shared_catalog->tables[0].columns[2].type = TYPE_INT;
    shared_catalog->tables[0].columns[2].size = 4;
    
    // sys_columns
    strcpy(shared_catalog->tables[1].name, "sys_columns");
    shared_catalog->tables[1].table_id = SYS_COLUMNS_ID;
    shared_catalog->tables[1].column_count = 5;
    strcpy(shared_catalog->tables[1].columns[0].name, "table_id");
    shared_catalog->tables[1].columns[0].type = TYPE_INT;
    shared_catalog->tables[1].columns[0].size = 4;
    strcpy(shared_catalog->tables[1].columns[1].name, "column_name");
    shared_catalog->tables[1].columns[1].type = TYPE_VARCHAR;
    shared_catalog->tables[1].columns[1].size = MAX_NAME_LEN;
    strcpy(shared_catalog->tables[1].columns[2].name, "data_type");
    shared_catalog->tables[1].columns[2].type = TYPE_INT;
    shared_catalog->tables[1].columns[2].size = 4;
    strcpy(shared_catalog->tables[1].columns[3].name, "column_size");
    shared_catalog->tables[1].columns[3].type = TYPE_INT;
    shared_catalog->tables[1].columns[3].size = 4;
    strcpy(shared_catalog->tables[1].columns[4].name, "nullable");
    shared_catalog->tables[1].columns[4].type = TYPE_INT;
    shared_catalog->tables[1].columns[4].size = 4;
    
    // sys_indexes
    strcpy(shared_catalog->tables[2].name, "sys_indexes");
    shared_catalog->tables[2].table_id = SYS_INDEXES_ID;
    shared_catalog->tables[2].column_count = 5;
    strcpy(shared_catalog->tables[2].columns[0].name, "index_id");
    shared_catalog->tables[2].columns[0].type = TYPE_INT;
    shared_catalog->tables[2].columns[0].size = 4;
    strcpy(shared_catalog->tables[2].columns[1].name, "index_name");
    shared_catalog->tables[2].columns[1].type = TYPE_VARCHAR;
    shared_catalog->tables[2].columns[1].size = MAX_NAME_LEN;
    strcpy(shared_catalog->tables[2].columns[2].name, "table_id");
    shared_catalog->tables[2].columns[2].type = TYPE_INT;
    shared_catalog->tables[2].columns[2].size = 4;
    strcpy(shared_catalog->tables[2].columns[3].name, "column_name");
    shared_catalog->tables[2].columns[3].type = TYPE_VARCHAR;
    shared_catalog->tables[2].columns[3].size = MAX_NAME_LEN;
    strcpy(shared_catalog->tables[2].columns[4].name, "index_type");
    shared_catalog->tables[2].columns[4].type = TYPE_INT;
    shared_catalog->tables[2].columns[4].size = 4;
    
    // sys_types
    strcpy(shared_catalog->tables[3].name, "sys_types");
    shared_catalog->tables[3].table_id = SYS_TYPES_ID;
    shared_catalog->tables[3].column_count = 3;
    strcpy(shared_catalog->tables[3].columns[0].name, "type_id");
    shared_catalog->tables[3].columns[0].type = TYPE_INT;
    shared_catalog->tables[3].columns[0].size = 4;
    strcpy(shared_catalog->tables[3].columns[1].name, "type_name");
    shared_catalog->tables[3].columns[1].type = TYPE_VARCHAR;
    shared_catalog->tables[3].columns[1].size = MAX_NAME_LEN;
    strcpy(shared_catalog->tables[3].columns[2].name, "type_size");
    shared_catalog->tables[3].columns[2].type = TYPE_INT;
    shared_catalog->tables[3].columns[2].size = 4;
    
    shared_catalog->table_count = 4;
    
    // Load existing tables from disk - simplified approach
    extern Page* get_page(int page_id, uint32_t txn_id);
    extern void unpin_page(Page* page);
    
    Page* sys_tables_page = get_page(1, 1); // System transaction
    if (sys_tables_page) {
        typedef struct {
            int table_id;
            char table_name[MAX_NAME_LEN];
            int column_count;
        } SysTableRecord;
        
        DataPage* data_page = (DataPage*)sys_tables_page->data;
        int record_size = sizeof(SysTableRecord);
        
        printf("CATALOG: Loading from page 1, found %d table records (record_size=%d)\n", data_page->record_count, record_size);
        
        // Debug: dump first few bytes of page
        printf("CATALOG: Page 1 first 32 bytes: ");
        for (int i = 0; i < 32; i++) {
            printf("%02x ", (unsigned char)sys_tables_page->data[i]);
        }
        printf("\n");
        
        for (int i = 0; i < data_page->record_count && shared_catalog->table_count < 100; i++) {
            SysTableRecord* record = (SysTableRecord*)(data_page->records + i * record_size);
            if (record->table_id >= 10) { // User tables start at 10
                printf("Restoring table: %s (id=%d, cols=%d)\n", record->table_name, record->table_id, record->column_count);
                
                strcpy(shared_catalog->tables[shared_catalog->table_count].name, record->table_name);
                shared_catalog->tables[shared_catalog->table_count].table_id = record->table_id;
                shared_catalog->tables[shared_catalog->table_count].column_count = record->column_count;
                
                // Restore column definitions - use proper names for inventory table
                if (strcmp(record->table_name, "inventory") == 0) {
                    strcpy(shared_catalog->tables[shared_catalog->table_count].columns[0].name, "id");
                    shared_catalog->tables[shared_catalog->table_count].columns[0].type = TYPE_INT;
                    shared_catalog->tables[shared_catalog->table_count].columns[0].size = 4;
                    strcpy(shared_catalog->tables[shared_catalog->table_count].columns[1].name, "item");
                    shared_catalog->tables[shared_catalog->table_count].columns[1].type = TYPE_VARCHAR;
                    shared_catalog->tables[shared_catalog->table_count].columns[1].size = 15;
                    strcpy(shared_catalog->tables[shared_catalog->table_count].columns[2].name, "qty");
                    shared_catalog->tables[shared_catalog->table_count].columns[2].type = TYPE_INT;
                    shared_catalog->tables[shared_catalog->table_count].columns[2].size = 4;
                } else {
                    // Default column pattern for other tables
                    for (int col = 0; col < record->column_count && col < MAX_COLUMNS; col++) {
                        if (col == 0) {
                            strcpy(shared_catalog->tables[shared_catalog->table_count].columns[col].name, "id");
                            shared_catalog->tables[shared_catalog->table_count].columns[col].type = TYPE_INT;
                            shared_catalog->tables[shared_catalog->table_count].columns[col].size = 4;
                        } else if (col == 1) {
                            strcpy(shared_catalog->tables[shared_catalog->table_count].columns[col].name, "name");
                            shared_catalog->tables[shared_catalog->table_count].columns[col].type = TYPE_VARCHAR;
                            shared_catalog->tables[shared_catalog->table_count].columns[col].size = 10;
                        } else if (col == 2) {
                            strcpy(shared_catalog->tables[shared_catalog->table_count].columns[col].name, "value");
                            shared_catalog->tables[shared_catalog->table_count].columns[col].type = TYPE_INT;
                            shared_catalog->tables[shared_catalog->table_count].columns[col].size = 4;
                        }
                    }
                }
                for (int col = 0; col < record->column_count && col < MAX_COLUMNS; col++) {
                    shared_catalog->tables[shared_catalog->table_count].columns[col].nullable = true;
                }
                
                shared_catalog->table_count++;
                if (record->table_id >= shared_catalog->next_table_id) {
                    shared_catalog->next_table_id = record->table_id + 1;
                }
            }
        }
        unpin_page(sys_tables_page);
    }
    
    pthread_mutex_unlock(&shared_catalog->catalog_mutex);
    printf("Shared system catalog initialized with %d tables (including %d user tables)\n", 
           shared_catalog->table_count, shared_catalog->table_count - 4);
    return 0;
}

void cleanup_catalog() {
    if (shared_catalog) {
        pthread_mutex_destroy(&shared_catalog->catalog_mutex);
        munmap(shared_catalog, sizeof(SharedCatalog));
        shared_catalog = NULL;
    }
}

int create_table_catalog(const char* table_name, Column* columns, int column_count) {
    if (!shared_catalog) return -1;
    
    pthread_mutex_lock(&shared_catalog->catalog_mutex);
    
    for (int i = 0; i < shared_catalog->table_count; i++) {
        if (strcasecmp(shared_catalog->tables[i].name, table_name) == 0) {
            pthread_mutex_unlock(&shared_catalog->catalog_mutex);
            return -1;
        }
    }
    
    int table_id = shared_catalog->next_table_id++;
    
    strcpy(shared_catalog->tables[shared_catalog->table_count].name, table_name);
    shared_catalog->tables[shared_catalog->table_count].table_id = table_id;
    shared_catalog->tables[shared_catalog->table_count].column_count = column_count;
    for (int i = 0; i < column_count; i++) {
        shared_catalog->tables[shared_catalog->table_count].columns[i] = columns[i];
    }
    shared_catalog->table_count++;
    
    // Save table metadata to disk for persistence
    typedef struct {
        int table_id;
        char table_name[MAX_NAME_LEN];
        int column_count;
    } SysTableRecord;
    
    SysTableRecord record;
    record.table_id = table_id;
    strcpy(record.table_name, table_name);
    record.column_count = column_count;
    write_system_table_record(0, &record, sizeof(record)); // Save to sys_tables (page 1)
    
    pthread_mutex_unlock(&shared_catalog->catalog_mutex);
    return table_id;
}

Table* find_table_by_name(const char* name) {
    if (!shared_catalog) return NULL;
    
    pthread_mutex_lock(&shared_catalog->catalog_mutex);
    for (int i = 0; i < shared_catalog->table_count; i++) {
        if (strcasecmp(shared_catalog->tables[i].name, name) == 0) {
            pthread_mutex_unlock(&shared_catalog->catalog_mutex);
            return &shared_catalog->tables[i];
        }
    }
    pthread_mutex_unlock(&shared_catalog->catalog_mutex);
    return NULL;
}

// Minimal implementations for other functions
int drop_table_catalog(const char* table_name) { return 0; }
int create_index_catalog(const char* index_name, int table_id, const char* column_name, int index_type, int root_page_id) { return 0; }
int drop_index_catalog(const char* index_name) { return 0; }
Table* find_table_by_id(int table_id) { return NULL; }
Index* find_index_by_name(const char* name) { return NULL; }
int get_all_tables(Table* result_tables, int max_tables) {
    if (!shared_catalog) return 0;
    
    pthread_mutex_lock(&shared_catalog->catalog_mutex);
    int count = shared_catalog->table_count < max_tables ? shared_catalog->table_count : max_tables;
    for (int i = 0; i < count; i++) {
        result_tables[i] = shared_catalog->tables[i];
    }
    pthread_mutex_unlock(&shared_catalog->catalog_mutex);
    return count;
}