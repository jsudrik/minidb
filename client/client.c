#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <ctype.h>

#define MAX_QUERY_LEN 2048
#define MAX_RESPONSE_LEN 16384

int connect_to_server(const char* host, int port) {
    int sock = socket(AF_INET, SOCK_STREAM, 0);
    if (sock < 0) {
        perror("Socket creation failed");
        return -1;
    }
    
    struct sockaddr_in addr = {0};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    
    if (inet_pton(AF_INET, host, &addr.sin_addr) <= 0) {
        printf("Invalid address: %s\n", host);
        close(sock);
        return -1;
    }
    
    if (connect(sock, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        perror("Connection failed");
        close(sock);
        return -1;
    }
    
    return sock;
}

char* trim_whitespace(char* str) {
    char* end;
    
    while (isspace((unsigned char)*str)) str++;
    
    if (*str == 0) return str;
    
    end = str + strlen(str) - 1;
    while (end > str && isspace((unsigned char)*end)) end--;
    
    end[1] = '\0';
    return str;
}

void sql_prompt(int sock) {
    char query[MAX_QUERY_LEN];
    char response[MAX_RESPONSE_LEN];
    int query_number = 1;
    
    printf("Connected to MiniDB Server\n");
    printf("Type 'help' for commands, 'quit' to exit\n\n");
    
    while (1) {
        printf("minidb[%d]> ", query_number);
        fflush(stdout);
        
        if (!fgets(query, sizeof(query), stdin)) {
            // Check if we're reading from a pipe/file that's closed
            if (feof(stdin)) {
                // Wait a bit for any pending server response
                fd_set readfds;
                struct timeval timeout;
                FD_ZERO(&readfds);
                FD_SET(sock, &readfds);
                timeout.tv_sec = 1;
                timeout.tv_usec = 0;
                
                if (select(sock + 1, &readfds, NULL, NULL, &timeout) > 0) {
                    char final_response[MAX_RESPONSE_LEN];
                    int bytes = recv(sock, final_response, sizeof(final_response) - 1, 0);
                    if (bytes > 0) {
                        final_response[bytes] = '\0';
                        printf("%s", final_response);
                        if (final_response[bytes-1] != '\n') {
                            printf("\n");
                        }
                    }
                }
            }
            printf("\n");
            break;
        }
        
        char* trimmed_query = trim_whitespace(query);
        
        if (strlen(trimmed_query) == 0) continue;
        
        if (strcasecmp(trimmed_query, "help") == 0) {
            printf("MiniDB Commands:\n");
            printf("  CREATE TABLE name (col1 INT, col2 VARCHAR(50), ...)\n");
            printf("  DROP TABLE name\n");
            printf("  INSERT INTO name VALUES ('val1', 123, ...)\n");
            printf("  UPDATE name SET col = 'value'\n");
            printf("  DELETE FROM name\n");
            printf("  SELECT * FROM name\n");
            printf("  CREATE INDEX idx_name ON table (column) USING BTREE\n");
            printf("  DROP INDEX idx_name\n");
            printf("  DESCRIBE table_name\n");
            printf("  SHOW TABLES\n");
            printf("  COMMIT, ROLLBACK\n");
            printf("  shutdown - Shutdown server\n");
            printf("  quit - Exit client\n\n");
            continue;
        }
        
        if (strcasecmp(trimmed_query, "quit") == 0 || strcasecmp(trimmed_query, "exit") == 0) {
            printf("Disconnecting from server...\n");
            send(sock, trimmed_query, strlen(trimmed_query), 0);
            break;
        }
        
        if (send(sock, trimmed_query, strlen(trimmed_query), 0) < 0) {
            printf("Error: Failed to send query to server\n");
            break;
        }
        
        // Wait for response with timeout
        fd_set readfds;
        struct timeval timeout;
        FD_ZERO(&readfds);
        FD_SET(sock, &readfds);
        timeout.tv_sec = 60;  // 1 minute timeout
        timeout.tv_usec = 0;
        
        int select_result = select(sock + 1, &readfds, NULL, NULL, &timeout);
        if (select_result <= 0) {
            printf("Error: Server response timeout\n");
            break;
        }
        
        memset(response, 0, sizeof(response));
        int bytes = recv(sock, response, sizeof(response) - 1, 0);
        
        if (bytes > 0) {
            response[bytes] = '\0';
            printf("%s", response);
            if (response[bytes-1] != '\n') {
                printf("\n");
            }
            query_number++;
        } else if (bytes == 0) {
            printf("Server disconnected\n");
            break;
        } else {
            printf("Error: Failed to receive response from server\n");
            break;
        }
        
        fflush(stdout);
    }
}

int main(int argc, char* argv[]) {
    const char* host = argc > 1 ? argv[1] : "127.0.0.1";
    int port = argc > 2 ? atoi(argv[2]) : 5432;
    
    printf("MiniDB Client - Connecting to %s:%d...\n", host, port);
    
    int sock = connect_to_server(host, port);
    if (sock < 0) {
        printf("Failed to connect to server\n");
        return 1;
    }
    
    printf("Connected successfully!\n\n");
    
    // Read welcome message from server first
    char welcome[MAX_RESPONSE_LEN];
    int welcome_bytes = recv(sock, welcome, sizeof(welcome) - 1, 0);
    if (welcome_bytes > 0) {
        welcome[welcome_bytes] = '\0';
        printf("%s", welcome);
    }
    
    sql_prompt(sock);
    
    close(sock);
    printf("Connection closed. Goodbye!\n");
    
    return 0;
}