/* =========================================================
   REPLICATION TEST DATABASE - FULL SCRIPT
   Covers:
   - Database creation
   - Schema setup
   - Initial snapshot data
   - Post-snapshot changes (DML)
   - Edge cases (identity, bulk, transactions)
   ========================================================= */

------------------------------------------------------------
-- PHASE 0: CREATE CLEAN TEST DATABASE
------------------------------------------------------------
USE master;
GO

IF DB_ID('ReplicationTestDB') IS NOT NULL
BEGIN
    ALTER DATABASE ReplicationTestDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE ReplicationTestDB;
END
GO

CREATE DATABASE ReplicationTestDB;
GO

USE ReplicationTestDB;
GO


------------------------------------------------------------
-- PHASE 1: CREATE TABLES (SCHEMA FOR SNAPSHOT)
------------------------------------------------------------

-- Customers table
CREATE TABLE Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    Name NVARCHAR(100),
    Email NVARCHAR(100),
    CreatedAt DATETIME DEFAULT GETDATE()
);

-- Products table
CREATE TABLE Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(100),
    Price DECIMAL(10,2),
    Stock INT
);

-- Orders table (FK to Customers)
CREATE TABLE Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT,
    OrderDate DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Orders_Customers 
        FOREIGN KEY (CustomerID)
        REFERENCES Customers(CustomerID)
);

-- OrderDetails table (FK to Orders & Products)
CREATE TABLE OrderDetails (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT,
    ProductID INT,
    Quantity INT,
    CONSTRAINT FK_OD_Orders 
        FOREIGN KEY (OrderID)
        REFERENCES Orders(OrderID),
    CONSTRAINT FK_OD_Products 
        FOREIGN KEY (ProductID)
        REFERENCES Products(ProductID)
);

------------------------------------------------------------
-- PHASE 1: INITIAL DATA (SNAPSHOT CONTENT)
-- This is what gets replicated by Snapshot Agent
------------------------------------------------------------

-- Insert Customers
INSERT INTO Customers (Name, Email)
VALUES 
('Alice', 'alice@test.com'),
('Bob', 'bob@test.com'),
('Charlie', 'charlie@test.com');

-- Insert Products
INSERT INTO Products (ProductName, Price, Stock)
VALUES
('Laptop', 1200, 10),
('Mouse', 25, 100),
('Keyboard', 50, 50);

-- Insert Orders
INSERT INTO Orders (CustomerID)
VALUES (1), (2);

-- Insert OrderDetails
INSERT INTO OrderDetails (OrderID, ProductID, Quantity)
VALUES
(1, 1, 1),
(1, 2, 2),
(2, 3, 1);

------------------------------------------------------------
-- >>> RUN SNAPSHOT AGENT HERE <<<
-- Verify subscriber has identical schema + data
------------------------------------------------------------


------------------------------------------------------------
-- PHASE 2: POST-SNAPSHOT CHANGES (TRANSACTIONAL TEST)
------------------------------------------------------------

----------------------------
-- INSERT TESTS (new rows)
----------------------------
INSERT INTO Customers (Name, Email)
VALUES ('David', 'david@test.com');

INSERT INTO Products (ProductName, Price, Stock)
VALUES ('Monitor', 300, 20);

----------------------------
-- UPDATE TESTS
----------------------------
UPDATE Products
SET Price = Price + 10
WHERE ProductName = 'Mouse';

UPDATE Customers
SET Email = 'alice_new@test.com'
WHERE Name = 'Alice';

----------------------------
-- DELETE TESTS
----------------------------
DELETE FROM OrderDetails
WHERE OrderDetailID = 2;

DELETE FROM Orders
WHERE OrderID = 2;

----------------------------
-- RELATIONAL INSERT TEST
-- (tests FK consistency in replication)
----------------------------
INSERT INTO Orders (CustomerID) VALUES (3);

INSERT INTO OrderDetails (OrderID, ProductID, Quantity)
VALUES (3, 1, 1);

----------------------------
-- BUSINESS LOGIC UPDATE
-- (tests chained updates)
----------------------------
UPDATE Products
SET Stock = Stock - 1
WHERE ProductID = 1;


------------------------------------------------------------
-- EDGE CASES FOR ADVANCED REPLICATION TESTING
------------------------------------------------------------

----------------------------
-- IDENTITY INSERT TEST
-- (tests identity handling across publisher/subscriber)
----------------------------
SET IDENTITY_INSERT Customers ON;

INSERT INTO Customers (CustomerID, Name, Email)
VALUES (100, 'ManualID', 'manual@test.com');

SET IDENTITY_INSERT Customers OFF;


----------------------------
-- BULK INSERT TEST
-- (tests latency & performance)
----------------------------
INSERT INTO Products (ProductName, Price, Stock)
SELECT 
    'BulkProduct_' + CAST(number AS VARCHAR),
    10 + number,
    100
FROM master..spt_values
WHERE type = 'P' AND number < 50;


----------------------------
-- TRANSACTION CONSISTENCY TEST
-- (ensures atomic replication)
----------------------------
BEGIN TRAN;

INSERT INTO Customers (Name, Email)
VALUES ('TransactionalUser', 'txn@test.com');

UPDATE Products
SET Stock = Stock - 5
WHERE ProductID = 2;

COMMIT;


------------------------------------------------------------
-- OPTIONAL: VALIDATION QUERIES
-- Run on Publisher and Subscriber to compare
------------------------------------------------------------

-- Row counts per table
SELECT 'Customers' AS TableName, COUNT(*) FROM Customers
UNION ALL
SELECT 'Products', COUNT(*) FROM Products
UNION ALL
SELECT 'Orders', COUNT(*) FROM Orders
UNION ALL
SELECT 'OrderDetails', COUNT(*) FROM OrderDetails;

-- Check sample data
SELECT TOP 10 * FROM Customers ORDER BY CustomerID DESC;
SELECT TOP 10 * FROM Products ORDER BY ProductID DESC;

------------------------------------------------------------
-- END OF SCRIPT
------------------------------------------------------------
