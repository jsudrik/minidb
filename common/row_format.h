#ifndef ROW_FORMAT_H
#define ROW_FORMAT_H

#include <stdint.h>
#include <stdbool.h>

/*
 * MiniDB Row Format Documentation
 * ===============================
 * 
 * DATA ROW FORMAT:
 * +--------+--------+--------+--------+--------+--------+
 * | FLAGS  | FIELD1 | FIELD2 | ...    | FIELDN | PADDING|
 * +--------+--------+--------+--------+--------+--------+
 * |   1B   |   4B   |   8B   |  ...   |  VAR   |   VAR  |
 * +--------+--------+--------+--------+--------+--------+
 * 
 * INDEX ROW FORMAT (B-Tree):
 * +--------+--------+--------+--------+
 * | FLAGS  | KEY    | PAGE_ID| NEXT   |
 * +--------+--------+--------+--------+
 * |   1B   |  VAR   |   4B   |   4B   |
 * 
 * INDEX ROW FORMAT (Hash):
 * +--------+--------+--------+--------+--------+
 * | FLAGS  | KEY    | REC_ID | NEXT   | HASH   |
 * +--------+--------+--------+--------+--------+
 * |   1B   |  VAR   |   4B   |   4B   |   4B   |
 * 
 * FLAGS (1 byte):
 *   Bit 0: DELETE_FLAG (0=active, 1=deleted)
 *   Bit 1: UPDATE_FLAG (0=original, 1=updated)
 *   Bit 2: INDEX_LEAF (0=internal, 1=leaf node)
 *   Bit 3: INDEX_OVERFLOW (0=normal, 1=overflow)
 *   Bit 4-7: Reserved for future use
 * 
 * FIELD FORMAT by type:
 *   TYPE_INT:     4 bytes (little-endian)
 *   TYPE_BIGINT:  8 bytes (little-endian)
 *   TYPE_FLOAT:   4 bytes (IEEE 754)
 *   TYPE_CHAR:    Fixed size (null-padded)
 *   TYPE_VARCHAR: Variable size (null-terminated)
 */

// Row header flags
#define ROW_FLAG_DELETED    0x01
#define ROW_FLAG_UPDATED    0x02
#define ROW_FLAG_INDEX_LEAF 0x04
#define ROW_FLAG_INDEX_OVERFLOW 0x08
#define ROW_FLAG_RESERVED   0xF0

// Row header structure
typedef struct {
    uint8_t flags;          // Row status flags
} RowHeader;

// Row access macros
#define ROW_IS_DELETED(header)  ((header)->flags & ROW_FLAG_DELETED)
#define ROW_IS_UPDATED(header)  ((header)->flags & ROW_FLAG_UPDATED)
#define ROW_IS_INDEX_LEAF(header) ((header)->flags & ROW_FLAG_INDEX_LEAF)
#define ROW_IS_INDEX_OVERFLOW(header) ((header)->flags & ROW_FLAG_INDEX_OVERFLOW)
#define ROW_SET_DELETED(header) ((header)->flags |= ROW_FLAG_DELETED)
#define ROW_SET_UPDATED(header) ((header)->flags |= ROW_FLAG_UPDATED)
#define ROW_SET_INDEX_LEAF(header) ((header)->flags |= ROW_FLAG_INDEX_LEAF)
#define ROW_SET_INDEX_OVERFLOW(header) ((header)->flags |= ROW_FLAG_INDEX_OVERFLOW)
#define ROW_CLEAR_DELETED(header) ((header)->flags &= ~ROW_FLAG_DELETED)
#define ROW_CLEAR_UPDATED(header) ((header)->flags &= ~ROW_FLAG_UPDATED)

// Get pointer to row data (after header)
#define ROW_DATA_PTR(row_ptr) ((char*)(row_ptr) + sizeof(RowHeader))

// Get row header from row pointer
#define ROW_HEADER_PTR(row_ptr) ((RowHeader*)(row_ptr))

// Index row structures
typedef struct {
    RowHeader header;
    Value key;
    int page_id;
    int next_entry;
} BTreeIndexRow;

typedef struct {
    RowHeader header;
    Value key;
    int record_id;
    int next_bucket;
    uint32_t hash_value;
} HashIndexRow;

#endif // ROW_FORMAT_H