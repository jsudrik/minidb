#ifndef TYPES_H
#define TYPES_H

#include <stdint.h>
#include <stdbool.h>
#include <pthread.h>

// Platform-specific includes and definitions
#ifdef MACOS
    #include <sys/types.h>
    #ifdef MACOS_ARM64
        // ARM64 specific definitions
        #define PLATFORM_ALIGNMENT 8
    #else
        // x86_64 specific definitions
        #define PLATFORM_ALIGNMENT 8
    #endif
#else
    // Linux/Unix defaults
    #define PLATFORM_ALIGNMENT 8
#endif

#define PAGE_SIZE 4096
#define MAX_COLUMNS 32
#define MAX_NAME_LEN 64
#define MAX_QUERY_LEN 2048
#define MAX_RESULT_ROWS 1000
#define MAX_STRING_LEN 255

typedef enum {
    TYPE_INT,
    TYPE_BIGINT,
    TYPE_FLOAT,
    TYPE_CHAR,
    TYPE_VARCHAR
} DataType;

typedef enum {
    ISOLATION_READ_COMMITTED,
    ISOLATION_REPEATABLE_READ
} IsolationLevel;

typedef enum {
    TXN_ACTIVE,
    TXN_COMMITTED,
    TXN_ABORTED
} TransactionState;

typedef struct {
    uint32_t txn_id;
    TransactionState state;
    IsolationLevel isolation;
    pthread_mutex_t txn_mutex;
} Transaction;

typedef struct {
    char name[MAX_NAME_LEN];
    DataType type;
    int size;
    bool nullable;
} Column;

typedef struct {
    int table_id;
    char name[MAX_NAME_LEN];
    int column_count;
    Column columns[MAX_COLUMNS];
} Table;

typedef struct {
    int index_id;
    char name[MAX_NAME_LEN];
    int table_id;
    char column_name[MAX_NAME_LEN];
    enum { INDEX_BTREE, INDEX_HASH } type;
    int root_page_id;
} Index;

typedef struct {
    int page_id;
    char data[PAGE_SIZE];
    bool dirty;
    bool in_use;
    int pin_count;
    pthread_mutex_t page_mutex;
} Page;

typedef union {
    int int_val;
    int64_t bigint_val;
    float float_val;
    char string_val[MAX_STRING_LEN];
} Value;

typedef struct {
    Column columns[MAX_COLUMNS];
    Value data[MAX_RESULT_ROWS][MAX_COLUMNS];
    int row_count;
    int column_count;
} QueryResult;

// System catalog table IDs
#define SYS_TABLES_ID 1
#define SYS_COLUMNS_ID 2
#define SYS_INDEXES_ID 3
#define SYS_TYPES_ID 4

#endif