#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <limits.h>
#include "../../common/types.h"

typedef struct {
    enum { OP_SCAN, OP_INDEX_SCAN, OP_SELECT, OP_PROJECT, OP_JOIN } type;
    char table_name[MAX_NAME_LEN];
    char index_name[MAX_NAME_LEN];
    char columns[MAX_COLUMNS][MAX_NAME_LEN];
    int column_count;
    int estimated_cost;
    int estimated_rows;
    int selectivity;
} QueryPlan;

extern Table* find_table_by_name(const char* name);

int estimate_table_size(const char* table_name) {
    Table* table = find_table_by_name(table_name);
    if (!table) return 0;
    
    if (table->table_id <= 4) {
        return 10; // System tables
    }
    return 1000; // User tables
}

int estimate_scan_cost(const char* table_name) {
    int table_size = estimate_table_size(table_name);
    return (table_size / 50) + 1; // Pages to read
}

int estimate_index_scan_cost(const char* table_name) {
    int table_size = estimate_table_size(table_name);
    return (table_size / 1000) + 1; // Much faster
}

QueryPlan* optimize_select_query(const char* table_name, 
                                const char* columns[], 
                                int column_count,
                                const char* where_clause) {
    QueryPlan* plan = malloc(sizeof(QueryPlan));
    memset(plan, 0, sizeof(QueryPlan));
    
    strcpy(plan->table_name, table_name);
    plan->column_count = column_count;
    
    for (int i = 0; i < column_count; i++) {
        strcpy(plan->columns[i], columns[i]);
    }
    
    int seq_cost = estimate_scan_cost(table_name);
    int index_cost = INT_MAX;
    
    if (where_clause && strstr(where_clause, "=")) {
        index_cost = estimate_index_scan_cost(table_name);
        plan->selectivity = 10;
    } else {
        plan->selectivity = 100;
    }
    
    if (index_cost < seq_cost && where_clause) {
        plan->type = OP_INDEX_SCAN;
        plan->estimated_cost = index_cost;
        plan->estimated_rows = estimate_table_size(table_name) * plan->selectivity / 100;
        printf("Optimizer: Index scan chosen, cost=%d, rows=%d\n", 
               plan->estimated_cost, plan->estimated_rows);
    } else {
        plan->type = OP_SCAN;
        plan->estimated_cost = seq_cost;
        plan->estimated_rows = estimate_table_size(table_name);
        printf("Optimizer: Sequential scan chosen, cost=%d, rows=%d\n", 
               plan->estimated_cost, plan->estimated_rows);
    }
    
    return plan;
}

QueryPlan* optimize_insert_query(const char* table_name, int value_count) {
    QueryPlan* plan = malloc(sizeof(QueryPlan));
    memset(plan, 0, sizeof(QueryPlan));
    
    plan->type = OP_SELECT;
    strcpy(plan->table_name, table_name);
    plan->estimated_cost = 5 + value_count;
    plan->estimated_rows = 1;
    
    printf("Optimizer: Insert plan, cost=%d\n", plan->estimated_cost);
    return plan;
}

QueryPlan* optimize_update_query(const char* table_name, const char* where_clause) {
    QueryPlan* plan = malloc(sizeof(QueryPlan));
    memset(plan, 0, sizeof(QueryPlan));
    
    plan->type = OP_SELECT;
    strcpy(plan->table_name, table_name);
    
    if (where_clause && strlen(where_clause) > 0) {
        plan->estimated_cost = estimate_index_scan_cost(table_name) + 10;
        plan->estimated_rows = estimate_table_size(table_name) / 10;
    } else {
        plan->estimated_cost = estimate_scan_cost(table_name) + 20;
        plan->estimated_rows = estimate_table_size(table_name);
    }
    
    printf("Optimizer: Update plan, cost=%d, rows=%d\n", 
           plan->estimated_cost, plan->estimated_rows);
    return plan;
}

QueryPlan* optimize_delete_query(const char* table_name, const char* where_clause) {
    QueryPlan* plan = malloc(sizeof(QueryPlan));
    memset(plan, 0, sizeof(QueryPlan));
    
    plan->type = OP_SELECT;
    strcpy(plan->table_name, table_name);
    
    if (where_clause && strlen(where_clause) > 0) {
        plan->estimated_cost = estimate_index_scan_cost(table_name) + 5;
        plan->estimated_rows = estimate_table_size(table_name) / 10;
    } else {
        plan->estimated_cost = estimate_scan_cost(table_name) + 10;
        plan->estimated_rows = estimate_table_size(table_name);
    }
    
    printf("Optimizer: Delete plan, cost=%d, rows=%d\n", 
           plan->estimated_cost, plan->estimated_rows);
    return plan;
}

void free_query_plan(QueryPlan* plan) {
    if (plan) {
        free(plan);
    }
}