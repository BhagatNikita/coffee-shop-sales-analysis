-- Create Database
CREATE DATABASE IF NOT EXISTS CoffeeShopDB;

-- Use Database
USE CoffeeShopDB;

-- Drop Tables (Child tables first)
DROP TABLE IF EXISTS Sales;
DROP TABLE IF EXISTS Customers;
DROP TABLE IF EXISTS Products;
DROP TABLE IF EXISTS City;

-- Create City Table
CREATE TABLE City (
    city_id INT PRIMARY KEY,
    city_name VARCHAR(15),
    population BIGINT,
    estimated_rent DECIMAL(10,2),
    city_rank INT
);

-- Create Customers Table
CREATE TABLE Customers (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(25),
    city_id INT,
    CONSTRAINT fk_city
        FOREIGN KEY (city_id)
        REFERENCES City(city_id)
);

-- Create Products Table
-- NOTE: product_id 1-14 = drink/consumable items (used as a filter in Q7).
-- If a category column is added later, replace the BETWEEN filter with it.
CREATE TABLE Products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(35),
    price DECIMAL(10,2)
);

-- Create Sales Table
CREATE TABLE Sales (
    sale_id INT PRIMARY KEY,
    sale_date DATE,
    product_id INT,
    customer_id INT,
    total DECIMAL(10,2),
    rating INT,

    CONSTRAINT fk_products
        FOREIGN KEY (product_id)
        REFERENCES Products(product_id),

    CONSTRAINT fk_customers
        FOREIGN KEY (customer_id)
        REFERENCES Customers(customer_id)
);

-- View Tables
SELECT * FROM City;
SELECT * FROM Customers;
SELECT * FROM Products;
SELECT * FROM Sales;

-- ============================================================
-- Reports & Data Analysis
-- ============================================================

-- Q.1 Coffee Consumers Count
-- How many people in each city are estimated to consume coffee,
-- given that 25% of the population does?

SELECT
    city_name,
    ROUND((population * 0.25) / 1000000, 2) AS coffee_consumers_in_millions,
    city_rank
FROM City
ORDER BY population DESC;


-- Q.2 Total Revenue from Coffee Sales
-- What is the total revenue generated from coffee sales across all
-- cities in the last quarter of 2023?

SELECT
    SUM(total) AS total_revenue
FROM Sales
WHERE YEAR(sale_date) = 2023
  AND QUARTER(sale_date) = 4;

SELECT
    c.city_name,
    SUM(s.total) AS total_revenue
FROM Sales s
JOIN Customers cu ON s.customer_id = cu.customer_id
JOIN City c ON cu.city_id = c.city_id
WHERE YEAR(s.sale_date) = 2023
  AND QUARTER(s.sale_date) = 4
GROUP BY c.city_name
ORDER BY total_revenue DESC;


-- Q.3 Sales Count for Each Product
-- How many units of each coffee product have been sold?

SELECT
    p.product_name,
    COUNT(s.sale_id) AS total_orders
FROM Products p
LEFT JOIN Sales s ON s.product_id = p.product_id
GROUP BY p.product_name
ORDER BY total_orders DESC;


-- Q.4 Average Sales Amount per City
-- What is the average sales amount per customer in each city?

SELECT
    ci.city_name,
    SUM(s.total) AS total_revenue,
    COUNT(DISTINCT s.customer_id) AS total_customers,
    ROUND(
        SUM(s.total) / NULLIF(COUNT(DISTINCT s.customer_id), 0),
        2
    ) AS avg_sale_per_customer
FROM Sales s
JOIN Customers c ON s.customer_id = c.customer_id
JOIN City ci ON ci.city_id = c.city_id
GROUP BY ci.city_name
ORDER BY total_revenue DESC;


-- Q.5 City Population and Coffee Consumers (25%)
-- Provide a list of cities along with their population and estimated
-- coffee consumers (city_name, total current customers, estimated
-- coffee consumers at 25%)

SELECT
    ci.city_name,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    ROUND((ci.population * 0.25) / 1000000, 2) AS coffee_consumers_million
FROM Sales s
JOIN Customers c ON s.customer_id = c.customer_id
JOIN City ci ON c.city_id = ci.city_id
GROUP BY ci.city_name, ci.population;


-- Q.6 Top Selling Products by City
-- What are the top 3 selling products in each city?

SELECT *
FROM (
    SELECT
        ci.city_name,
        p.product_name,
        COUNT(s.sale_id) AS total_orders,
        DENSE_RANK() OVER (
            PARTITION BY ci.city_name
            ORDER BY COUNT(s.sale_id) DESC
        ) AS ranking
    FROM Sales s
    JOIN Products p ON s.product_id = p.product_id
    JOIN Customers c ON c.customer_id = s.customer_id
    JOIN City ci ON ci.city_id = c.city_id
    GROUP BY ci.city_name, p.product_name
) AS t1
WHERE ranking <= 3;


-- Q.7 Customer Segmentation by City
-- How many unique customers are there in each city who have purchased
-- coffee products to consume (product_id 1-14 = drink/consumable items)?

