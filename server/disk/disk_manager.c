#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <pthread.h>
#include "../../common/types.h"

#ifdef MACOS
    #include <sys/stat.h>
    // macOS specific includes
#endif

static int db_fd = -1;
static pthread_mutex_t disk_mutex = PTHREAD_MUTEX_INITIALIZER;
static int next_page_id = 10;

int init_disk_manager(const char* db_file) {
    pthread_mutex_lock(&disk_mutex);
    
    db_fd = open(db_file, O_RDWR | O_CREAT, 0644);
    if (db_fd == -1) {
        perror("Failed to open database file");
        pthread_mutex_unlock(&disk_mutex);
        return -1;
    }
    
    off_t file_size = lseek(db_fd, 0, SEEK_END);
    if (file_size > 0) {
        next_page_id = (file_size / PAGE_SIZE) + 1;
    }
    
    pthread_mutex_unlock(&disk_mutex);
    printf("Disk manager initialized, file: %s, next_page_id: %d\n", 
           db_file, next_page_id);
    return 0;
}

int read_page_from_disk(int page_id, char* data) {
    if (db_fd == -1) return -1;
    
    pthread_mutex_lock(&disk_mutex);
    
    off_t offset = (off_t)page_id * PAGE_SIZE;
    if (lseek(db_fd, offset, SEEK_SET) == -1) {
        pthread_mutex_unlock(&disk_mutex);
        return -1;
    }
    
    int bytes_read = read(db_fd, data, PAGE_SIZE);
    if (bytes_read < PAGE_SIZE) {
        memset(data + bytes_read, 0, PAGE_SIZE - bytes_read);
    }
    
    pthread_mutex_unlock(&disk_mutex);
    return 0;
}

int write_page_to_disk(int page_id, const char* data) {
    if (db_fd == -1) return -1;
    
    pthread_mutex_lock(&disk_mutex);
    
    off_t offset = (off_t)page_id * PAGE_SIZE;
    if (lseek(db_fd, offset, SEEK_SET) == -1) {
        pthread_mutex_unlock(&disk_mutex);
        return -1;
    }
    
    int bytes_written = write(db_fd, data, PAGE_SIZE);
    if (bytes_written != PAGE_SIZE) {
        pthread_mutex_unlock(&disk_mutex);
        return -1;
    }
    
    fsync(db_fd);
    
    pthread_mutex_unlock(&disk_mutex);
    return 0;
}

int allocate_page() {
    pthread_mutex_lock(&disk_mutex);
    int page_id = next_page_id++;
    pthread_mutex_unlock(&disk_mutex);
    
    return page_id;
}

void close_disk_manager() {
    pthread_mutex_lock(&disk_mutex);
    if (db_fd != -1) {
        fsync(db_fd);
        close(db_fd);
        db_fd = -1;
    }
    pthread_mutex_unlock(&disk_mutex);
}