#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include "../../common/types.h"
#include "../../common/wal_types.h"

#define MAX_TRANSACTIONS 1000

static Transaction transactions[MAX_TRANSACTIONS];
static uint32_t next_txn_id = 1;
static pthread_mutex_t txn_manager_mutex = PTHREAD_MUTEX_INITIALIZER;

// Read-write lock table for read committed isolation
typedef struct {
    int resource_id;
    pthread_rwlock_t rwlock;
    int readers;
    int writers;
} ResourceLock;

static ResourceLock resource_locks[10000];
static pthread_mutex_t lock_table_mutex = PTHREAD_MUTEX_INITIALIZER;

uint32_t begin_transaction(IsolationLevel isolation) {
    pthread_mutex_lock(&txn_manager_mutex);
    
    uint32_t txn_id = next_txn_id++;
    int idx = txn_id % MAX_TRANSACTIONS;
    
    transactions[idx].txn_id = txn_id;
    transactions[idx].state = TXN_ACTIVE;
    transactions[idx].isolation = isolation;
    pthread_mutex_init(&transactions[idx].txn_mutex, NULL);
    
    pthread_mutex_unlock(&txn_manager_mutex);
    
    // Skip WAL logging for debugging
    // extern uint64_t wal_begin_transaction(uint32_t txn_id);
    // wal_begin_transaction(txn_id);
    
    printf("Transaction %u started with isolation %d\n", txn_id, isolation);
    return txn_id;
}

int acquire_read_lock(uint32_t txn_id, int resource_id) {
    pthread_mutex_lock(&lock_table_mutex);
    
    int hash_key = resource_id % 10000;
    ResourceLock* lock = &resource_locks[hash_key];
    
    if (lock->resource_id == 0) {
        lock->resource_id = resource_id;
        pthread_rwlock_init(&lock->rwlock, NULL);
    }
    
    pthread_mutex_unlock(&lock_table_mutex);
    
    int result = pthread_rwlock_rdlock(&lock->rwlock);
    if (result == 0) {
        lock->readers++;
    }
    
    return result;
}

int acquire_write_lock(uint32_t txn_id, int resource_id) {
    pthread_mutex_lock(&lock_table_mutex);
    
    int hash_key = resource_id % 10000;
    ResourceLock* lock = &resource_locks[hash_key];
    
    if (lock->resource_id == 0) {
        lock->resource_id = resource_id;
        pthread_rwlock_init(&lock->rwlock, NULL);
    }
    
    pthread_mutex_unlock(&lock_table_mutex);
    
    int result = pthread_rwlock_wrlock(&lock->rwlock);
    if (result == 0) {
        lock->writers++;
    }
    
    return result;
}

void release_locks(uint32_t txn_id) {
    pthread_mutex_lock(&lock_table_mutex);
    
    for (int i = 0; i < 10000; i++) {
        if (resource_locks[i].resource_id != 0) {
            pthread_rwlock_unlock(&resource_locks[i].rwlock);
            resource_locks[i].readers = 0;
            resource_locks[i].writers = 0;
        }
    }
    
    pthread_mutex_unlock(&lock_table_mutex);
}

int commit_transaction(uint32_t txn_id) {
    int idx = txn_id % MAX_TRANSACTIONS;
    
    pthread_mutex_lock(&transactions[idx].txn_mutex);
    
    if (transactions[idx].state != TXN_ACTIVE) {
        pthread_mutex_unlock(&transactions[idx].txn_mutex);
        return -1;
    }
    
    // Write WAL commit record and flush to disk
    extern uint64_t wal_commit_transaction(uint32_t txn_id);
    wal_commit_transaction(txn_id);
    
    // Force WAL to disk synchronously
    extern void flush_wal();
    flush_wal();
    
    transactions[idx].state = TXN_COMMITTED;
    release_locks(txn_id);
    
    pthread_mutex_unlock(&transactions[idx].txn_mutex);
    
    printf("Transaction %u committed\n", txn_id);
    return 0;
}

int abort_transaction(uint32_t txn_id) {
    int idx = txn_id % MAX_TRANSACTIONS;
    
    pthread_mutex_lock(&transactions[idx].txn_mutex);
    
    // Skip WAL logging for debugging
    // extern uint64_t wal_abort_transaction(uint32_t txn_id);
    // wal_abort_transaction(txn_id);
    
    transactions[idx].state = TXN_ABORTED;
    release_locks(txn_id);
    
    pthread_mutex_unlock(&transactions[idx].txn_mutex);
    
    printf("Transaction %u aborted\n", txn_id);
    return 0;
}

TransactionState get_transaction_state(uint32_t txn_id) {
    int idx = txn_id % MAX_TRANSACTIONS;
    return transactions[idx].state;
}