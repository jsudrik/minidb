# Query Tests

This directory contains regression tests for MiniDB query functionality.

## Test Categories

- **select_star**: Tests for `SELECT *` queries
- **select_columns**: Tests for `SELECT column_list` queries
- **select_where**: Tests for `SELECT` with `WHERE` clause and various operators

## Adding New Query Tests

To add a new query test:

1. Create a new directory with a descriptive name (e.g., `select_order_by`)
2. Create a `test.sql` file with the SQL commands for the test
3. Run the test once to generate output
4. Review the output and if correct, copy it to `expected.out`

## Test Structure

Each test should:

1. Create any necessary tables
2. Insert test data
3. Execute the query being tested
4. Include a `shutdown` command at the end

## Example

```sql
-- Example test.sql for a new query test
create table test (id int, name varchar(20), value int);
insert into test values (1, 'Alice', 100);
insert into test values (2, 'Bob', 200);
insert into test values (3, 'Charlie', 300);
select * from test where value > 150;
shutdown;
```

## Running Tests

To run all query tests:
```
../run_tests.sh queries
```

To run a specific query test:
```
../run_tests.sh queries select_where
```