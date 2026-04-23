# SQL Server Transactional Replication — Setup Guide

**Publisher / Distributor**: `SQLRPL-AUTO-I`  
**Subscriber**: `SRVRTGS-TEST`

---

## Before You Start — Edit These Values

Open these files and update only the marked variables:

| File | Variable | Change To |
|---|---|---|
| `addHost.ps1` | `$Hostname` | Subscriber server name |
| `addHost.ps1` | `$IPAddress` | Subscriber IP address |
| `createSub.sql` | `@Subscriber` | Subscriber server name |
| `createSub.sql` | `@SubscriberDB` | Subscriber database name |
| `createSub.sql` | `@SubPassword` | SA or SQL login password on subscriber |
| `createRepldb.sql` | `'ReplDB'` | Subscriber database name |

> Everything else (machine name, paths, agent accounts) is auto-detected.  
> If using an **existing database** instead of the test one, also change `@PublisherDB` in `createPub.sql`, `createSub.sql`, and `addDbowner.sql`.

---

## Run Order

### Publisher (`SQLRPL-AUTO-I`)

| # | Script | How | Note |
|---|---|---|---|
| 0 | `MSSQLSERVER_18483.sql` | SSMS | ⚠️ Only if `@@SERVERNAME ≠ SERVERPROPERTY('ServerName')` — restart SQL Server after |
| 1 | `addEnvVar.ps1` | PowerShell (Admin) | |
| 2 | `createUsers_pub.ps1` | PowerShell (Admin) | |
| 3 | `addNewLogins2sql.sql` | SSMS | |
| 4 | `addPermisions2Repldata.ps1` | PowerShell (Admin) | Must run before step 5 |
| 5 | `createDistribution.sql` | SSMS | |
| 6 | `testPrepa.sql` | SSMS | ⭐ Skip if you already have a DB |
| 7 | `addDbowner.sql` | SSMS | |
| 8 | `createPub.sql` | SSMS | |
| — | ⏳ Wait for Snapshot Agent to finish | Replication Monitor | Do not continue until complete |

### Subscriber (`SRVRTGS-TEST`)

| # | Script | How |
|---|---|---|
| 9 | `addHost.ps1` | PowerShell (Admin) — run on Publisher |
| 10 | `createUser_sub.ps1` | PowerShell (Admin) — run on Subscriber |
| 11 | `addNewLogin2sql_sub.sql` | SSMS — run on Subscriber |
| 12 | `createRepldb.sql` | SSMS — run on Subscriber |

### Finalize (back on Publisher)

| # | Script | How |
|---|---|---|
| 13 | `createSub.sql` | SSMS |

---

## Common Pitfalls

- **Don't run `testPrepa.sql` if you have an existing DB** — it drops and recreates without warning.
- **Snapshot must finish before running `createSub.sql`** — check Replication Monitor.
- **Run step 4 before step 5** — share must exist before the distributor is configured.
- **Publisher DB must use Full recovery model** — Log Reader won't work otherwise:
  ```sql
  ALTER DATABASE [YourDB] SET RECOVERY FULL;
  ```
- **All replicated tables must have a Primary Key** — no PK = can't be added as an article.

---

## Validate After Setup

Run on both servers — row counts must match:

```sql
SELECT 'Customers'   AS T, COUNT(*) AS N FROM Customers    UNION ALL
SELECT 'Products',          COUNT(*)       FROM Products    UNION ALL
SELECT 'Orders',            COUNT(*)       FROM Orders      UNION ALL
SELECT 'OrderDetails',      COUNT(*)       FROM OrderDetails;
```

Check for errors on Publisher:
```sql
SELECT TOP 10 time, error_text FROM [DistDB].dbo.MSrepl_errors ORDER BY time DESC;
```
