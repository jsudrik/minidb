#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#include <sys/mman.h>
#include "../../common/types.h"

#define BUFFER_POOL_SIZE 100

// Shared buffer pool structure
typedef struct {
    Page buffer_pool[BUFFER_POOL_SIZE];
    int lru_counter[BUFFER_POOL_SIZE];
    int global_counter;
    pthread_mutex_t buffer_mutex;
} SharedBufferPool;

static SharedBufferPool* shared_buffer = NULL;

extern int read_page_from_disk(int page_id, char* data);
extern int write_page_to_disk(int page_id, const char* data);

int init_buffer_manager() {
    // Create shared memory for buffer pool
    shared_buffer = mmap(NULL, sizeof(SharedBufferPool), 
                        PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    if (shared_buffer == MAP_FAILED) {
        perror("Buffer pool mmap failed");
        return -1;
    }
    
    // Initialize shared buffer pool
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
    pthread_mutex_init(&shared_buffer->buffer_mutex, &attr);
    pthread_mutexattr_destroy(&attr);
    
    shared_buffer->global_counter = 0;
    
    for (int i = 0; i < BUFFER_POOL_SIZE; i++) {
        shared_buffer->buffer_pool[i].page_id = -1;
        shared_buffer->buffer_pool[i].dirty = false;
        shared_buffer->buffer_pool[i].in_use = false;
        shared_buffer->buffer_pool[i].pin_count = 0;
        
        pthread_mutexattr_init(&attr);
        pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
        pthread_mutex_init(&shared_buffer->buffer_pool[i].page_mutex, &attr);
        pthread_mutexattr_destroy(&attr);
        
        shared_buffer->lru_counter[i] = 0;
    }
    printf("Shared buffer manager initialized with %d pages (4K each)\n", BUFFER_POOL_SIZE);
    return 0;
}

int find_lru_page() {
    int lru_idx = -1;
    int min_counter = shared_buffer->global_counter + 1;
    
    for (int i = 0; i < BUFFER_POOL_SIZE; i++) {
        // Page must not be in use and not pinned to be replaceable
        if (shared_buffer->buffer_pool[i].pin_count == 0) {
            if (shared_buffer->lru_counter[i] < min_counter) {
                min_counter = shared_buffer->lru_counter[i];
                lru_idx = i;
            }
        }
    }
    return lru_idx;
}

Page* get_page(int page_id, uint32_t txn_id) {
    if (!shared_buffer) return NULL;
    
    pthread_mutex_lock(&shared_buffer->buffer_mutex);
    
    // Check if page is already in buffer
    for (int i = 0; i < BUFFER_POOL_SIZE; i++) {
        if (shared_buffer->buffer_pool[i].page_id == page_id && shared_buffer->buffer_pool[i].in_use) {
            pthread_mutex_lock(&shared_buffer->buffer_pool[i].page_mutex);
            shared_buffer->buffer_pool[i].pin_count++;
            shared_buffer->lru_counter[i] = ++shared_buffer->global_counter;
            pthread_mutex_unlock(&shared_buffer->buffer_mutex);
            return &shared_buffer->buffer_pool[i];
        }
    }
    
    // Find LRU page to replace
    int idx = find_lru_page();
    if (idx == -1) {
        pthread_mutex_unlock(&shared_buffer->buffer_mutex);
        printf("No available buffer pages - all pinned\n");
        return NULL;
    }
    
    // If page is dirty and valid, write to disk
    if (shared_buffer->buffer_pool[idx].dirty && shared_buffer->buffer_pool[idx].page_id != -1) {
        write_page_to_disk(shared_buffer->buffer_pool[idx].page_id, shared_buffer->buffer_pool[idx].data);
        printf("Wrote dirty page %d to disk\n", shared_buffer->buffer_pool[idx].page_id);
    }
    
    // Load new page
    shared_buffer->buffer_pool[idx].page_id = page_id;
    if (read_page_from_disk(page_id, shared_buffer->buffer_pool[idx].data) != 0) {
        memset(shared_buffer->buffer_pool[idx].data, 0, PAGE_SIZE);
    }
    
    pthread_mutex_lock(&shared_buffer->buffer_pool[idx].page_mutex);
    
    shared_buffer->buffer_pool[idx].dirty = false;
    shared_buffer->buffer_pool[idx].in_use = true;
    shared_buffer->buffer_pool[idx].pin_count = 1;
    shared_buffer->lru_counter[idx] = ++shared_buffer->global_counter;
    
    pthread_mutex_unlock(&shared_buffer->buffer_mutex);
    
    return &shared_buffer->buffer_pool[idx];
}

void unpin_page(Page* page) {
    if (page && page->pin_count > 0) {
        page->pin_count--;
        pthread_mutex_unlock(&page->page_mutex);
    }
}

void mark_dirty(Page* page) {
    if (page) {
        page->dirty = true;
    }
}

void flush_all_pages() {
    if (!shared_buffer) return;
    
    pthread_mutex_lock(&shared_buffer->buffer_mutex);
    
    int flushed = 0;
    for (int i = 0; i < BUFFER_POOL_SIZE; i++) {
        if (shared_buffer->buffer_pool[i].dirty && shared_buffer->buffer_pool[i].page_id != -1) {
            write_page_to_disk(shared_buffer->buffer_pool[i].page_id, shared_buffer->buffer_pool[i].data);
            shared_buffer->buffer_pool[i].dirty = false;
            flushed++;
        }
    }
    
    pthread_mutex_unlock(&shared_buffer->buffer_mutex);
    printf("Flushed %d dirty pages to disk\n", flushed);
}

void cleanup_buffer_manager() {
    if (shared_buffer) {
        flush_all_pages();
        pthread_mutex_destroy(&shared_buffer->buffer_mutex);
        for (int i = 0; i < BUFFER_POOL_SIZE; i++) {
            pthread_mutex_destroy(&shared_buffer->buffer_pool[i].page_mutex);
        }
        munmap(shared_buffer, sizeof(SharedBufferPool));
        shared_buffer = NULL;
    }
}