SELECT
    ci.city_name,
    COUNT(DISTINCT c.customer_id) AS unique_customers
FROM Sales s
JOIN Products p ON s.product_id = p.product_id
JOIN Customers c ON c.customer_id = s.customer_id
JOIN City ci ON ci.city_id = c.city_id
WHERE p.product_id BETWEEN 1 AND 14
GROUP BY ci.city_name
ORDER BY unique_customers;


-- Q.8 Average Sale vs. Rent
-- Find each city and their average sale per customer and average
-- rent per customer.

SELECT
    ci.city_name,
    ROUND(SUM(s.total) / NULLIF(COUNT(DISTINCT s.customer_id), 0), 2) AS avg_sale_per_customer,
    ROUND(ci.estimated_rent / NULLIF(COUNT(DISTINCT s.customer_id), 0), 2) AS avg_rent_per_customer
FROM Sales s
JOIN Customers c ON s.customer_id = c.customer_id
JOIN City ci ON c.city_id = ci.city_id
GROUP BY ci.city_id, ci.city_name, ci.estimated_rent;


-- Q.9 Monthly Sales Growth
-- Calculate the percentage growth (or decline) in sales month over
-- month, by city. Guarded against NULL/zero previous-month values
-- (first month of data, or a month with no prior sales).

SELECT
    city_name,
    year,
    month,
    total_sales,
    previous_month_sales,
    ROUND(
        ((total_sales - previous_month_sales) / NULLIF(previous_month_sales, 0)) * 100,
        2
    ) AS growth_percentage
FROM (
    SELECT
        ci.city_name,
        YEAR(s.sale_date) AS year,
        MONTH(s.sale_date) AS month,
        SUM(s.total) AS total_sales,
        LAG(SUM(s.total)) OVER (
            PARTITION BY ci.city_name
            ORDER BY YEAR(s.sale_date), MONTH(s.sale_date)
        ) AS previous_month_sales
    FROM Sales s
    JOIN Customers c ON s.customer_id = c.customer_id
    JOIN City ci ON c.city_id = ci.city_id
    GROUP BY ci.city_name, YEAR(s.sale_date), MONTH(s.sale_date)
) AS monthly_sales
WHERE previous_month_sales IS NOT NULL;


-- Q.10 Market Potential Analysis
-- Identify the top 3 cities based on highest sales. Return city name,
-- total sale, total rent, total customers, estimated coffee consumers.

SELECT
    ci.city_name,
    SUM(s.total) AS total_sales,
    ci.estimated_rent AS total_rent,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    ROUND((ci.population * 0.25 / 1000000), 2) AS estimated_coffee_consumers_million,
    ROUND(SUM(s.total) / NULLIF(COUNT(DISTINCT c.customer_id), 0), 2) AS avg_sale_per_customer,
    ROUND(ci.estimated_rent / NULLIF(COUNT(DISTINCT c.customer_id), 0), 2) AS avg_rent_per_customer
FROM Sales s
JOIN Customers c ON s.customer_id = c.customer_id
JOIN City ci ON c.city_id = ci.city_id
GROUP BY ci.city_id, ci.city_name, ci.estimated_rent, ci.population
ORDER BY total_sales DESC
LIMIT 3;


-- Q.11 (NEW) Average Rating by Product
-- Which products are best/worst received by customers?
-- Uses the previously-unused `rating` column.

SELECT
    p.product_name,
    COUNT(s.sale_id) AS total_orders,
    ROUND(AVG(s.rating), 2) AS avg_rating
FROM Sales s
JOIN Products p ON s.product_id = p.product_id
WHERE s.rating IS NOT NULL
GROUP BY p.product_name
ORDER BY avg_rating DESC;


-- Q.12 (NEW) Average Rating by City
-- Does customer satisfaction vary by location?

SELECT
    ci.city_name,
    COUNT(s.sale_id) AS total_orders,
    ROUND(AVG(s.rating), 2) AS avg_rating
FROM Sales s
JOIN Customers c ON s.customer_id = c.customer_id
JOIN City ci ON c.city_id = ci.city_id
WHERE s.rating IS NOT NULL
GROUP BY ci.city_name
ORDER BY avg_rating DESC;


-- ============================================================
-- Recommendation
-- ============================================================
-- Based on the market potential analysis (Q.10), three cities stand
-- out as the strongest expansion targets:
--
-- 1. Pune
--    - Lowest average rent per customer among top cities
--    - Highest total revenue generated
--    - High average sale per customer, indicating strong per-visit spend
--
-- 2. Delhi
--    - Largest estimated coffee-consuming population (7.7M)
--    - Highest total customer count (68)
--    - Average rent per customer (~330) remains well under the 500 threshold
--
-- 3. Jaipur
--    - Highest customer count of the three (69)
--    - Very low average rent per customer (~156), the best cost efficiency
--    - Strong average sale per customer (~11.6k)
--
-- Together these cities offer the best balance of revenue potential,
-- customer demand, and operating cost, making them the top candidates
-- for continued or expanded investment.
