SELECT market 
FROM dim_customer 
WHERE customer= "Atliq Exclusive" 
AND region="APAC";

WITH cte1 as
(SELECT count(DISTINCT(product_code)) as Unique_Products_2020
FROM fact_sales_monthly as f 
WHERE fiscal_year=2020),
cte2 as
(SELECT count(DISTINCT(product_code)) as Unique_Products_2021
FROM fact_sales_monthly as f 
WHERE fiscal_year=2021)
SELECT *, round((Unique_Products_2021-Unique_Products_2020)*100/Unique_Products_2020,2) as Percentage_Change		
FROM cte1
CROSS JOIN
cte2;

SELECT segment,
count(DISTINCT(product_code)) as Product_Count 
FROM dim_product
GROUP BY segment
ORDER BY Product_Count DESC;

WITH cte1 as (SELECT p.segment,
count(DISTINCT(f.product_code)) as Product_Count_2020
FROM fact_sales_monthly as f 
JOIN dim_product as p
USING(product_code)
WHERE fiscal_year=2020
GROUP BY segment
ORDER BY Product_Count_2020 DESC),
cte2 as (SELECT  p.segment,
count(DISTINCT(f.product_code)) as Product_Count_2021
FROM fact_sales_monthly as f 
JOIN dim_product as p
USING(product_code)
WHERE fiscal_year=2021
GROUP BY segment
ORDER BY Product_Count_2021 DESC),
cte_table as (SELECT cte1.segment, Product_Count_2020, 
Product_Count_2021,round(Product_Count_2021-Product_Count_2020) as Difference
FROM cte1 JOIN cte2 USING (segment))
SELECT segment,Product_Count_2020, Product_Count_2021, Difference
FROM cte_table ORDER BY Difference DESC;

SELECT F.product_code, P.product, F.manufacturing_cost 
FROM fact_manufacturing_cost F JOIN dim_product P
ON F.product_code = P.product_code
WHERE manufacturing_cost
IN (
	SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost
    UNION
    SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost
    ) 
ORDER BY manufacturing_cost DESC ;

SELECT c.customer_code, c.customer, 
round(AVG(f.pre_invoice_discount_pct)*100,2) as Avg_Discount_Pct
FROM dim_customer as c 
JOIN fact_pre_invoice_deductions as f
USING (customer_code)
WHERE market = "India"and fiscal_year=2021
GROUP BY c.customer_code,c.customer
ORDER BY Average_Discount_Percentage DESC
LIMIT 5;

SELECT CONCAT(MONTHNAME(FS.date), ' (', YEAR(FS.date), ')') AS 'Month', FS.fiscal_year,
       ROUND(SUM(G.gross_price*FS.sold_quantity), 2) AS Gross_sales_Amount
FROM fact_sales_monthly FS JOIN dim_customer C ON FS.customer_code = C.customer_code
						   JOIN fact_gross_price G ON FS.product_code = G.product_code
WHERE C.customer = 'Atliq Exclusive'
GROUP BY  Month, FS.fiscal_year 
ORDER BY FS.fiscal_year ;
    
WITH cte as
(SELECT *,
 CASE
     WHEN MONTH(date) IN (9,10,11) THEN 'Q1'
     WHEN MONTH(date) IN (12,1,2) THEN 'Q2'
     WHEN MONTH(date) IN (3,4,5) THEN 'Q3'
     ELSE 'Q4'
        END as Quarter
    FROM fact_sales_monthly
    WHERE fiscal_year = 2020)
SELECT Quarter,
ROUND(SUM(sold_quantity) / 1000000, 2) as total_sold_quantity_mln
FROM cte
GROUP BY Quarter
ORDER BY total_sold_quantity_mln DESC;



WITH CTE
     AS (SELECT c.channel,
                Sum(s.sold_quantity * g.gross_price) AS total_sales
         FROM   fact_sales_monthly s
                JOIN fact_gross_price g using(product_code)
                JOIN dim_customer c using(customer_code)
         WHERE  s.fiscal_year = 2021
         GROUP  BY c.channel
         ORDER  BY total_sales DESC)
SELECT channel,
       CONCAT(Round(total_sales / 1000000, 2), 'M') AS
       gross_sales_in_millions,
       CONCAT(Round(total_sales / ( Sum(total_sales) OVER() ) * 100, 2), '%') AS 
       percentage
FROM   CTE;


WITH top_sold_products AS 
(SELECT b.division AS division,
b.product_code AS product_code,
b.product AS product,
SUM(a.sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly AS a
INNER JOIN dim_product AS b
ON a.product_code = b.product_code
WHERE a.fiscal_year = 2021
GROUP BY  b.division, b.product_code, b.product 
ORDER BY total_sold_quantity DESC),
top_sold_per_division AS 
( SELECT division,product_code,product,total_sold_quantity,
DENSE_RANK() OVER(PARTITION BY division 
ORDER BY total_sold_quantity DESC) AS rank_order 
 FROM top_sold_products)
 SELECT * FROM top_sold_per_division
 WHERE rank_order <= 3;