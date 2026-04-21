# SQL Server Transactional Replication — Setup Guide

This guide walks through the complete setup of SQL Server Transactional Replication between two servers:

- **Publisher / Distributor**: `SRVDB1` (or your local server name)
- **Subscriber**: `SRVDB2`

---

## Architecture Overview

```
┌─────────────────────────────────┐        ┌──────────────────────┐
│  PUBLISHER / DISTRIBUTOR        │        │  SUBSCRIBER          │
│  (SRVDB1)                       │        │  (SRVDB2)            │
│                                 │        │                      │
│  DB: ReplicationTestDB  ────────│────────│───► DB: ReplDB       │
│  DB: DistDB (distribution)      │        │                      │
│  Share: \\SRVDB1\ReplData       │        │                      │
└─────────────────────────────────┘        └──────────────────────┘
```

---

## Replication Agent Accounts

| Account | Role | Created On |
|---|---|---|
| `repl_snapshot` | Snapshot Agent | Publisher only |
| `repl_logreader` | Log Reader Agent | Publisher only |
| `repl_distribution` | Distribution Agent | Publisher + Subscriber |
| `repl_merge` | Merge Agent | Publisher + Subscriber |

> **Note:** All accounts are local Windows accounts (not domain accounts).  
> Agent account password used throughout: `Poste@2025`  
> Distributor admin password (separate): `Str0ng!Pass_2026`

---

## Global Parameters Reference

These values appear across multiple scripts. Decide on them before you start and apply them consistently everywhere.

| Parameter | Default Value | Used In |
|---|---|---|
| Publisher server name | `@@SERVERNAME` (auto) | All publisher scripts |
| Subscriber server name | `SRVDB2` | `addHost.ps1`, `createSub.sql` |
| Subscriber IP address | `172.29.104.60` | `addHost.ps1` |
| Distribution database name | `DistDB` | `createDistribution.sql` |
| Publisher database name | `ReplicationTestDB` | `testPrepa.sql`, `addDbowner.sql`, `createPub.sql`, `createSub.sql` |
| Subscriber database name | `ReplDB` | `createRepldb.sql`, `createSub.sql` |
| Publication name | `RepTest_Pub` | `createPub.sql`, `createSub.sql` |
| SMB share name | `ReplData` | `addPermisions2Repldata.ps1` |
| SQL Server version folder | `MSSQL15.MSSQLSERVER` | `addPermisions2Repldata.ps1` |
| Agent accounts password | `Poste@2025` | `createUsers_pub.ps1`, `createUser_sub.ps1`, `createPub.sql`, `createSub.sql` |
| Distributor admin password | `Str0ng!Pass_2026` | `createDistribution.sql` |
| Subscriber SA login | `sa` | `createSub.sql` |
| Subscriber SA password | `P@ssw0rd` | `createSub.sql` |
| Account prefix (domain or server) | `@@SERVERNAME` (auto) | `addNewLogins2sql.sql`, `addNewLogin2sql_sub.sql`, `addDbowner.sql` |

---

## Execution Order

### ⚙️ PRE-FLIGHT — Run once if needed

#### Fix `@@SERVERNAME` mismatch (Error 18483)

```
Script : MSSQLSERVER_18483.sql
Run on : Publisher (SRVDB1)
Run in : SSMS → master database
```

**When to run:** Only if you encounter error 18483, or if the two queries below return different values:
```sql
SELECT @@SERVERNAME;
SELECT SERVERPROPERTY('ServerName');
```

This corrects the mismatch that occurs after a machine rename. **Restart the SQL Server service after running this script.**

**No configurable parameters** — the script uses both system functions automatically.

---

### 🖥️ PUBLISHER SIDE — Steps 1 to 8

---

#### Step 1 — Fix PATH Environment Variable

```
Script : addEnvVar.ps1
Run on : Publisher (SRVDB1)
Run as : Administrator (PowerShell)
```

