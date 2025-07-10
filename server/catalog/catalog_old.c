#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/mman.h>
#include "../../common/types.h"

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
    
    pthread_mutex_unlock(&shared_catalog->catalog_mutex);
    printf("Shared system catalog initialized with %d system tables\n", shared_catalog->table_count);
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
    pthread_mutex_lock(&catalog_mutex);
    
    for (int i = 0; i < table_count; i++) {
        if (strcasecmp(tables[i].name, table_name) == 0) {
            pthread_mutex_unlock(&catalog_mutex);
            return -1;
        }
    }
    
    int table_id = next_table_id++;
    
    strcpy(tables[table_count].name, table_name);
    tables[table_count].table_id = table_id;
    tables[table_count].column_count = column_count;
    for (int i = 0; i < column_count; i++) {
        tables[table_count].columns[i] = columns[i];
    }
    table_count++;
    
    struct {
        int table_id;
        char table_name[MAX_NAME_LEN];
        int column_count;
    } sys_table_record = {table_id, "", column_count};
    strcpy(sys_table_record.table_name, table_name);
    write_system_table_record(SYS_TABLES_ID, &sys_table_record, sizeof(sys_table_record));
    
    for (int i = 0; i < column_count; i++) {
        struct {
            int table_id;
            char column_name[MAX_NAME_LEN];
            int data_type;
            int column_size;
            int nullable;
        } sys_column_record = {table_id, "", columns[i].type, columns[i].size, columns[i].nullable};
        strcpy(sys_column_record.column_name, columns[i].name);
        write_system_table_record(SYS_COLUMNS_ID, &sys_column_record, sizeof(sys_column_record));
    }
    
    pthread_mutex_unlock(&catalog_mutex);
    return table_id;
}

int drop_table_catalog(const char* table_name) {
    if (!shared_catalog) return -1;
    
    pthread_mutex_lock(&shared_catalog->catalog_mutex);
    
    int found_idx = -1;
    for (int i = 0; i < shared_catalog->table_count; i++) {
        if (strcasecmp(shared_catalog->tables[i].name, table_name) == 0) {
            found_idx = i;
            break;
        }
    }
    
    if (found_idx == -1) {
        pthread_mutex_unlock(&shared_catalog->catalog_mutex);
        return -1;
    }
    
    // Remove from in-memory catalog
    for (int i = found_idx; i < shared_catalog->table_count - 1; i++) {
        shared_catalog->tables[i] = shared_catalog->tables[i + 1];
    }
    shared_catalog->table_count--;
    
    pthread_mutex_unlock(&shared_catalog->catalog_mutex);
    return 0;
}

int create_index_catalog(const char* index_name, int table_id, const char* column_name, int index_type, int root_page_id) {
    pthread_mutex_lock(&catalog_mutex);
    
    int index_id = next_index_id++;
    
    strcpy(indexes[index_count].name, index_name);
    indexes[index_count].index_id = index_id;
    indexes[index_count].table_id = table_id;
    strcpy(indexes[index_count].column_name, column_name);
    indexes[index_count].type = index_type;
    indexes[index_count].root_page_id = root_page_id;
    index_count++;
    
    struct {
        int index_id;
        char index_name[MAX_NAME_LEN];
        int table_id;
        char column_name[MAX_NAME_LEN];
        int index_type;
    } sys_index_record = {index_id, "", table_id, "", index_type};
    strcpy(sys_index_record.index_name, index_name);
    strcpy(sys_index_record.column_name, column_name);
    write_system_table_record(SYS_INDEXES_ID, &sys_index_record, sizeof(sys_index_record));
    
    pthread_mutex_unlock(&catalog_mutex);
    return index_id;
}

int drop_index_catalog(const char* index_name) {
    pthread_mutex_lock(&catalog_mutex);
    
    int found_idx = -1;
    for (int i = 0; i < index_count; i++) {
        if (strcasecmp(indexes[i].name, index_name) == 0) {
            found_idx = i;
            break;
        }
    }
    
    if (found_idx == -1) {
        pthread_mutex_unlock(&catalog_mutex);
        return -1;
    }
    
    for (int i = found_idx; i < index_count - 1; i++) {
        indexes[i] = indexes[i + 1];
    }
    index_count--;
    
    pthread_mutex_unlock(&catalog_mutex);
    return 0;
}

Table* find_table_by_name(const char* name) {
    pthread_mutex_lock(&catalog_mutex);
    for (int i = 0; i < table_count; i++) {
        if (strcasecmp(tables[i].name, name) == 0) {
            pthread_mutex_unlock(&catalog_mutex);
            return &tables[i];
        }
    }
    pthread_mutex_unlock(&catalog_mutex);
    return NULL;
}

Table* find_table_by_id(int table_id) {
    pthread_mutex_lock(&catalog_mutex);
    for (int i = 0; i < table_count; i++) {
        if (tables[i].table_id == table_id) {
            pthread_mutex_unlock(&catalog_mutex);
            return &tables[i];
        }
    }
    pthread_mutex_unlock(&catalog_mutex);
    return NULL;
}

Index* find_index_by_name(const char* name) {
    pthread_mutex_lock(&catalog_mutex);
    for (int i = 0; i < index_count; i++) {
        if (strcasecmp(indexes[i].name, name) == 0) {
            pthread_mutex_unlock(&catalog_mutex);
            return &indexes[i];
        }
    }
    pthread_mutex_unlock(&catalog_mutex);
    return NULL;
}

int get_all_tables(Table* result_tables, int max_tables) {
    pthread_mutex_lock(&catalog_mutex);
    int count = table_count < max_tables ? table_count : max_tables;
    for (int i = 0; i < count; i++) {
        result_tables[i] = tables[i];
    }
    pthread_mutex_unlock(&catalog_mutex);
    return count;
}