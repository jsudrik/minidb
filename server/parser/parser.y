%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include "../../common/types.h"

extern int yylex();
void yyerror(const char* s);

typedef struct {
    enum { 
        STMT_SELECT, 
        STMT_INSERT, 
        STMT_UPDATE,
        STMT_DELETE,
        STMT_CREATE_TABLE, 
        STMT_CREATE_INDEX,
        STMT_DROP_TABLE,
        STMT_DROP_INDEX,
        STMT_DESCRIBE,
        STMT_SHOW_TABLES,
        STMT_BEGIN,
        STMT_COMMIT,
        STMT_ROLLBACK
    } type;
    union {
        struct {
            char table[MAX_NAME_LEN];
            char columns[MAX_COLUMNS][MAX_NAME_LEN];
            int column_count;
            bool select_all;
            char where_clause[MAX_QUERY_LEN];
        } select;
        struct {
            char table[MAX_NAME_LEN];
            Value values[MAX_COLUMNS];
            int value_count;
        } insert;
        struct {
            char table[MAX_NAME_LEN];
            char column[MAX_NAME_LEN];
            Value value;
            char where_clause[MAX_QUERY_LEN];
        } update;
        struct {
            char table[MAX_NAME_LEN];
            char where_clause[MAX_QUERY_LEN];
        } delete;
        struct {
            char table[MAX_NAME_LEN];
            Column columns[MAX_COLUMNS];
            int column_count;
        } create_table;
        struct {
            char index_name[MAX_NAME_LEN];
            char table[MAX_NAME_LEN];
            char column[MAX_NAME_LEN];
            int type;
        } create_index;
        struct {
            char name[MAX_NAME_LEN];
        } drop_table, drop_index, describe;
    } data;
} Statement;

Statement* current_stmt;
%}

%union {
    int num;
    float fval;
    char* str;
}

%token SELECT FROM WHERE INSERT INTO VALUES UPDATE SET DELETE
%token CREATE DROP TABLE INDEX ON USING
%token INT_TYPE BIGINT_TYPE FLOAT_TYPE CHAR_TYPE VARCHAR_TYPE
%token BTREE HASH DESCRIBE SHOW TABLES
%token BEGIN_TXN COMMIT ROLLBACK AND OR
%token EQ NE LT GT LE GE LPAREN RPAREN COMMA SEMICOLON ASTERISK
%token <str> IDENTIFIER STRING
%token <num> NUMBER
%token <fval> FLOAT_NUM

%%
statement: select_stmt | insert_stmt | update_stmt | delete_stmt | 
          create_table_stmt | create_index_stmt | drop_table_stmt | drop_index_stmt |
          describe_stmt | show_stmt | txn_stmt;

select_stmt: SELECT column_list FROM IDENTIFIER where_opt {
    current_stmt->type = STMT_SELECT;
    strcpy(current_stmt->data.select.table, $4);
} | SELECT ASTERISK FROM IDENTIFIER where_opt {
    current_stmt->type = STMT_SELECT;
    strcpy(current_stmt->data.select.table, $4);
    current_stmt->data.select.select_all = true;
};

column_list: IDENTIFIER { 
    strcpy(current_stmt->data.select.columns[0], $1);
    current_stmt->data.select.column_count = 1;
    current_stmt->data.select.select_all = false;
} | column_list COMMA IDENTIFIER {
    strcpy(current_stmt->data.select.columns[current_stmt->data.select.column_count], $3);
    current_stmt->data.select.column_count++;
};

where_opt: /* empty */ | WHERE condition {
    strcpy(current_stmt->data.select.where_clause, "WHERE condition");
};

condition: IDENTIFIER EQ value | IDENTIFIER NE value | 
          IDENTIFIER LT value | IDENTIFIER GT value |
          IDENTIFIER LE value | IDENTIFIER GE value;

insert_stmt: INSERT INTO IDENTIFIER VALUES LPAREN value_list RPAREN {
    current_stmt->type = STMT_INSERT;
    strcpy(current_stmt->data.insert.table, $3);
};

update_stmt: UPDATE IDENTIFIER SET IDENTIFIER EQ value where_opt {
    current_stmt->type = STMT_UPDATE;
    strcpy(current_stmt->data.update.table, $2);
    strcpy(current_stmt->data.update.column, $4);
};

delete_stmt: DELETE FROM IDENTIFIER where_opt {
    current_stmt->type = STMT_DELETE;
    strcpy(current_stmt->data.delete.table, $3);
};

value_list: value {
    current_stmt->data.insert.value_count = 1;
} | value_list COMMA value {
    current_stmt->data.insert.value_count++;
};

