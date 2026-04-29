# SQL Server 2022 — Transactional Replication Setup Guide

> Windows | MSSQL 2022 | Push Subscription

---
helpful links 


https://learn.microsoft.com/en-us/sql/relational-databases/replication/tutorial-preparing-the-server-for-replication?view=sql-server-ver17


https://learn.microsoft.com/en-us/sql/relational-databases/replication/tutorial-replicating-data-between-continuously-connected-servers?view=sql-server-ver17


https://learn.microsoft.com/en-us/sql/relational-databases/replication/sql-server-replication?view=sql-server-ver17


---
## Architecture

| Role            | Description                                                        |
|-----------------|--------------------------------------------------------------------|
| Publisher (PUB) | Source server — hosts the database to replicate from               |
| Subscriber (SUB)| Target server — receives replicated data                           |
| Source DB       | The database being published on the publisher                      |
| Target DB       | The destination database on the subscriber                         |
| Distribution DB | Created on the publisher — tracks replication history and commands |
| Snapshot Share  | UNC path on the publisher where snapshot files are written         |
| Publication     | Named logical unit grouping the articles to replicate              |

---

## Script Reference

| Script                       | Purpose                                                                                              | Run On |
|------------------------------|------------------------------------------------------------------------------------------------------|--------|
| `addHost.ps1`                | Add the other server's IP/hostname to Windows hosts file. Skip if both are in the same domain.      | BOTH   |
| `addEnvVar.ps1`              | Add SQL Server binary paths to system environment variables.                                         | BOTH   |
| `createUsers_pub.ps1`        | Create Windows local agent accounts: repl_snapshot, repl_logreader, repl_distribution, repl_merge.  | PUB    |
| `createUser_sub.ps1`         | Create Windows local agent accounts on subscriber: repl_distribution, repl_merge.                   | SUB    |
| `addPermisions2Repldata.ps1` | Create the ReplData SMB share and set NTFS permissions for agent accounts. Check the path first.     | PUB    |
| `MSSQLSERVER_18483.sql`      | Fix error 18483 — grant connect permissions. Restart SQL Server after running.                       | BOTH   |
| `addNewLogins2sql.sql`       | Register Windows agent accounts as SQL Server logins on the publisher.                               | PUB    |
| `addNewLogin2sql_sub.sql`    | Register Windows agent accounts as SQL Server logins on the subscriber.                              | SUB    |
| `distroCreation.sql`         | Create the distributor, distribution database, and register the publisher.                           | PUB    |
| `addDbowner.sql`             | Grant db_owner to agent accounts. Run on PUB targeting distribution DB and source DB. Run on SUB targeting target DB. | BOTH |
| `pubCreation.sql`            | Enable publishing on the source DB, create publication, configure agents, add articles, start snapshot. | PUB |
| `createRepldb.sql`           | Create the target database, create the source schema to match publisher, create agent users.         | SUB    |
| `subCreation.sql`            | Create push subscription and Distribution Agent job.                                                 | PUB    |

---

## Execution Order

### Phase 1 — Preparation (Both Servers)

**Step 1 — Add hosts file entry** `addHost.ps1`
- On PUB: add the subscriber's IP and hostname
- On SUB: add the publisher's IP and hostname
- Skip if both servers are in the same Active Directory domain

**Step 2 — Add environment variables** `addEnvVar.ps1`
- Adds SQL Server bin path to system PATH
- Run on both servers

**Step 3 — Create Windows agent accounts**
- PUB: run `createUsers_pub.ps1` — creates repl_snapshot, repl_logreader, repl_distribution, repl_merge
- SUB: run `createUser_sub.ps1` — creates repl_distribution, repl_merge

**Step 4 — Configure snapshot share** `addPermisions2Repldata.ps1` *(PUB only)*
- Creates the ReplData SMB share on the publisher
- Grants repl_snapshot Full Control, repl_distribution and repl_merge Read access
- **Check the repldata folder path inside the script before running**

**Step 5 — Fix error 18483** `MSSQLSERVER_18483.sql`
- Run on both servers
- **Restart the SQL Server service after running on each machine**

---

### Phase 2 — Publisher Actions

**Step 6 — Register agent logins in SQL Server** `addNewLogins2sql.sql`
- Creates SQL Server logins for the Windows agent accounts on the publisher

**Step 7 — Create distributor & distribution DB** `distroCreation.sql`
- Creates the distribution database
- Registers this server as its own distributor and publisher

**Step 8 — Grant db_owner on distribution DB and source DB** `addDbowner.sql`
- Run twice on the publisher:
  - First run: target the distribution DB — agent accounts need db_owner for distribution metadata
  - Second run: target the source DB — agent accounts need db_owner to read the publication source

**Step 9 — Create publication** `pubCreation.sql`
- Enables publishing on the source database
- Creates the publication
- Configures Snapshot Agent and Log Reader Agent
- Adds all user tables as articles
- Starts the snapshot job
- **Wait for snapshot to complete before proceeding**

---

### Phase 3 — Subscriber Actions

