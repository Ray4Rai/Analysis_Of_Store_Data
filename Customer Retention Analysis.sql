CREATE DATABASE Superstore_Analysis;
USE Superstore_Analysis;
 
-- Server name
Select *  from sysservers	

-- Total customers
SELECT
	YEAR(Order_date) AS Years,
	COUNT (DISTINCT Customer_ID) AS Overall_customers
FROM Sales
	GROUP BY YEAR(Order_date)
	ORDER BY Years

-- Trial using a Sub Query
SELECT
	COUNT (DISTINCT Customer_ID) AS Old_customers_2015
FROM Sales
	WHERE YEAR(Order_date) = '2015'
	AND Customer_ID IN (SELECT DISTINCT Customer_ID FROM Sales 
						WHERE YEAR(Order_date) = '2014' ) ;

-- Using SET Operators
SELECT COUNT (*)
FROM
( SELECT 
	DISTINCT Customer_ID
FROM Temp
	WHERE Years = 2016
INTERSECT
SELECT 
	DISTINCT Customer_ID
FROM Temp
	WHERE Years = 2015 ) a

-- Function 1 - Old Customers				
CREATE FUNCTION FetchOldCustomer()
RETURNS @Old_Customers TABLE (Years INT, Old_Customers INT)
AS
BEGIN

	DECLARE @StartYear INT = 2014;
	DECLARE @EndYear INT = 2017;
	DECLARE @CurrentYear INT = @EndYear;
	DECLARE @PreviousYear INT;

	WHILE @CurrentYear > @StartYear
	BEGIN
		SET @PreviousYear = @CurrentYear - 1;
		INSERT INTO @Old_Customers

		SELECT
			CAST(@CurrentYear AS VARCHAR(5)) AS Yr,
			COUNT(DISTINCT Customer_ID) AS Old_Customers
		FROM Sales
			WHERE YEAR(Order_date) = @CurrentYear 
			AND Customer_ID IN( 
								SELECT DISTINCT Customer_ID FROM Sales
								WHERE YEAR(Order_date) = @PreviousYear );

		SET @CurrentYear = @PreviousYear;
	END

	RETURN;
END;

SELECT * FROM FetchOldCustomer() ORDER BY Years;
DROP FUNCTION FetchOldCustomer


-- Function 2 - Lost customers
CREATE FUNCTION FetchLostCustomer()
RETURNS @Lost_Customers TABLE (Years INT, Lost_Customers INT)
AS
BEGIN

	DECLARE @StartYear INT = 2014;
	DECLARE @EndYear INT = 2017;
	DECLARE @CurrentYear INT = @EndYear;
	DECLARE @PreviousYear INT;

	WHILE @CurrentYear > @StartYear
	BEGIN
		SET @PreviousYear = @CurrentYear - 1;
		INSERT INTO @Lost_Customers

		SELECT
			@CurrentYear AS Years,
			COUNT(DISTINCT Customer_ID) AS Lost_Customers
		FROM Sales
			WHERE YEAR(Order_date) = @PreviousYear 
			AND Customer_ID NOT IN( 
								     SELECT DISTINCT Customer_ID FROM Sales
								     WHERE YEAR(Order_date) = @CurrentYear );

		SET @CurrentYear = @PreviousYear;
	END

	RETURN;
END;

SELECT * FROM FetchLostCustomer() ORDER BY Years;
DROP FUNCTION FetchLostCustomer


-- Funtion 3 - New Customers
CREATE FUNCTION FetchNewCustomer()
RETURNS @New_Customers TABLE (Years INT, New_Customers INT)
AS
BEGIN

	DECLARE @StartYear INT = 2014;
	DECLARE @EndYear INT = 2017;
	DECLARE @CurrentYear INT = @EndYear;
	DECLARE @PreviousYear INT;

	WHILE @CurrentYear > @StartYear
	BEGIN
		SET @PreviousYear = @CurrentYear - 1;
		INSERT INTO @New_Customers

		SELECT
			@CurrentYear AS Years,
			COUNT(DISTINCT Customer_ID) AS New_Customers
		FROM Sales
			WHERE YEAR(Order_date) = @CurrentYear 
			AND Customer_ID NOT IN( 
								     SELECT DISTINCT Customer_ID FROM Sales
								     WHERE YEAR(Order_date) = @PreviousYear );

		SET @CurrentYear = @PreviousYear;
	END

	RETURN;
END;

SELECT * FROM FetchNewCustomer() ORDER BY Years;

