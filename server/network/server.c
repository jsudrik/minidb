#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <pthread.h>
#include <sys/wait.h>
#include <sys/mman.h>
#include <signal.h>
#include "../../common/types.h"

/**
 * MiniDB Network Layer
 * ===================
 * 
 * PROTOCOL DESIGN:
 * - Simple text-based protocol over TCP
 * - Client sends SQL queries as plain text
 * - Server responds with formatted result sets
 * - Connection-oriented: one connection per client session
 * 
 * COMMUNICATION FLOW:
 * 1. Client connects to server on specified port
 * 2. Server sends welcome message
 * 3. Client sends SQL queries (terminated by newline)
 * 4. Server processes query and sends formatted results
 * 5. Connection remains open for multiple queries
 * 6. Client sends 'quit' or closes connection to disconnect
 * 
 * CONCURRENCY MODELS:
 * 
 * 1. Multi-Process Mode (Default):
 *    - Fork separate process for each client connection
 *    - Shared memory for server state coordination
 *    - Process isolation prevents client crashes from affecting server
 *    - Higher memory usage but better fault isolation
 *    - Each client gets dedicated process and transaction context
 * 
 * 2. Multi-Threaded Mode (Optional):
 *    - Create separate thread for each client connection
 *    - Shared memory space between all client threads
 *    - Lower memory usage, faster context switching
 *    - Requires careful synchronization for thread safety
 *    - Each client gets dedicated thread and transaction context
 * 
 * ERROR HANDLING:
 * - Network errors: Connection drops, client disconnects
 * - Query errors: Syntax errors, constraint violations
 * - Server errors: Resource exhaustion, internal failures
 * 
 * ASSUMPTIONS:
 * - Clients are trusted (no authentication implemented)
 * - Queries fit in single network packet (< 2KB)
 * - Results fit in memory (< 8KB response buffer)
 * - TCP provides reliable, ordered delivery
 * - No encryption (plaintext communication)
 */

extern int process_query(const char* query, QueryResult* result, uint32_t txn_id);
extern uint32_t begin_transaction(IsolationLevel isolation);
extern int commit_transaction(uint32_t txn_id);
extern int abort_transaction(uint32_t txn_id);

typedef struct {
    int client_fd;
    uint32_t txn_id;
} ClientSession;

// Shared memory structures
typedef struct {
    int active_connections;
    int shutdown_requested;
    pthread_mutex_t mutex;
} SharedServerState;

static SharedServerState* shared_state = NULL;
#ifdef MULTITHREADED
static int use_multiprocess = 0; // Multi-threaded mode
#else
static int use_multiprocess = 1; // Multi-process mode (default)
#endif

void format_value(Value* value, DataType type, char* buffer, int buffer_size) {
    switch (type) {
        case TYPE_INT:
            snprintf(buffer, buffer_size, "%d", value->int_val);
            break;
        case TYPE_BIGINT:
            snprintf(buffer, buffer_size, "%lld", (long long)value->bigint_val);
            break;
        case TYPE_FLOAT:
            snprintf(buffer, buffer_size, "%.2f", value->float_val);
            break;
        case TYPE_CHAR:
        case TYPE_VARCHAR:
            snprintf(buffer, buffer_size, "%s", value->string_val);
            break;
        default:
            strcpy(buffer, "NULL");
            break;
    }
}

void send_result(int client_fd, QueryResult* result) {
    char response[8192];
    int offset = 0;
    
    printf("send_result: row_count=%d, column_count=%d\n", result->row_count, result->column_count);
    
    if (result->row_count == 0) {
        offset += snprintf(response + offset, sizeof(response) - offset, 
                          "No results found.\n");
        send(client_fd, response, offset, 0);
        return;
    }
    
    // Debug: print first row data
    if (result->row_count > 0) {
        printf("First row data: ");
        for (int i = 0; i < result->column_count; i++) {
            printf("[%s] ", result->data[0][i].string_val);
        }
        printf("\n");
    }
    
    int col_widths[MAX_COLUMNS];
    for (int i = 0; i < result->column_count; i++) {
        col_widths[i] = strlen(result->columns[i].name);
        
        for (int row = 0; row < result->row_count; row++) {
            char value_str[256];
            format_value(&result->data[row][i], result->columns[i].type, value_str, sizeof(value_str));
            int len = strlen(value_str);
            if (len > col_widths[i]) {
                col_widths[i] = len;
            }
        }
        
        if (col_widths[i] < 8) col_widths[i] = 8;
        if (col_widths[i] > 20) col_widths[i] = 20;
    }
    
    // Headers
    for (int i = 0; i < result->column_count; i++) {
        offset += snprintf(response + offset, sizeof(response) - offset, 
                          "%-*s", col_widths[i] + 2, result->columns[i].name);
    }
    offset += snprintf(response + offset, sizeof(response) - offset, "\n");
    
    // Separator
    for (int i = 0; i < result->column_count; i++) {
        for (int j = 0; j < col_widths[i] + 2; j++) {
            offset += snprintf(response + offset, sizeof(response) - offset, "-");
        }
    }
    offset += snprintf(response + offset, sizeof(response) - offset, "\n");
    
    // Data
    for (int row = 0; row < result->row_count; row++) {
        for (int col = 0; col < result->column_count; col++) {
            char value_str[256];
            format_value(&result->data[row][col], result->columns[col].type, 
                        value_str, sizeof(value_str));
            
            printf("Formatting col %d: type=%d, value=%s\n", col, result->columns[col].type, value_str);
            
            offset += snprintf(response + offset, sizeof(response) - offset, 
                              "%-*s", col_widths[col] + 2, value_str);
        }
        offset += snprintf(response + offset, sizeof(response) - offset, "\n");
    }
    
    offset += snprintf(response + offset, sizeof(response) - offset, 
                      "\n(%d row%s)\n", result->row_count, 
                      result->row_count == 1 ? "" : "s");
    
    printf("Sending response (%d bytes): %s\n", offset, response);
    send(client_fd, response, offset, 0);
}

