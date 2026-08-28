# SQL Server Index Rationalization & Performance Optimization

> Enterprise SQL Server initiative focused on identifying, analyzing and removing redundant indexes to reduce storage consumption, index maintenance overhead and database complexity.

---

## 📌 Project Overview

Over time, enterprise databases can accumulate redundant and overlapping indexes due to application changes, new query patterns, historical performance tuning and development activities.

Although indexes are essential for query performance, unnecessary indexes introduce additional costs:

- Increased storage consumption
- Higher `INSERT`, `UPDATE` and `DELETE` maintenance overhead
- Additional I/O operations
- Longer index maintenance operations
- Larger backup and restore footprints
- Increased database complexity

This project was created to systematically identify **duplicate and redundant indexes** across multiple SQL Server databases.

The analysis goes beyond simple duplicate detection by evaluating:

- Index key columns
- `INCLUDE` columns
- Read activity
- Write activity
- Storage consumption
- Index structure
- Primary and unique constraints
- Potential query coverage

The result was the controlled removal of redundant indexes and approximately **16.27 GB of index storage released**.

---

# 🎯 Objectives

The main objectives of the project were:

1. Identify exact duplicate indexes.
2. Identify indexes with the same key columns but overlapping `INCLUDE` columns.
3. Analyze index read/write activity.
4. Identify indexes with high maintenance cost.
5. Measure the storage footprint of redundant indexes.
6. Determine safe candidates for removal.
7. Reduce unnecessary index maintenance.
8. Simplify the overall indexing strategy.
9. Preserve existing query access paths and workload performance.

---

# 🏗️ Index Rationalization Strategy

The project categorized redundant indexes into two main patterns.

## 1. Exact Duplicate Indexes

Indexes containing the same key columns and ordering.

Example:

```text
Index A
KEY:
    ID_Contrato ASC
    ID_FonteOrigem ASC

Index B
KEY:
    ID_Contrato ASC
    ID_FonteOrigem ASC
```

If both indexes provide the same access path and neither provides additional functionality, one index becomes a candidate for removal.

---

## 2. Same Key Columns with Different INCLUDE Columns

A more complex scenario occurs when indexes have identical key columns but different included columns.

Example:

```text
Index A

KEY:
    ID_usuario
    ID_CRM_Grupo

INCLUDE:
    ID_Cliente
    ID_ClienteTipo
    nrCpfCnpj
    DtSaida
```

```text
Index B

KEY:
    ID_usuario
    ID_CRM_Grupo
```

In this situation, the indexes are not necessarily exact duplicates.

The analysis must determine whether one index already provides sufficient coverage for the workload.

The following factors were considered:

- Query coverage
- `INCLUDE` columns
- Read activity
- Write activity
- Lookup requirements
- Storage footprint
- Workload characteristics

---

# 🔎 Analysis Methodology

The index rationalization process followed these stages:

```text
SQL Server Metadata
        │
        ▼
Index Inventory
        │
        ▼
Duplicate Detection
        │
        ├── Exact Duplicate
        │
        └── Same Key + INCLUDE
        │
        ▼
Usage Analysis
        │
        ├── Reads
        ├── Writes
        └── Read/Write Ratio
        │
        ▼
Storage Analysis
        │
        ▼
Risk Assessment
        │
        ▼
Candidate Validation
        │
        ▼
Controlled Index Removal
        │
        ▼
Post-Change Validation
```

---

# 📊 Analysis Dimensions

## Index Structure

Each index was analyzed according to:

- Key columns
- Column ordering
- Sort direction
- Included columns
- Index type
- Unique indexes
- Primary keys
- Clustered indexes
- Nonclustered indexes

---

## Workload Analysis

SQL Server index usage statistics were analyzed to understand how each index was being used.

Key metrics included:

