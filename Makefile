# Detect platform
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Compiler and flags
CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -pthread -g -DDEBUG
LDFLAGS = -pthread

# macOS specific settings
ifeq ($(UNAME_S),Darwin)
    # macOS ARM64 (Apple Silicon) specific flags
    ifeq ($(UNAME_M),arm64)
        CFLAGS += -arch arm64 -DMACOS_ARM64
        LDFLAGS += -arch arm64
    endif
    # macOS x86_64 specific flags
    ifeq ($(UNAME_M),x86_64)
        CFLAGS += -arch x86_64 -DMACOS_X86_64
        LDFLAGS += -arch x86_64
    endif
    # Common macOS flags
    CFLAGS += -DMACOS
endif

# Server components
SERVER_SOURCES = server/main.c \
                server/network/server.c \
                server/buffer/buffer_manager.c \
                server/disk/disk_manager.c \
                server/storage/storage.c \
                server/executor/executor.c \
                server/optimizer/optimizer.c \
                server/catalog/catalog.c \
                server/transaction/transaction_manager.c \
                server/wal/wal_manager.c \
                server/recovery/recovery_manager.c

# Client
CLIENT_SOURCES = client/client.c

# Targets
all: check-config minidb_server minidb_client

# Check if configure was run
check-config:
	@if [ ! -f config.status ]; then \
		echo "Warning: configure script not run. Run './configure' first to check dependencies."; \
		echo "Continuing with build anyway..."; \
	fi

minidb_server: $(SERVER_SOURCES) server/recovery/page_diagnostics.c
	@echo "Building MiniDB Server with transaction support..."
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)
	@echo "Server build complete!"

minidb_client: $(CLIENT_SOURCES)
	@echo "Building MiniDB Client..."
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)
	@echo "Client build complete!"

# Parser (requires flex and bison)
parser: server/parser/lexer.l server/parser/parser.y
	@echo "Building SQL Parser..."
	cd server/parser && \
	flex lexer.l && \
	bison -d parser.y && \
	$(CC) $(CFLAGS) -c lex.yy.c parser.tab.c
	@echo "Parser build complete!"

# Test targets
test: minidb_server minidb_client
	@echo "Running comprehensive test suite..."
	cd tests && ./run_tests.sh

crashtest: minidb_server minidb_client
	@echo "Running crash recovery test..."
	cd tests && ./crash_recovery_test.sh

# Platform-specific test
platformtest: minidb_server minidb_client
	@echo "Running platform compatibility test..."
	@echo "Platform: $(UNAME_S) $(UNAME_M)"
	./minidb_server 5445 platformtest.db &
	@sleep 2
	@echo "CREATE TABLE platform_test (id INT, name VARCHAR(50))" | ./minidb_client 127.0.0.1 5445 || true
	@echo "INSERT INTO platform_test VALUES ('1', '$(UNAME_S) $(UNAME_M) Test')" | ./minidb_client 127.0.0.1 5445 || true
	@echo "SELECT * FROM platform_test" | ./minidb_client 127.0.0.1 5445 || true
	@pkill -f "minidb_server 5445" || true
	@rm -f platformtest.db platformtest.db.wal
	@echo "Platform test completed!"

# Quick test
quicktest: minidb_server minidb_client
	@echo "Running quick functionality test..."
	./minidb_server 5434 quicktest.db &
	@sleep 2
	@echo "CREATE TABLE test (id INT, name VARCHAR(50))" | timeout 5 ./minidb_client 127.0.0.1 5434 || true
	@echo "INSERT INTO test VALUES ('1', 'Test User')" | timeout 5 ./minidb_client 127.0.0.1 5434 || true
	@echo "SELECT * FROM test" | timeout 5 ./minidb_client 127.0.0.1 5434 || true
	@echo "UPDATE test SET name = 'Updated User'" | timeout 5 ./minidb_client 127.0.0.1 5434 || true
	@echo "SELECT * FROM test" | timeout 5 ./minidb_client 127.0.0.1 5434 || true
	@echo "DELETE FROM test" | timeout 5 ./minidb_client 127.0.0.1 5434 || true
	@echo "DROP TABLE test" | timeout 5 ./minidb_client 127.0.0.1 5434 || true
	@pkill -f "minidb_server 5434" || true
	@rm -f quicktest.db
	@echo "Quick test completed!"