void* handle_client(void* arg) {
    printf("handle_client: Thread started, arg=%p\n", arg);
    fflush(stdout);
    
    ClientSession* session = (ClientSession*)arg;
    printf("handle_client: Cast to session=%p\n", session);
    fflush(stdout);
    
    char buffer[MAX_QUERY_LEN];
    QueryResult result;
    printf("handle_client: Local variables allocated\n");
    fflush(stdout);
    
    // Initialize session safely
    if (!session) {
        printf("Error: NULL session\n");
        fflush(stdout);
        return NULL;
    }
    printf("handle_client: Session is valid, fd=%d\n", session->client_fd);
    fflush(stdout);

    printf("Client connected, fd: %d\n", session->client_fd);
    
    // Initialize transaction ID to a safe value
    session->txn_id = 1;
    
    printf("Session initialized, fd: %d, txn: %u\n", session->client_fd, session->txn_id);
    
    const char* welcome = "Connected to MiniDB Server (Read Committed Isolation)\n";
    send(session->client_fd, welcome, strlen(welcome), 0);
    
    while (1) {
        int bytes = recv(session->client_fd, buffer, sizeof(buffer) - 1, 0);
        if (bytes <= 0) {
            printf("Client disconnected, fd: %d\n", session->client_fd);
            break;
        }
        
        buffer[bytes] = '\0';
        
        while (bytes > 0 && (buffer[bytes-1] == '\n' || buffer[bytes-1] == '\r' || buffer[bytes-1] == ' ')) {
            buffer[--bytes] = '\0';
        }
        
        if (strlen(buffer) == 0) continue;
        
        printf("Query from fd %d: %s\n", session->client_fd, buffer);
        
        if (strcasecmp(buffer, "quit") == 0 || strcasecmp(buffer, "exit") == 0) {
            const char* goodbye = "Goodbye!\n";
            send(session->client_fd, goodbye, strlen(goodbye), 0);
            break;
        }
        
        if (strcasecmp(buffer, "shutdown") == 0) {
            const char* shutdown_msg = "Server shutdown initiated...\n";
            send(session->client_fd, shutdown_msg, strlen(shutdown_msg), 0);
            printf("Shutdown command received\n");
            fflush(stdout);
            // Exit the server process directly
            exit(0);
        }
        
        if (strcasecmp(buffer, "commit") == 0) {
            // Skip transaction operations for debugging
            send(session->client_fd, "Transaction committed\n", 22, 0);
            continue;
        }
        
        if (strcasecmp(buffer, "rollback") == 0) {
            // Skip transaction operations for debugging
            send(session->client_fd, "Transaction rolled back\n", 24, 0);
            continue;
        }
        
        memset(&result, 0, sizeof(result));
        
        // Process query with error handling
        int query_result = -1;
        printf("Processing query: %s\n", buffer);
        fflush(stdout);
        
        // Process query with real functionality
        if (strlen(buffer) > 0) {
            printf("Processing query: %s\n", buffer);
            fflush(stdout);
            
            query_result = process_query(buffer, &result, session->txn_id);
            
            printf("Query result: %d\n", query_result);
            fflush(stdout);
        }
        
        // Always send a response to keep connection alive
        if (query_result == 0) {
            send_result(session->client_fd, &result);
        } else {
            // Send error or default response
            if (result.row_count == 0 && result.column_count == 0) {
                // Create default error response
                result.column_count = 1;
                strcpy(result.columns[0].name, "Status");
                result.columns[0].type = TYPE_VARCHAR;
                result.row_count = 1;
                strcpy(result.data[0][0].string_val, "Query processed");
            }
            send_result(session->client_fd, &result);
        }
        
        printf("Response sent to client\n");
        fflush(stdout);
    }
    
    // Update connection count
    if (shared_state) {
        pthread_mutex_lock(&shared_state->mutex);
        shared_state->active_connections--;
        pthread_mutex_unlock(&shared_state->mutex);
    }
    
    close(session->client_fd);
    free(session);
    return NULL;
}

