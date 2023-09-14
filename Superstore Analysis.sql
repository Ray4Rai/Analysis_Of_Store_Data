CREATE DATABASE Superstore_Analysis;
USE Superstore_Analysis;

-- viewing the records
SELECT DISTINCT * FROM Orders;
SELECT DISTINCT * FROM Returned;

-----------------------------------------------------------------------------

-- Final Sales Report = Total orders - Returned orders
(SELECT * FROM Orders)
EXCEPT
(SELECT a.*
 FROM Orders a
 RIGHT JOIN Returned b
	ON a.Order_ID = b.Order_ID)

-- Sales 
SELECT * FROM Sales;

-----------------------------------------------------------------------------

/*
1.	Find the top 5 customers with the highest lifetime value (LTV) where
	LTV equals to sum of their profits divided by the total number of years 
	since they have been customers.
*/
SELECT TOP 5
    Customer_ID,
	DATEDIFF (YEAR, MIN(Order_Date), MAX(Order_Date)) AS Membership_yrs,
	SUM(Profit) AS Total_Profit,
	CAST(SUM(Profit) AS DECIMAL(10,2)) /  
	NULLIF(DATEDIFF(YEAR, MIN(Order_Date), MAX(Order_Date)), 0) AS Lifetime_value
FROM Sales
GROUP BY Customer_ID 
ORDER BY Membership_yrs DESC, Lifetime_value DESC

-----------------------------------------------------------------------------

-- 2. Create a pivot table to show total sales by product category and sub-category.

-- Using GROUPBY()
SELECT
	Category,
	Sub_category,
	SUM(Sales) AS Total_Sales
FROM Sales
	GROUP BY Category, Sub_category
	ORDER BY Category

-- Using Pivot
SELECT * FROM 
(
	SELECT 
		Sub_category,
		Category,
		Sales
	FROM SALES ) CTE
PIVOT ( 
		SUM(Sales)
		FOR Category IN ([Furniture],
						 [Office Supplies],
				         [Technology]) ) AS Pivot_table

-----------------------------------------------------------------------------

-- 3. Find the customer who has made the maximum number of orders in each category.
SELECT 
	Category,
	Customer_Name,
	Total_Orders
FROM (
	   SELECT
		   Customer_Name,
	       Category,
		   COUNT(DISTINCT Order_ID) AS Total_Orders,
		   RANK() OVER (PARTITION BY Category ORDER BY COUNT(DISTINCT Order_ID) DESC) AS rn
	   FROM Sales
	   GROUP BY Customer_Name, Category ) CTE
WHERE rn = 1

-----------------------------------------------------------------------------

-- 4. Find the top 3 products in each category based on their sales.
SELECT
	Category,
	Product_name AS Top_3_prod,
	Total_Sales
FROM ( 
       SELECT
	       Category,
	       Product_name,
		   SUM(Sales) AS Total_Sales,
		   RANK() OVER (PARTITION BY Category ORDER BY SUM(Sales) DESC) AS rn
	   FROM Sales
	   GROUP BY Product_name, Category ) CTE
WHERE rn <= 3
ORDER BY Category


/*
5.	In the table Orders with columns Order_ID, Customer_ID, OrderDate, Total_Amount. 
	You need to create a Stored Procedure Get_Customer_Orders that takes a CustomerID 
	as input and returns a table with the following columns - 
	
	Order Date,
	Total Amount,
	Total Orders - The total number of orders made by the customer,
	Average Amount - The average total amount of orders made by the customer,
	Last Order Date - The date of the customer's most recent order,
	Days Since Last Order -  The number of days since the customer's most recent order. 
							(Create a function that calculates the number of days between last
							 order date and current date) 

*/

-- Function
CREATE FUNCTION
DaysBetweenDates(@date1 date)
RETURNS INT
AS
BEGIN
	RETURN DATEDIFF(DAY, @date1, GETDATE())
END

-- Procedure
CREATE PROCEDURE
GetCustomerOrders(@CustomerID NVARCHAR(MAX))
AS
BEGIN

	SELECT 
		Customer_ID,
		SUM(Sales) AS Total_amount,
		COUNT(DISTINCT Order_ID) AS Total_orders,
		CAST(SUM(Sales) / COUNT(DISTINCT Order_ID) AS DECIMAL(18,2)) AS Average_amount,
		MAX(Order_date) AS Last_ordered_at,
		dbo.DaysBetweenDates(MAX(Order_date)) AS Days_since_last_order
	FROM Sales s
		WHERE s.Customer_ID = @CustomerID
	GROUP BY Customer_ID
END

EXEC GetCustomerOrders @CustomerID = 'AA-10375'

-- all records
SELECT 
	Customer_ID,
	SUM(Sales) AS Total_amount,
	COUNT(DISTINCT Order_ID) AS Total_orders,
	ROUND(AVG(Sales), 2) AS Average_amount,
	MAX(Order_date) AS Last_ordered_at,
	dbo.DaysBetweenDates(MAX(Order_date)) AS Days_since_last_order
FROM Sales
GROUP BY Customer_ID