# Sample database with comprehensive data
sample: minidb_server minidb_client
	@echo "Creating comprehensive sample database..."
	./minidb_server 5435 sample.db &
	@sleep 2
	@echo "Creating sample schema and data..."
	@echo "CREATE TABLE employees (id INT, name VARCHAR(100), dept VARCHAR(50), salary FLOAT, emp_id BIGINT)" | timeout 5 ./minidb_client 127.0.0.1 5435 || true
	@echo "CREATE TABLE departments (id INT, name VARCHAR(50), manager_id INT)" | timeout 5 ./minidb_client 127.0.0.1 5435 || true
	@echo "INSERT INTO employees VALUES ('1', 'Alice Johnson', 'Engineering', '75000.0', '1001')" | timeout 5 ./minidb_client 127.0.0.1 5435 || true
	@echo "INSERT INTO employees VALUES ('2', 'Bob Smith', 'Marketing', '65000.0', '1002')" | timeout 5 ./minidb_client 127.0.0.1 5435 || true
	@echo "INSERT INTO employees VALUES ('3', 'Carol Davis', 'Engineering', '80000.0', '1003')" | timeout 5 ./minidb_client 127.0.0.1 5435 || true
	@echo "INSERT INTO employees VALUES ('4', 'David Wilson', 'Sales', '70000.0', '1004')" | timeout 5 ./minidb_client 127.0.0.1 5435 || true
	@echo "INSERT INTO departments VALUES ('1', 'Engineering', '1')" | timeout 5 ./minidb_client 127.0.0.1 5435 || true
	@echo "INSERT INTO departments VALUES ('2', 'Marketing', '2')" | timeout 5 ./minidb_client 127.0.0.1 5435 || true
	@echo "INSERT INTO departments VALUES ('3', 'Sales', '4')" | timeout 5 ./minidb_client 127.0.0.1 5435 || true
	@echo "CREATE INDEX idx_emp_dept ON employees (dept) USING BTREE" | timeout 5 ./minidb_client 127.0.0.1 5435 || true
	@echo "CREATE INDEX idx_emp_salary ON employees (salary) USING HASH" | timeout 5 ./minidb_client 127.0.0.1 5435 || true
	@pkill -f "minidb_server 5435" || true
	@echo "Sample database created: sample.db"
	@echo "Connect with: ./minidb_client"
	@echo "Then run: ./minidb_server 5432 sample.db"

clean:
	@echo "Cleaning build files..."
	rm -f minidb_server minidb_client
	rm -f server/parser/lex.yy.c server/parser/parser.tab.c server/parser/parser.tab.h
	rm -f *.o server/*/*.o
	rm -f *.db minidb.dat test.db quicktest.db
	rm -f config.status
	@echo "Clean complete!"

install: minidb_server minidb_client
	@echo "Installing MiniDB..."
	mkdir -p /usr/local/bin
	cp minidb_server /usr/local/bin/
	cp minidb_client /usr/local/bin/
	@echo "Installation complete!"

uninstall:
	@echo "Uninstalling MiniDB..."
	rm -f /usr/local/bin/minidb_server
	rm -f /usr/local/bin/minidb_client
	@echo "Uninstall complete!"

debug: CFLAGS += -DDEBUG -O0 -ggdb
debug: minidb_server minidb_client

release: CFLAGS += -O2 -DNDEBUG
release: CFLAGS := $(filter-out -g,$(CFLAGS))
release: minidb_server minidb_client

# Help target
help:
	@echo "MiniDB - Complete RDBMS Build System"
	@echo "===================================="
	@echo "Targets:"
	@echo "  all         - Build server and client (default)"
	@echo "  test        - Run comprehensive test suite"
	@echo "  quicktest   - Run quick functionality test"
	@echo "  sample      - Create sample database with test data"
	@echo "  parser      - Build SQL parser (requires flex/bison)"
	@echo "  clean       - Remove all build files"
	@echo "  install     - Install to /usr/local/bin"
	@echo "  uninstall   - Remove from /usr/local/bin"
	@echo "  debug       - Build with debug symbols"
	@echo "  release     - Build optimized release version"
	@echo "  help        - Show this help"
	@echo ""
	@echo "Usage Examples:"
	@echo "  make all && make test"
	@echo "  make sample"
	@echo "  ./minidb_server [port] [database_file]"
	@echo "  ./minidb_client [host] [port]"
	@echo ""
	@echo "Supported SQL Commands:"
	@echo "  CREATE TABLE, DROP TABLE"
	@echo "  INSERT, SELECT, UPDATE, DELETE"
	@echo "  CREATE INDEX, DROP INDEX (BTREE/HASH)"
	@echo "  DESCRIBE, SHOW TABLES"
	@echo "  BEGIN, COMMIT, ROLLBACK"

.PHONY: all check-config clean install uninstall parser test crashtest platformtest quicktest sample debug release help