value: STRING {
    int idx = current_stmt->data.insert.value_count;
    strcpy(current_stmt->data.insert.values[idx].string_val, $1);
} | NUMBER {
    int idx = current_stmt->data.insert.value_count;
    current_stmt->data.insert.values[idx].int_val = $1;
} | FLOAT_NUM {
    int idx = current_stmt->data.insert.value_count;
    current_stmt->data.insert.values[idx].float_val = $1;
};

create_table_stmt: CREATE TABLE IDENTIFIER LPAREN column_def_list RPAREN {
    current_stmt->type = STMT_CREATE_TABLE;
    strcpy(current_stmt->data.create_table.table, $3);
};

column_def_list: column_def | column_def_list COMMA column_def;

column_def: IDENTIFIER INT_TYPE {
    int idx = current_stmt->data.create_table.column_count;
    strcpy(current_stmt->data.create_table.columns[idx].name, $1);
    current_stmt->data.create_table.columns[idx].type = TYPE_INT;
    current_stmt->data.create_table.columns[idx].size = 4;
    current_stmt->data.create_table.columns[idx].nullable = true;
    current_stmt->data.create_table.column_count++;
} | IDENTIFIER BIGINT_TYPE {
    int idx = current_stmt->data.create_table.column_count;
    strcpy(current_stmt->data.create_table.columns[idx].name, $1);
    current_stmt->data.create_table.columns[idx].type = TYPE_BIGINT;
    current_stmt->data.create_table.columns[idx].size = 8;
    current_stmt->data.create_table.columns[idx].nullable = true;
    current_stmt->data.create_table.column_count++;
} | IDENTIFIER FLOAT_TYPE {
    int idx = current_stmt->data.create_table.column_count;
    strcpy(current_stmt->data.create_table.columns[idx].name, $1);
    current_stmt->data.create_table.columns[idx].type = TYPE_FLOAT;
    current_stmt->data.create_table.columns[idx].size = 4;
    current_stmt->data.create_table.columns[idx].nullable = true;
    current_stmt->data.create_table.column_count++;
} | IDENTIFIER VARCHAR_TYPE LPAREN NUMBER RPAREN {
    int idx = current_stmt->data.create_table.column_count;
    strcpy(current_stmt->data.create_table.columns[idx].name, $1);
    current_stmt->data.create_table.columns[idx].type = TYPE_VARCHAR;
    current_stmt->data.create_table.columns[idx].size = $4;
    current_stmt->data.create_table.columns[idx].nullable = true;
    current_stmt->data.create_table.column_count++;
};

create_index_stmt: CREATE INDEX IDENTIFIER ON IDENTIFIER LPAREN IDENTIFIER RPAREN USING BTREE {
    current_stmt->type = STMT_CREATE_INDEX;
    strcpy(current_stmt->data.create_index.index_name, $3);
    strcpy(current_stmt->data.create_index.table, $5);
    strcpy(current_stmt->data.create_index.column, $7);
    current_stmt->data.create_index.type = INDEX_BTREE;
} | CREATE INDEX IDENTIFIER ON IDENTIFIER LPAREN IDENTIFIER RPAREN USING HASH {
    current_stmt->type = STMT_CREATE_INDEX;
    strcpy(current_stmt->data.create_index.index_name, $3);
    strcpy(current_stmt->data.create_index.table, $5);
    strcpy(current_stmt->data.create_index.column, $7);
    current_stmt->data.create_index.type = INDEX_HASH;
};

drop_table_stmt: DROP TABLE IDENTIFIER {
    current_stmt->type = STMT_DROP_TABLE;
    strcpy(current_stmt->data.drop_table.name, $3);
};

drop_index_stmt: DROP INDEX IDENTIFIER {
    current_stmt->type = STMT_DROP_INDEX;
    strcpy(current_stmt->data.drop_index.name, $3);
};

describe_stmt: DESCRIBE IDENTIFIER {
    current_stmt->type = STMT_DESCRIBE;
    strcpy(current_stmt->data.describe.name, $2);
};

show_stmt: SHOW TABLES {
    current_stmt->type = STMT_SHOW_TABLES;
};

txn_stmt: BEGIN_TXN {
    current_stmt->type = STMT_BEGIN;
} | COMMIT {
    current_stmt->type = STMT_COMMIT;
} | ROLLBACK {
    current_stmt->type = STMT_ROLLBACK;
};

%%

void yyerror(const char* s) {
    fprintf(stderr, "Parse error: %s\n", s);
}

Statement* parse_sql(const char* sql) {
    current_stmt = malloc(sizeof(Statement));
    memset(current_stmt, 0, sizeof(Statement));
    
    yy_scan_string(sql);
    yyparse();
    
    return current_stmt;
}