**Step 10 — Create target DB & schema** `createRepldb.sql`
- Creates the target database on the subscriber
- Creates the source schema to match the publisher — **required, snapshot will fail without it**
- Creates agent user accounts in the database

**Step 11 — Register agent logins in SQL Server** `addNewLogin2sql_sub.sql`
- Creates SQL Server logins for agent accounts on the subscriber instance

**Step 12 — Grant db_owner on target DB** `addDbowner.sql`
- Same script as Step 8, run on the subscriber targeting the target database

---

### Phase 4 — Create Subscription (Publisher)

**Step 13 — Create push subscription** `subCreation.sql`
- Run on the publisher
- Creates the push subscription pointing to the subscriber
- Creates the Distribution Agent job
- Distribution Agent applies the snapshot automatically on first run

---

## Important Notes

> **Source schema on subscriber** — The source database schema must exist in the target DB before the Distribution Agent runs. If missing, the agent will fail repeatedly with a schema not found error. Fix: create the schema manually in the target DB on the subscriber, then reinitialize the subscription.

> **addDbowner.sql** — Must be run on the publisher targeting both the distribution DB and the source DB, and on the subscriber targeting the target DB. Missing permissions cause the snapshot agent to fail with error 14080.

> **MSSQLSERVER_18483.sql** — Always restart the SQL Server service after running this script on each machine.

> **Snapshot job** — Runs asynchronously via SQL Server Agent. Monitor progress in SSMS Replication Monitor or by querying the snapshot history in the distribution DB. Do not create the subscription until the snapshot completes successfully.

> **Subscriber before subscription** — Phase 3 (subscriber setup) must be completed before Phase 4 (subscription creation). The target DB, schema, and permissions must all exist before the publisher can push to it.

> **GO and variables** — GO kills all variables declared before it. Scripts are written to avoid GO inside batches. Do not add GO between steps that share variables.

> **SERVERPROPERTY in proc params** — Cannot be passed directly as a stored procedure parameter. Always assign to a variable first, then pass the variable.

---

## Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Specified schema name does not exist` | Source schema missing in target DB on subscriber | Create the schema manually in the target DB, then reinitialize the subscription |
| `Error 14080 — not a valid Publisher` | Agent account missing db_owner on distribution DB | Run `addDbowner.sql` on publisher targeting the distribution DB |
| `Incorrect syntax near SERVERPROPERTY` | Expression passed directly to stored proc param | Assign to a variable first, then pass the variable |
| `Must declare scalar variable` (after GO) | GO kills all variables declared before it | Avoid GO inside scripts or redeclare variables in each new batch |
| `Snapshot stuck at 'Starting agent'` | Agent account missing SQL Server login or permissions | Run login and db_owner scripts, verify SQL Server Agent service is running |
| `job is already running` | Tried to start an already-running agent from SSMS | Not an error — the agent is running, just monitor it |

---

## Reinitialization (when needed)

Run this on the publisher only when the subscription is broken or needs a full resync from scratch:

```sql
USE [<source_db>];
GO

DECLARE @pubName NVARCHAR(128) = N'<publication_name>';
DECLARE @subHost NVARCHAR(128) = N'<subscriber_hostname>';
DECLARE @subDB   NVARCHAR(128) = N'<target_db>';

EXEC sp_reinitsubscription
    @publication    = @pubName,
    @subscriber     = @subHost,
    @destination_db = @subDB;

EXEC sp_startpublication_snapshot
    @publication = @pubName;
GO
```

---

## Verification Queries

**Check distributor registration** *(run on PUB)*:
```sql
SELECT name, data_source, is_distributor
FROM sys.servers
WHERE is_distributor = 1;
```

**Check snapshot agent history** *(run on PUB)*:
```sql
USE <distribution_db>;

SELECT TOP 10
    h.runstatus,
    CASE h.runstatus
        WHEN 1 THEN 'Start'
        WHEN 2 THEN 'Succeed'
        WHEN 3 THEN 'InProgress'
        WHEN 6 THEN 'Fail'
    END AS status_desc,
    h.comments,
    h.time
FROM MSsnapshot_history h
JOIN MSsnapshot_agents  a ON h.agent_id = a.id
WHERE a.publication = N'<publication_name>'
ORDER BY h.time DESC;
```

**Check distribution agent status** *(run on PUB)*:
```sql
USE <distribution_db>;

SELECT
    a.name,
    h.runstatus,
    h.comments,
    h.delivered_transactions,
    h.delivered_commands,
    h.time
FROM MSdistribution_agents  a
JOIN MSdistribution_history h ON a.id = h.agent_id
WHERE a.subscriber_db = N'<target_db>'
ORDER BY h.time DESC;
```

**Verify row counts on subscriber** *(run on SUB)*:
```sql
USE <target_db>;

SELECT
    s.name + '.' + t.name AS TableName,
    p.rows AS TotalRows
FROM sys.tables     t
JOIN sys.schemas    s ON t.schema_id  = s.schema_id
JOIN sys.partitions p ON t.object_id  = p.object_id
WHERE p.index_id IN (0, 1)
ORDER BY s.name, t.name;
``
---

*SQL Server 2022 — Windows — Transactional Replication — Push Subscription*