-- Function 5 - Monthly Retention
CREATE FUNCTION FetchMonthlyRetention()
RETURNS @Details TABLE 
(YearMonth VARCHAR(7), Total_Customers INT, Old_Customers INT, 
New_Customers INT, Lost_Customers INT, Retention_Rate DECIMAL(10,2))
AS
BEGIN

	DECLARE @StartDate DATE;
	DECLARE @EndDate DATE;;
    DECLARE @CurrentDate DATE;
    DECLARE @PreviousDate DATE;
    DECLARE @PreviousTotalCustomers INT;
	
	SELECT @StartDate = MIN(Order_date) FROM Sales;
	SELECT @EndDate = MAX(Order_date) FROM Sales;
	SET @CurrentDate = @EndDate
    
	WHILE @CurrentDate >= @StartDate
    BEGIN

        SET @PreviousDate = DATEADD(MONTH, -1, @CurrentDate);

        SELECT @PreviousTotalCustomers = COUNT(DISTINCT Customer_ID) FROM Sales 
        WHERE YEAR(Order_date) = YEAR(@PreviousDate) AND 
            MONTH(Order_date) = MONTH(@PreviousDate);

        INSERT INTO @Details(YearMonth, Total_Customers, Old_Customers, New_Customers, Lost_Customers, Retention_Rate)

        SELECT
            FORMAT(@CurrentDate, 'yyyy-MM') AS YearMonth,
            (SELECT COUNT(DISTINCT Customer_ID) FROM Sales 
                WHERE YEAR(Order_date) = YEAR(@CurrentDate) AND 
                    MONTH(Order_date) = MONTH(@CurrentDate)) AS Total_Customers,
            a.Old_Customers,
            b.New_Customers,
            c.Lost_Customers,
            CASE 
                WHEN @PreviousTotalCustomers > 0 THEN a.Old_Customers*1.0/@PreviousTotalCustomers 
                ELSE 0 
            END AS Retention_Rate
        FROM(
            SELECT
                COUNT(DISTINCT Customer_ID) AS Old_Customers
            FROM Sales
                WHERE YEAR(Order_date) = YEAR(@PreviousDate) AND 
                    MONTH(Order_date) = MONTH(@PreviousDate) AND 
                    Customer_ID IN( 
                                    SELECT DISTINCT Customer_ID FROM Sales
                                    WHERE YEAR(Order_date) = YEAR(@CurrentDate) AND 
                                        MONTH(Order_date) = MONTH(@CurrentDate) )) a
        JOIN(
            SELECT
                COUNT(DISTINCT Customer_ID) AS New_Customers
            FROM Sales
                WHERE YEAR(Order_date) = YEAR(@CurrentDate) AND 
                    MONTH(Order_date) = MONTH(@CurrentDate) AND 
                    Customer_ID NOT IN( 
                                        SELECT DISTINCT Customer_ID FROM Sales
                                            WHERE YEAR(Order_date) = YEAR(@PreviousDate) AND 
                                                MONTH(Order_date) = MONTH(@PreviousDate) )) b ON 1=1
        JOIN (
            SELECT
                COUNT(DISTINCT Customer_ID) AS Lost_Customers
            FROM Sales
                WHERE YEAR(Order_date) = YEAR(@PreviousDate) AND 
                    MONTH(Order_date) = MONTH(@PreviousDate) AND 
                    Customer_ID NOT IN( 
                                        SELECT DISTINCT Customer_ID FROM Sales
                                            WHERE YEAR(Order_date) = YEAR(@CurrentDate) AND 
                                                MONTH(Order_date) = MONTH(@CurrentDate) )) c ON 1=1;

        SET @CurrentDate = @PreviousDate;

    END;

    RETURN;
END;

SELECT * FROM FetchMonthlyRetention() ORDER BY YearMonth

-- Function 4 - Fetch Annual Retention
CREATE FUNCTION FetchAnnualRetention()
RETURNS @Details TABLE 
(Years VARCHAR(5), Total_Customers INT, Old_Customers INT, 
 New_Customers INT, Lost_Customers INT, Retention_rate DECIMAL(10,2))
AS
BEGIN

	DECLARE @StartYear DATE = '2014';
	DECLARE @EndYear DATE = '2017';
	DECLARE @CurrentYear DATE = @EndYear;
	DECLARE @PreviousYear DATE;
	DECLARE @PreviousTotalCustomers INT;

	WHILE @CurrentYear >= @StartYear
	BEGIN

		SET @PreviousYear = DATEADD( YEAR, -1, @CurrentYear );

		SELECT @PreviousTotalCustomers = COUNT(DISTINCT Customer_ID) FROM Sales
			WHERE YEAR(Order_date) = YEAR(@PreviousYear);

		INSERT INTO @Details
		(Years, Total_Customers, Old_Customers, New_Customers, Lost_Customers, Retention_rate)

		SELECT
		    FORMAT(@CurrentYear, 'yyyy') AS Years,
			(SELECT COUNT(DISTINCT Customer_ID) FROM Sales WHERE YEAR(Order_date) = YEAR(@CurrentYear)) AS Total_Customers,
			a.Old_Customers,
			b.New_Customers,
			c.Lost_Customers,
			CASE 
				WHEN @PreviousTotalCustomers > 0 THEN a.Old_Customers*1.0/@PreviousTotalCustomers
				ELSE 0
			END AS Retention_rate
		FROM(
			  SELECT
			      @CurrentYear AS Years,
				  COUNT(DISTINCT Customer_ID) AS Old_Customers
			  FROM Sales
			      WHERE YEAR(Order_date) = YEAR(@CurrentYear) 
			      AND Customer_ID IN( 
								     SELECT DISTINCT Customer_ID FROM Sales
								     WHERE YEAR(Order_date) = YEAR(@PreviousYear) )) a
		JOIN(
			  SELECT
			      @CurrentYear AS Years,
			      COUNT(DISTINCT Customer_ID) AS New_Customers
		      FROM Sales
			      WHERE YEAR(Order_date) = YEAR(@CurrentYear) 
			      AND Customer_ID NOT IN( 
								          SELECT DISTINCT Customer_ID FROM Sales
								          WHERE YEAR(Order_date) = YEAR(@PreviousYear) )) b ON 1=1
		JOIN (
			   SELECT
		   	       @CurrentYear AS Years,
			       COUNT(DISTINCT Customer_ID) AS Lost_Customers
		       FROM Sales
			       WHERE YEAR(Order_date) = YEAR(@PreviousYear) 
			       AND Customer_ID NOT IN( 
								           SELECT DISTINCT Customer_ID FROM Sales
								           WHERE YEAR(Order_date) = YEAR(@CurrentYear) )) c ON 1=1;
	    
		SET @CurrentYear = @PreviousYear;
	
	END;

	RETURN;
END;

SELECT * FROM FetchAnnualRetention() ORDER BY Years;