Prepends `%SystemRoot%\SysWOW64\` and `%SystemRoot%\SysWOW64\1033` to the system `PATH`. This prevents replication agents from failing to locate required COM DLLs.

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `$p1` | `%SystemRoot%\SysWOW64\` | First path to prepend — do not change |
| `$p2` | `%SystemRoot%\SysWOW64\1033` | Second path to prepend — do not change |

> ⚠️ Run this **before** creating any agent accounts or services.

---

#### Step 2 — Create Windows Accounts on Publisher

```
Script : createUsers_pub.ps1
Run on : Publisher (SRVDB1)
Run as : Administrator (PowerShell)
```

Creates 4 local Windows user accounts with **Password Never Expires** enabled:
`repl_snapshot`, `repl_logreader`, `repl_distribution`, `repl_merge`

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `$Password` | `Poste@2025` | Password assigned to all 4 accounts |
| Keys in `$Accounts` | `repl_snapshot`, `repl_logreader`, `repl_distribution`, `repl_merge` | Account names — change if using domain accounts instead |

---

#### Step 3 — Register Accounts as SQL Server Logins (Publisher)

```
Script : addNewLogins2sql.sql
Run on : Publisher (SRVDB1)
Run in : SSMS → master database
```

Creates Windows logins in SQL Server for all 4 replication accounts.

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `@prefix` | `@@SERVERNAME` | Server or domain name prefixed to each account (e.g. `SRVDB1\repl_snapshot`). Change to your domain name if using domain accounts: `SET @prefix = 'MYDOMAIN'` |
| `@accounts` table | 4 agent accounts | Add or remove account names as needed |

---

#### Step 4 — Configure the Distributor

```
Script : createDistribution.sql
Run on : Publisher (SRVDB1)
Run in : SSMS → master database
```

Registers the local server as its own Distributor, creates the distribution database, and registers the Publisher.

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `@Distributor` | `@@SERVERNAME` | Distributor server name — auto-detected, do not change |
| `@DistributionDB` | `DistDB` | Name of the distribution database to create |
| `@SnapshotFolder` | `\\<SERVERNAME>\ReplData` | UNC path to the snapshot share — auto-built from server name |
| `@Password` | `Str0ng!Pass_2026` | Distributor admin password — **change this in production** |

> ⚠️ The SMB share (`ReplData`) must exist before running this script. Run **Step 5 first** if the share does not yet exist, then return to run Step 4.

---

#### Step 5 — Create the ReplData Share & Set Permissions

```
Script : addPermisions2Repldata.ps1
Run on : Publisher (SRVDB1)
Run as : Administrator (PowerShell)
```

Creates the `ReplData` SMB share and applies both SMB and NTFS permissions per agent role.

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `$path` | `C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\repldata` | Physical path to the repldata folder. **Update `MSSQL15` to match your SQL Server version** (`MSSQL15` = SQL 2019, `MSSQL16` = SQL 2022, `MSSQL14` = SQL 2017) |
| `$shareName` | `ReplData` | SMB share name — must match `@SnapshotFolder` in `createDistribution.sql` |
| `$repl_distribution` | `repl_distribution` | Account granted Read access on the share |
| `$repl_merge` | `repl_merge` | Account granted Read access on the share |
| `$repl_snapshot` | `repl_snapshot` | Account granted Full Control on the share |

---

#### Step 6 — Prepare the Publisher Database

```
Script : testPrepa.sql
Run on : Publisher (SRVDB1)
Run in : SSMS
Status : ⭐ OPTIONAL — skip if you already have a database to replicate
```

**Use this step only if you do not already have a source database.** This script creates a clean `ReplicationTestDB` database with sample tables and data specifically for testing replication end-to-end.

> ⚠️ **This script drops and recreates `ReplicationTestDB` unconditionally if it already exists. Do NOT run it if you have an existing database you want to replicate — all data will be lost.**

**If you already have a database**, skip this step entirely and update the database name referenced in the remaining scripts to match your existing database (see the [If You Already Have a Database](#if-you-already-have-a-database-skipping-step-6) section below).

**Parameters in this script:**

| Item | Default | Description |
|---|---|---|
| Database name | `ReplicationTestDB` | Change the `CREATE DATABASE` and `USE` statements at the top if you want a different name |
| Snapshot boundary marker | `-- >>> RUN SNAPSHOT AGENT HERE <<<` | Everything above this line is snapshot data; everything below simulates post-snapshot changes |

**What this script creates:**

- Tables: `Customers`, `Products`, `Orders`, `OrderDetails`
- Initial seed rows (delivered via snapshot)
- Post-snapshot DML: INSERTs, UPDATEs, DELETEs, identity insert, bulk insert, transactional block

> **Tip:** When testing, pause execution at the `-- >>> RUN SNAPSHOT AGENT HERE <<<` marker, let the Snapshot Agent run, verify the subscriber received the data, then continue with the post-snapshot DML section.

---

#### Step 7 — Grant db_owner to Replication Accounts

```
Script : addDbowner.sql
Run on : Publisher (SRVDB1)
Run in : SSMS → master database
```

Adds all 4 replication accounts as `db_owner` in both the distribution database and the publisher database.

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `@prefix` | `@@SERVERNAME` | Server or domain prefix for account names. Change to `'MYDOMAIN'` if using domain accounts |
| `@databases` table | `distribution`, `ReplicationTestDB` | **Replace `ReplicationTestDB`** with your actual publisher database name if you skipped Step 6 |
| `@accounts` table | 4 agent accounts | Add or remove accounts as needed |

> ⚠️ Run this **after** both the distribution database (Step 4) and the publisher database (Step 6 or your existing DB) exist.

---

#### Step 8 — Create the Publication

```
Script : createPub.sql
Run on : Publisher (SRVDB1)
Run in : SSMS → [your publisher database]
```

Enables publishing, creates the publication `RepTest_Pub`, configures Snapshot and Log Reader agents, adds all user tables as articles, and starts the Snapshot Agent.

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `USE [ReplicationTestDB]` at top | `ReplicationTestDB` | **Change to your actual publisher database name** if you skipped Step 6 |
| `@Publication` | `RepTest_Pub` | Publication name — must match `@Publication` in `createSub.sql` |
| `@SnapshotLogin` | `@@SERVERNAME\repl_snapshot` | Snapshot Agent Windows account — auto-built from server name |
| `@LogReaderLogin` | `@@SERVERNAME\repl_logreader` | Log Reader Agent Windows account — auto-built from server name |
| `@Password` | `Poste@2025` | Password for both agent accounts above |

> ⚠️ **Wait for the Snapshot Agent to complete successfully** before moving to the Subscriber steps. Monitor progress in SSMS → Replication Monitor → Snapshot Agent status column.

---

### 🖥️ SUBSCRIBER SIDE — Steps 9 to 12

---

#### Step 9 — Add Subscriber to Publisher's Hosts File

```
Script : addHost.ps1
Run on : Publisher (SRVDB1)
Run as : Administrator (PowerShell)
```

Adds an entry for `SRVDB2` into the `hosts` file on the Publisher, enabling name resolution without DNS.

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `$Hostname` | `SRVDB2` | **Change** to your subscriber's actual server name |
| `$IPAddress` | `172.29.104.60` | **Change** to your subscriber's actual IP address |

---

#### Step 10 — Create Windows Accounts on Subscriber

```
Script : createUser_sub.ps1
Run on : Subscriber (SRVDB2)
Run as : Administrator (PowerShell)
```

Creates 2 local Windows accounts on the subscriber: `repl_distribution` and `repl_merge`, with **Password Never Expires** enabled.

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `$Password` | `Poste@2025` | Password for both accounts — must match `@DistPassword` in `createSub.sql` |
| Keys in `$Accounts` | `repl_distribution`, `repl_merge` | Account names — change if using domain accounts |

---

#### Step 11 — Register Accounts as SQL Server Logins (Subscriber)

```
Script : addNewLogin2sql_sub.sql
Run on : Subscriber (SRVDB2)
Run in : SSMS → master database
```

Creates Windows logins for `repl_distribution` and `repl_merge` on the subscriber SQL instance.

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `@prefix` | `@@SERVERNAME` | Evaluated on the subscriber, so it resolves to `SRVDB2` automatically. Change to `'MYDOMAIN'` for domain accounts |
| `@accounts` table | `repl_distribution`, `repl_merge` | Add or remove accounts as needed |

---

#### Step 12 — Create Subscriber Database & Permissions

```
Script : createRepldb.sql
Run on : Subscriber (SRVDB2)
Run in : SSMS
```

Creates the `ReplDB` destination database if it does not exist, creates users for the two agent accounts, and grants `db_owner` to both.

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `'ReplDB'` in `DB_ID` check | `ReplDB` | **Change** to your desired subscriber database name |
| `@DistLogin` | `@@SERVERNAME\repl_distribution` | Distribution agent account — auto-built from the subscriber server name |
| `@MergeLogin` | `@@SERVERNAME\repl_merge` | Merge agent account — auto-built from the subscriber server name |

---

### 🔗 FINALIZE — Step 13

#### Step 13 — Create the Push Subscription

```
Script : createSub.sql
Run on : Publisher (SRVDB1)
Run in : SSMS → [your publisher database]
```

Creates a Push Subscription from the publication to the subscriber, and configures the Distribution Agent job to run continuously.

**Parameters in this script:**

| Variable | Default | Description |
|---|---|---|
| `USE [ReplicationTestDB]` at top | `ReplicationTestDB` | **Change to your actual publisher database name** if you skipped Step 6 |
| `@Publication` | `RepTest_Pub` | Must match the publication name from Step 8 |
| `@Subscriber` | `SRVDB2` | **Change** to your subscriber server name |
| `@SubscriberDB` | `ReplDB` | **Change** to your subscriber database name (must match Step 12) |
| `@DistLogin` | `@@SERVERNAME\repl_distribution` | Distribution Agent Windows account — auto-built |
| `@DistPassword` | `Poste@2025` | Password for the distribution agent account |
| `@subscriber_security_mode` | `0` | `0` = SQL auth, `1` = Windows auth for the subscriber connection |
| `@subscriber_login` | `sa` | **Change** to a least-privilege SQL login in production |
| `@subscriber_password` | `P@ssw0rd` | **Change** to match your subscriber SQL login password |
| `@frequency_type` | `64` | `64` = run continuously — do not change for transactional replication |

---

## Full Execution Order Summary

| # | Script | Run On | How | Optional? |
|---|---|---|---|---|
| 0 | `MSSQLSERVER_18483.sql` | Publisher | SSMS | ✅ Only if error 18483 occurs |
| 1 | `addEnvVar.ps1` | Publisher | PowerShell (Admin) | — |
| 2 | `createUsers_pub.ps1` | Publisher | PowerShell (Admin) | — |
| 3 | `addNewLogins2sql.sql` | Publisher | SSMS | — |
| 5* | `addPermisions2Repldata.ps1` | Publisher | PowerShell (Admin) | — |
| 4* | `createDistribution.sql` | Publisher | SSMS | — |
| **6** | **`testPrepa.sql`** | **Publisher** | **SSMS** | **⭐ Optional — skip if DB exists** |
| 7 | `addDbowner.sql` | Publisher | SSMS | — |
| 8 | `createPub.sql` | Publisher | SSMS | — |
| — | ⏳ **Wait for Snapshot Agent to complete** | — | Replication Monitor | — |
| 9 | `addHost.ps1` | Publisher | PowerShell (Admin) | — |
| 10 | `createUser_sub.ps1` | Subscriber | PowerShell (Admin) | — |
| 11 | `addNewLogin2sql_sub.sql` | Subscriber | SSMS | — |
| 12 | `createRepldb.sql` | Subscriber | SSMS | — |
| 13 | `createSub.sql` | Publisher | SSMS | — |

> \* Steps 4 and 5 are swapped from their numeric order intentionally — run Step 5 (share creation) **before** Step 4 (distributor config) so the UNC path exists when the distributor is configured.

---

## If You Already Have a Database (Skipping Step 6)

When skipping `testPrepa.sql`, update these references in the remaining scripts to point to your existing database:

| Script | What to change |
|---|---|
| `addDbowner.sql` | Replace `ReplicationTestDB` in the `@databases` table |
| `createPub.sql` | Change `USE [ReplicationTestDB]` at the top |
| `createSub.sql` | Change `USE [ReplicationTestDB]` at the top |

Also verify your existing database meets these requirements before running Step 8:

- **Full recovery model** is required — Simple recovery prevents the Log Reader Agent from reading the transaction log:
  ```sql
  ALTER DATABASE [YourDB] SET RECOVERY FULL;
  ```
- **All tables to be replicated must have a Primary Key** — tables without a PK cannot be added as articles.
- The database must **not already be enabled for replication** on another publication. Check with:
  ```sql
  SELECT name, is_published FROM sys.databases WHERE name = 'YourDB';
  -- is_published must be 0
  ```

---

## Important Notes & Common Pitfalls

### 🔴 Critical

- **Do not run `testPrepa.sql` if you already have a database** — it drops and recreates `ReplicationTestDB` with no confirmation prompt.
- **The Snapshot must fully complete before creating the subscription.** Creating the subscription while the snapshot is still running will cause the Distribution Agent to fail immediately.
- **Run Step 5 (share creation) before Step 4 (distributor config)** if the `ReplData` share does not yet exist — the distributor requires a valid, reachable UNC path at configuration time.
- **Full recovery model is mandatory on the publisher database.** The Log Reader Agent cannot function with Simple recovery.

### 🟡 Verify Before Running

- `addPermisions2Repldata.ps1` → confirm `$path` matches your SQL Server version folder (`MSSQL14` = 2017, `MSSQL15` = 2019, `MSSQL16` = 2022).
- `addHost.ps1` → update `$IPAddress` to your actual subscriber IP before running.
- `addDbowner.sql`, `addNewLogins2sql.sql`, `addNewLogin2sql_sub.sql` → if using domain accounts instead of local accounts, set `@prefix = 'YOURDOMAIN'` explicitly.
- `createSub.sql` → the `sa` account is used for the subscriber connection by default. Replace with a dedicated least-privilege SQL login in production.

### 🟢 Good to Know

- `addEnvVar.ps1` is idempotent — it removes the paths before re-adding them, safe to run multiple times.
- `addPermisions2Repldata.ps1` is idempotent — it removes and recreates the share on each run.
- `addHost.ps1` is idempotent — it checks for an existing entry before appending.
- `addNewLogins2sql.sql` and `addNewLogin2sql_sub.sql` are idempotent — they check for existing logins before creating.
- `createRepldb.sql` is idempotent — it uses `IF DB_ID(...) IS NULL` and `IF NOT EXISTS` guards.
- The publication uses **continuous transactional replication** (`@repl_freq = 'continuous'`, `@frequency_type = 64`) — changes on the publisher are delivered to the subscriber with minimal latency.

---

## Validation Queries

Run these on both servers after setup to confirm replication is working:

```sql
-- 1. Compare row counts between Publisher and Subscriber
--    Run on BOTH servers — numbers must match
SELECT 'Customers'     AS TableName, COUNT(*) AS RowCount FROM Customers
UNION ALL
SELECT 'Products',      COUNT(*) FROM Products
UNION ALL
SELECT 'Orders',        COUNT(*) FROM Orders
UNION ALL
SELECT 'OrderDetails',  COUNT(*) FROM OrderDetails;

-- 2. Check replication agent job status (run on Publisher)
SELECT name, enabled, date_modified
FROM msdb.dbo.sysjobs
WHERE name LIKE '%RepTest%'
ORDER BY name;

-- 3. Check for distribution errors (run on Publisher)
SELECT TOP 20 time, error_text, error_type
FROM [DistDB].dbo.MSrepl_errors
ORDER BY time DESC;

-- 4. Check subscription sync status (run on Publisher)
SELECT
    s.subscriber_db,
    ss.status,
    ss.last_sync_summary,
    ss.last_sync_datetime
FROM distribution.dbo.MSsubscriptions s
JOIN distribution.dbo.MSdistribution_status ss
    ON s.agent_id = ss.agent_id;

-- 5. Verify publisher database recovery model (run before Step 8)
SELECT name, recovery_model_desc
FROM sys.databases
WHERE name = 'ReplicationTestDB'; -- change to your DB name if skipping Step 6
-- Must return: FULL
```