| Metric | Description |
|---|---|
| `user_seeks` | Number of index seeks |
| `user_scans` | Number of index scans |
| `user_lookups` | Number of key lookups |
| `user_updates` | Number of index maintenance operations |
| Total Reads | Seeks + Scans + Lookups |
| Read/Write Ratio | Relationship between read and write workload |

---

# 💾 Storage Analysis

The physical footprint of each index was also evaluated.

```text
TotalReservedMB
        │
        ▼
Index Storage Footprint
        │
        ▼
Potential Storage Savings
```

This allowed high-impact candidates to be prioritized.

---

# 🛡️ Risk Assessment

An index was not removed solely because it had low usage.

Before removal, candidates were evaluated against:

- Query access patterns
- Read activity
- Write activity
- Key column structure
- `INCLUDE` coverage
- Primary key constraints
- Unique constraints
- Application dependencies
- Potential key lookups
- Potential execution plan regression
- Storage impact

The objective was to remove **redundancy**, not simply reduce the number of indexes.

---

# 🧰 SQL Server Metadata

The analysis used SQL Server catalog views and Dynamic Management Views (DMVs).

```sql
sys.indexes
sys.index_columns
sys.columns
sys.tables
sys.schemas
sys.dm_db_index_usage_stats
sys.dm_db_partition_stats
```

These objects were combined to build an index inventory containing structural, workload and storage information.

---

# 🧪 Example Analysis

A simplified example of the analysis logic:

```sql
SELECT
    DB_NAME() AS DatabaseName,
    OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName,
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    i.is_unique,
    i.is_primary_key,
    i.is_unique_constraint
FROM sys.indexes i
WHERE i.index_id > 0;
```

Index usage statistics were then correlated with index metadata:

```sql
SELECT
    OBJECT_SCHEMA_NAME(i.object_id) AS SchemaName,
    OBJECT_NAME(i.object_id) AS TableName,
    i.name AS IndexName,
    ISNULL(us.user_seeks, 0) AS UserSeeks,
    ISNULL(us.user_scans, 0) AS UserScans,
    ISNULL(us.user_lookups, 0) AS UserLookups,
    ISNULL(us.user_updates, 0) AS UserUpdates
FROM sys.indexes i
LEFT JOIN sys.dm_db_index_usage_stats us
    ON us.database_id = DB_ID()
    AND us.object_id = i.object_id
    AND us.index_id = i.index_id
WHERE i.index_id > 0;
```

Storage information was evaluated using:

```sql
sys.dm_db_partition_stats
```

This combination allowed structural information to be correlated with actual workload behavior.

---

# 📈 Key Findings

The analysis identified redundant indexes across multiple SQL Server databases.

## 🥇 Largest Storage Saving

### `tblCRM_Grupo_Cliente_Analista`

```text
Database:
db_GlobalOne_Servico

Schema:
CB2B

Total Reserved:
36,155.69 MB

Updates:
1,462

Reads:
28,557

Index Removed:
IX_CRM_Grupo_Analista_AUX

Storage Released:
9,038.18 MB
```

Approximately **8.83 GB** of storage was released from this single redundant index.

---

## 🥈 Large Duplicate Index

### `tblSTAGE_MVL_PRODUTO_CAR`

```text
Database:
db_GlobalOne_Telefonica

Total Reserved:
8,514.39 MB

Updates:
745,414

Reads:
39,234

Index Removed:
IDX_MVL_PRODUTO_CAR

Storage Released:
3,230.41 MB
```

Approximately **3.15 GB** was released.

---

## 🥉 Large Storage Reduction

### `tblSTG_EBILLING_old`

```text
Database:
db_GlobalOne_Servico

Total Reserved:
6,324.67 MB

Updates:
0

Reads:
0

Index Removed:
SK01_tblSTG_EBILLING2

Storage Released:
3,162.33 MB
```

This was a strong candidate because the redundant index consumed significant storage while presenting no recorded read or write activity in the analyzed DMV window.

---

# ⚡ High Write-Cost Example

### `TblProposta_LogAPI`