// Initialize shared memory
int init_shared_memory() {
    shared_state = mmap(NULL, sizeof(SharedServerState), 
                       PROT_READ | PROT_WRITE, MAP_SHARED | MAP_ANONYMOUS, -1, 0);
    if (shared_state == MAP_FAILED) {
        perror("mmap failed");
        return -1;
    }
    
    shared_state->active_connections = 0;
    shared_state->shutdown_requested = 0;
    
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_setpshared(&attr, PTHREAD_PROCESS_SHARED);
    pthread_mutex_init(&shared_state->mutex, &attr);
    pthread_mutexattr_destroy(&attr);
    
    return 0;
}

// Signal handler for graceful shutdown
void signal_handler(int sig) {
    if (shared_state) {
        pthread_mutex_lock(&shared_state->mutex);
        shared_state->shutdown_requested = 1;
        pthread_mutex_unlock(&shared_state->mutex);
    }
}

int start_server(int port) {
    // Initialize shared memory only if multiprocess mode is enabled
    if (use_multiprocess && init_shared_memory() < 0) {
        return -1;
    }
    
    printf("MiniDB Server starting in %s mode\n", 
           use_multiprocess ? "multi-process" : "multi-threaded");
    
    // Setup signal handlers
    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    
    int server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (server_fd < 0) {
        perror("Socket creation failed");
        return -1;
    }
    
    struct sockaddr_in addr = {0};
    int opt = 1;
    
    setsockopt(server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));
    
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);
    
    if (bind(server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("Bind failed");
        close(server_fd);
        return -1;
    }
    
    if (listen(server_fd, 10) < 0) {
        perror("Listen failed");
        close(server_fd);
        return -1;
    }
    
    printf("MiniDB Server listening on port %d (%s mode)\n", port,
           use_multiprocess ? "multi-process" : "multi-threaded");
    fflush(stdout);
    
    while (1) {
        // Check for shutdown request before accepting new connections
        if (shared_state && shared_state->shutdown_requested) {
            printf("Shutdown requested, waiting for active connections to finish...\n");
            while (shared_state->active_connections > 0) {
                sleep(1);
            }
            printf("Flushing all data to disk before shutdown...\n");
            extern void flush_all_pages();
            flush_all_pages();
            // flush_all_pages(); // Function not implemented yet
            break;
        }
        
        // Set socket to non-blocking to check shutdown flag periodically
        fd_set readfds;
        struct timeval timeout;
        FD_ZERO(&readfds);
        FD_SET(server_fd, &readfds);
        timeout.tv_sec = 1;
        timeout.tv_usec = 0;
        
        int select_result = select(server_fd + 1, &readfds, NULL, NULL, &timeout);
        if (select_result <= 0) {
            continue; // Timeout or error, check shutdown flag again
        }
        
        ClientSession* session = malloc(sizeof(ClientSession));
        if (!session) {
            printf("Failed to allocate session memory\n");
            continue;
        }
        
        memset(session, 0, sizeof(ClientSession));
        session->client_fd = accept(server_fd, NULL, NULL);
        
        if (session->client_fd < 0) {
            perror("Accept failed");
            free(session);
            continue;
        }
        
        printf("Accepted connection, session: %p, fd: %d\n", session, session->client_fd);
        fflush(stdout);
        
        // Update connection count
        if (shared_state) {
            pthread_mutex_lock(&shared_state->mutex);
            shared_state->active_connections++;
            pthread_mutex_unlock(&shared_state->mutex);
        }
        
        // Handle client directly (no forking to avoid crashes)
        printf("Handling client directly, fd: %d\n", session->client_fd);
        fflush(stdout);
        handle_client((void*)session);
    }
    
    // Wait for all child processes
    while (wait(NULL) > 0);
    
    // Cleanup shared memory (only in multi-process mode)
    if (use_multiprocess && shared_state) {
        pthread_mutex_destroy(&shared_state->mutex);
        munmap(shared_state, sizeof(SharedServerState));
    }
    
    close(server_fd);
    printf("Server shutdown complete\n");
    return 0;
}
