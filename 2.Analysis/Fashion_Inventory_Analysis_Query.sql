-- Overall inventory health
SELECT 
    Status,
    COUNT(*) as Product_Count,
    CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM inventory) AS DECIMAL(5,2)) as Percentage,
    CAST(AVG(Sell_Through_Rate) AS DECIMAL(5,2)) as Avg_Sell_Through
FROM inventory
GROUP BY Status
ORDER BY Product_Count DESC;

-- Capital tied up in deadstock
SELECT
	ROUND(SUM( i.stock_remaining * p.cost ),2) as Total_Capital_Tied_Up
FROM inventory i
JOIN product p on i.Product_ID = p.Product_ID
WHERE i.Status = 'Deadstock'

-- Deadstock rate by category
SELECT 
    p.Category,
    COUNT(*) as Total_Products,
    SUM(CASE WHEN i.Status = 'Deadstock' THEN 1 ELSE 0 END) as Deadstock_Count,
    CAST(SUM(CASE WHEN i.Status = 'Deadstock' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as Deadstock_Percentage,
	ROUND(SUM(CASE WHEN i.Status = 'Deadstock' THEN i.Stock_Remaining * p.Cost ELSE 0 END),2) as Capital_Tied_up,
    CAST(SUM(i.Markdown_Loss) AS DECIMAL(10,2)) as Total_Markdown_Loss,
	ROUND(AVG(i.Sell_Through_Rate),2) as Avg_Sell_Through
FROM product p
JOIN inventory i ON p.Product_ID = i.Product_ID
GROUP BY p.Category
ORDER BY Total_Markdown_Loss DESC;

--problematic color
SELECT
	p.color,
	ROUND(SUM(CASE WHEN i.Status = 'Deadstock' THEN i.Stock_Remaining * p.Cost ELSE 0 END),2) as Capital_Tied_up,
    CAST(SUM(i.Markdown_Loss) AS DECIMAL(10,2)) as Total_Markdown_Loss,
	ROUND(AVG(i.Sell_Through_Rate),2) as Avg_Sell_Through
FROM product p
JOIN inventory i ON p.Product_ID = i.Product_ID
GROUP BY p.Color
ORDER BY  Capital_Tied_up desc

--problematic size
SELECT
	p.Size,
	ROUND(SUM(CASE WHEN i.Status = 'Deadstock' THEN i.Stock_Remaining * p.Cost ELSE 0 END),2) as Capital_Tied_up,
    CAST(SUM(i.Markdown_Loss) AS DECIMAL(10,2)) as Total_Markdown_Loss,
	ROUND(AVG(i.Sell_Through_Rate),2) as Avg_Sell_Through
FROM product p
JOIN inventory i ON p.Product_ID = i.Product_ID
GROUP BY p.Size
ORDER BY  Capital_Tied_up desc

--Price and Performance correlation
SELECT 
    CASE 
        WHEN p.Price < 40 THEN 'Budget (<$40)'
        WHEN p.Price < 70 THEN 'Mid ($40-70)'
        WHEN p.Price < 100 THEN 'Premium ($70-100)'
        ELSE 'Luxury ($100+)'
    END as Price_Tier,
    COUNT(*) as Total_SKUs,
    SUM(CASE WHEN i.Status = 'Deadstock' THEN 1 ELSE 0 END) as Deadstock_Count,
    CAST(SUM(CASE WHEN i.Status = 'Deadstock' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS DECIMAL(5,2)) as Deadstock_Rate,
    CAST(AVG(p.Price) AS DECIMAL(10,2)) as Avg_Price,
    CAST(AVG(i.Sell_Through_Rate) AS DECIMAL(5,2)) as Avg_Sell_Through
FROM product p
JOIN inventory i ON p.Product_ID = i.Product_ID
GROUP BY 
    CASE 
        WHEN p.Price < 40 THEN 'Budget (<$40)'
        WHEN p.Price < 70 THEN 'Mid ($40-70)'
        WHEN p.Price < 100 THEN 'Premium ($70-100)'
        ELSE 'Luxury ($100+)'
    END
ORDER BY Deadstock_Rate DESC;


-- Capital tied up by color performance
SELECT 
    CASE 
        WHEN p.Color IN ('Black','White','Navy','Gray','Beige') THEN 'Neutral Colors'
        WHEN p.Color IN ('Neon Pink','Neon Green','Mustard','Orange') THEN 'Risky Colors'
        ELSE 'Bold Colors'
    END as Color_Group,
    
    -- Performance metrics
    COUNT(*) as SKU_Count,
    CAST(AVG(i.Sell_Through_Rate) AS DECIMAL(5,2)) as Avg_Sell_Through,
    
    -- Volume metrics
    SUM(i.Stock_Ordered) as Total_Units_Ordered,
    SUM(i.Units_Sold) as Total_Units_Sold,
    SUM(i.Stock_Remaining) as Total_Units_Remaining,
    
    -- Financial metrics
    CAST(SUM(i.Stock_Remaining * p.Cost) AS DECIMAL(12,2)) as Capital_Tied_Up,
    CAST(SUM(i.Stock_Remaining * p.Cost) * 100.0 / 
         (SELECT SUM(Stock_Remaining * Cost) FROM inventory inv JOIN product prod ON inv.Product_ID = prod.Product_ID) 
         AS DECIMAL(5,2)) as Pct_of_Total_Capital,
    
    -- Efficiency metric
    CAST(SUM(i.Stock_Remaining) * 100.0 / SUM(i.Stock_Ordered) AS DECIMAL(5,2)) as Overstock_Rate,
    
    -- Per-SKU average
    CAST(AVG(i.Stock_Remaining * p.Cost) AS DECIMAL(10,2)) as Avg_Capital_Per_SKU
    
FROM product p
JOIN inventory i ON p.Product_ID = i.Product_ID
GROUP BY 
    CASE 
        WHEN p.Color IN ('Black','White','Navy','Gray','Beige') THEN 'Neutral Colors'
        WHEN p.Color IN ('Neon Pink','Neon Green','Mustard','Orange') THEN 'Risky Colors'
        ELSE 'Bold Colors'
    END
ORDER BY Capital_Tied_Up DESC;

-- Projection Analysis on Natural Color
WITH NeutralAnalysis AS (
    SELECT 
        p.Product_ID,
        p.Product_Name,
        p.Color,
        i.Stock_Ordered,
        i.Units_Sold,
        i.Stock_Remaining,
        i.Sell_Through_Rate,
        p.Cost,
        
        -- What if we ordered just 20% more than actual demand?
        CAST(i.Units_Sold * 1.2 AS INT) as Optimal_Order_Qty,
        
        -- Comparison
        i.Stock_Ordered - CAST(i.Units_Sold * 1.2 AS INT) as Excess_Units,
        (i.Stock_Ordered - CAST(i.Units_Sold * 1.2 AS INT)) * p.Cost as Excess_Capital
        
    FROM product p
    JOIN inventory i ON p.Product_ID = i.Product_ID
    WHERE p.Color IN ('Black','White','Navy','Gray','Beige')
        AND i.Stock_Ordered > i.Units_Sold * 1.2  -- Over-ordered by >20%
)
SELECT 
    Color,
    COUNT(*) as Over_Ordered_SKUs,
    SUM(Stock_Ordered) as Total_Ordered,
    SUM(Optimal_Order_Qty) as Should_Have_Ordered,
    SUM(Excess_Units) as Excess_Units,
    CAST(SUM(Excess_Capital) AS DECIMAL(12,2)) as Capital_That_Couldve_Been_Saved,
    CAST(AVG(Sell_Through_Rate) AS DECIMAL(5,2)) as Avg_Sell_Through
FROM NeutralAnalysis
GROUP BY Color
ORDER BY Capital_That_Couldve_Been_Saved DESC;