```text
Updates:
3,270,678

Reads:
241

Index Removed:
IX_TblProposta_LogAPI_dtEvento

Storage Released:
70.55 MB
```

Although the storage saving was relatively small, the index represented significant write-maintenance activity.

This demonstrates an important aspect of index rationalization:

> Storage reduction is not the only benefit of removing redundant indexes.

Reducing unnecessary indexes can also reduce maintenance work generated by DML operations.

---

# 🔥 High Read Activity Example

### `TblProposta_Status`

```text
Reads:
319,560,609

Updates:
0

Index Removed:
IX_TblProposta_Status
```

This was an important validation case.

A simplistic index-cleanup process might assume that an index with extremely high reads must be retained.

However, the analysis identified redundancy based on the index structure and the presence of another index providing the required access path.

This reinforces the principle that:

> Index usage statistics must be analyzed together with index structure.

---

# 📊 Project Results

The consolidated analysis produced the following results:

| Metric | Result |
|---|---:|
| Databases | Multiple enterprise databases |
| Redundancy patterns | 2 |
| Storage released | **16,664 MB** |
| Storage released | **~16.27 GB** |
| Largest single saving | **9,038.18 MB** |
| Analysis scope | Multiple schemas and tables |
| Optimization type | Index Rationalization |

---

# 💡 Key Engineering Insights

## 1. Low usage does not automatically mean redundant

An index with low reads may still be important for a specific workload.

Therefore, low utilization alone is insufficient for deletion.

---

## 2. High usage does not automatically mean unique value

An index can have millions of reads and still be redundant if another index provides the same required access path.

---

## 3. INCLUDE columns require deeper analysis

Indexes with identical keys but different `INCLUDE` columns require query coverage analysis before removal.

---

## 4. Indexes have write costs

Every additional nonclustered index may increase the amount of work required for:

```text
INSERT
UPDATE
DELETE
```

operations.

---

## 5. Storage is only one part of the optimization

Index rationalization addresses multiple dimensions:

```text
Storage
   +
Read Performance
   +
Write Performance
   +
Maintenance
   +
Operational Complexity
```

---

# 🏆 Business & Technical Impact

The initiative generated measurable infrastructure and database optimization benefits.

### Storage

**~16.27 GB of index storage released**

### Maintenance

Reduction of unnecessary index maintenance operations.

### Database Footprint

Smaller physical database footprint for redundant index structures.

### Operational Complexity

Reduced number of redundant indexing structures requiring monitoring and maintenance.

### Performance Engineering

Improved alignment between index structures and actual workload requirements.

---

# 🛠️ Technologies

- SQL Server
- T-SQL
- SQL Server DMVs: 
  `sys.indexes`,
  `sys.index_columns`,
  `sys.columns`,
  `sys.dm_db_index_usage_stats`,
  `sys.dm_db_partition_stats`
- Index Rationalization
- Database Performance Tuning
- Query Performance Analysis
- Index Optimization
- Storage Optimization
- Execution Plan Analysis
- Workload Analysis
- Database Engineering

---

# 📌 Conclusion

This project demonstrates a systematic approach to **SQL Server Index Rationalization**, combining database metadata, workload statistics and physical storage analysis to identify redundant indexing structures.

Rather than applying a simple "unused index removal" strategy, the project evaluates the relationship between:

```text
Index Structure
      +
Query Workload
      +
Reads
      +
Writes
      +
Storage
      +
Coverage
```

The result was the identification and controlled removal of redundant indexes, contributing to approximately:

# **16.27 GB of storage released**

while reducing unnecessary index maintenance and improving the overall manageability of the SQL Server environment.

---

# 👨‍💻 Skills Demonstrated

```text
Database Performance Engineering
SQL Server Internals
Index Optimization
Index Rationalization
T-SQL
DMV Analysis
Query Performance
Storage Optimization
Workload Analysis
Database Architecture
Performance Tuning
Database Engineering
```
