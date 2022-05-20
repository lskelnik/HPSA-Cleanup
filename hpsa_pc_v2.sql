/*  
Clean up HPSA (Health Professional Shortage Area) primary care dataset. Sourced from data.hrsa.gov
Display highest need shortage areas by number of primary care FTEs needed and percent of population underserved

Skills used: numeric functions, date formatting, table modifications, string functions
*/

-- Simplify name of withdrawn date column

ALTER TABLE primary_care
RENAME COLUMN HPSA_Withdrawn_Date_String TO HPSA_Withdrawn_Date

-- Convert all text date columns to standard format yyyy-mm-dd
UPDATE primary_care 
SET 
    HPSA_Designation_Date = str_to_date(HPSA_Designation_Date, '%m/%d/%Y'),
    HPSA_Designation_Last_Update_Date = str_to_date(HPSA_Designation_Last_Update_Date, '%m/%d/%Y'),
    Withdrawn_Date = str_to_date(Withdrawn_Date, '%m/%d/%Y'),
    HPSA_Withdrawn_Date = str_to_date(HPSA_Withdrawn_Date, '%m/%d/%Y'),
    Data_Warehouse_Record_Create_Date = str_to_date(Data_Warehouse_Record_Create_Date, '%m/%d/%Y'),
    Data_Warehouse_Record_Create_Date_Text = str_to_date(Data_Warehouse_Record_Create_Date_Text, '%m/%d/%Y')

-- Change data type from Text to Date for previously updated columns with dates 

ALTER TABLE primary_care
MODIFY COLUMN HPSA_Designation_Date DATE NULL,
MODIFY COLUMN HPSA_Designation_Last_Update_Date DATE NULL,
MODIFY COLUMN HPSA_Withdrawn_Date DATE NULL,
MODIFY COLUMN Data_Warehouse_Record_Create_Date DATE NULL

-- Break out common county name to omit state abbreviation

UPDATE primary_care
SET Common_County_Name = SUBSTRING(Common_County_Name, 1, LOCATE(',', Common_County_Name) -1)

-- Remove integers and special characters from HPSA_Component_Name column, of data type string

UPDATE primary_care
SET HPSA_Component_Name = REPLACE(HPSA_Component_Name, '.', ''),
    HPSA_Component_Name = REPLACE(HPSA_Component_Name, ',', ''),
    HPSA_Component_Name = REPLACE(HPSA_Component_Name, '0', ''),
    HPSA_Component_Name = REPLACE(HPSA_Component_Name, '1', ''),
    HPSA_Component_Name = REPLACE(HPSA_Component_Name, '2', ''),
    HPSA_Component_Name = REPLACE(HPSA_Component_Name, '3', ''),
    HPSA_Component_Name = REPLACE(HPSA_Component_Name, '4', ''),
    HPSA_Component_Name = REPLACE(HPSA_Component_Name, '5', ''),
    HPSA_Component_Name = REPLACE(HPSA_Component_Name, '6', ''),
    HPSA_Component_Name = REPLACE(HPSA_Component_Name, '7', ''),
    HPSA_Component_Name = REPLACE(HPSA_Component_Name, '8', ''),
    HPSA_Component_Name = REPLACE(HPSA_Component_Name, '9', '')

-- Change empty and blank values after removing integers, etc. to NULL
UPDATE primary_care
SET HPSA_Component_Name = NULL
WHERE HPSA_Component_Name = ''

UPDATE primary_care
SET HPSA_Component_Name = NULL
WHERE HPSA_Component_Name = ' '

-- Set rows with all caps text to upper case first letter and lower case for remainder of string

UPDATE primary_care
SET HPSA_Component_Name = 
    CONCAT(UPPER(SUBSTRING(HPSA_Component_Name, 1, 1)), LOWER(SUBSTRING(HPSA_Component_Name, 2)))
WHERE HPSA_Component_Name = BINARY UPPER(HPSA_Component_Name)

UPDATE primary_care
SET HPSA_Name =
    CONCAT(UPPER(SUBSTRING(HPSA_Name, 1, 1)), LOWER(SUBSTRING(HPSA_Name, 2)))
WHERE HPSA_Name = BINARY UPPER(HPSA_Name)

-- Remove the commas and county and state names in certain rows in HPSA_Component_Name column
UPDATE primary_care
SET HPSA_Component_Name = SUBSTRING(HPSA_Component_Name, 1, 12)
WHERE HPSA_Component_Name LIKE '%Census Tract%'

-- Set 0 values to NULL for Metropolitan Indicator Code
UPDATE primary_care
SET HPSA_Metropolitan_Indicator_Code = NULL
WHERE HPSA_Metropolitan_Indicator_Code = '0'

-- Update rows where estimated served population and estimated underserved population are both zero. 
-- Underserved population should be the difference between designation population and served population

UPDATE primary_care
SET HPSA_Estimated_Underserved_Population = HPSA_Designation_Population
WHERE HPSA_Estimated_Served_Population = '0'

-- Update HPSA_Shortage column to have consistent number of decimal places. Majority have 2, but some have 4.
UPDATE primary_care
SET HPSA_Shortage = ROUND(HPSA_Shortage, 2)

-- Update rows in HPSA_Name column to have consistent wording
UPDATE primary_care
    SET HPSA_Name = REPLACE(HPSA_Name, 'Indian/Ho-Chunk', 'Indian - Ho-Chunk')
        HPSA_Name = REPLACE(HPSA_Name, '(Simplified)', ''),        
        HPSA_Name = REPLACE(HPSA_Name, 'MFW', 'Migrant Farmworkers'),
        HPSA_Name = REPLACE(HPSA_Name, 'Migrant Farmworker', 'Migrant Farmworkers'),
        HPSA_Name = REPLACE(HPSA_Name, 'LI', 'Low Income')

-- Remove duplicate columns
ALTER TABLE primary_care 
DROP COLUMN Withdrawn_Date,
DROP COLUMN Data_Warehouse_Record_Create_Date_Text 

-- Show HPSAs by state and county, ordered by HPSA_shortage (number of FTE healthcare providers needed) 
-- and percent of the population who are underserved

CREATE OR REPLACE VIEW HPSA_by_shortage AS
SELECT
    HPSA_Score,
    HPSA_Shortage,
    Common_County_Name AS County,
    Primary_State_Name AS State,
    HPSA_Designation_Population AS Population,
    HPSA_Estimated_Served_Population AS Served_Population,
    HPSA_Estimated_Underserved_Population AS Underserved_Population,
    ROUND((HPSA_Estimated_underserved_Population / HPSA_Designation_Population * 100), 2) AS Percent_Underserved
FROM primary_care
WHERE HPSA_Status = 'Designated' AND HPSA_Estimated_Served_Population <> 0 AND HPSA_Shortage IS NOT NULL
GROUP BY Primary_State_Name, Common_County_Name
ORDER BY HPSA_Shortage DESC, percent_underserved DESC






