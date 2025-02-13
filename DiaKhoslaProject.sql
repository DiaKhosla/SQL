-- Checking the data in the tables

SHOW TABLES;

USE diakhosla_final_project;

SELECT * FROM DiaKhosla_Final_Project.dim_drug;
SELECT * FROM DiaKhosla_Final_Project.dim_member;
SELECT * FROM DiaKhosla_Final_Project.fact_prescriptions;

-- Primary Key for dim_member (surrogate key)
ALTER TABLE DiaKhosla_Final_Project.dim_member
ADD PRIMARY KEY (member_id);

-- Primary Key for dim_drug (natural key)
ALTER TABLE DiaKhosla_Final_Project.dim_drug
ADD PRIMARY KEY (drug_ndc);

-- Composite Primary Key for fact_prescriptions
ALTER TABLE DiaKhosla_Final_Project.fact_prescriptions
ADD PRIMARY KEY (member_id, drug_ndc);

-- Foreign Key for member_id in fact_prescriptions (references dim_member)
ALTER TABLE DiaKhosla_Final_Project.fact_prescriptions
ADD CONSTRAINT fk_member_id
FOREIGN KEY (member_id) REFERENCES DiaKhosla_Final_Project.dim_member(member_id)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Foreign Key for drug_ndc in fact_prescriptions (references dim_drug)
ALTER TABLE DiaKhosla_Final_Project.fact_prescriptions
ADD CONSTRAINT fk_drug_ndc
FOREIGN KEY (drug_ndc) REFERENCES DiaKhosla_Final_Project.dim_drug(drug_ndc)
ON DELETE CASCADE
ON UPDATE CASCADE;

-- Task 1: Number of prescriptions grouped by drug name
SELECT 
    d.drug_name, 
    COUNT(f.member_id) AS number_of_prescriptions
FROM 
    DiaKhosla_Final_Project.fact_prescriptions f
JOIN 
    DiaKhosla_Final_Project.dim_drug d ON f.drug_ndc = d.drug_ndc
GROUP BY 
    d.drug_name;

-- Task 2: Total prescriptions, unique members, sums for copay and insurance paid grouped by age
SELECT
    CASE 
        WHEN m.member_age >= 65 THEN 'Age 65+'
        ELSE 'Age < 65'
    END AS age_group,
    COUNT(f.member_id) AS total_prescriptions,
    COUNT(DISTINCT f.member_id) AS unique_members,
    SUM(f.copay1 + f.copay2 + f.copay3) AS total_copay,
    SUM(f.insurancepaid1 + f.insurancepaid2 + f.insurancepaid3) AS total_insurancepaid
FROM 
    DiaKhosla_Final_Project.fact_prescriptions f
JOIN 
    DiaKhosla_Final_Project.dim_member m ON f.member_id = m.member_id
GROUP BY 
    age_group;
    
-- Task 3: Most recent prescription fill date and insurance paid
WITH RecentPrescriptions AS (
    SELECT 
        f.member_id, 
        m.member_first_name, 
        m.member_last_name, 
        d.drug_name, 
        -- Ensuring fill dates are valid (non-null)
        GREATEST(
            IFNULL(STR_TO_DATE(f.fill_date1, '%m/%d/%Y'), '1970-01-01'),
            IFNULL(STR_TO_DATE(f.fill_date2, '%m/%d/%Y'), '1970-01-01'),
            IFNULL(STR_TO_DATE(f.fill_date3, '%m/%d/%Y'), '1970-01-01')
        ) AS most_recent_fill_date,
        -- Summing up insurance payments
        f.insurancepaid1 + f.insurancepaid2 + f.insurancepaid3 AS insurance_paid,
        -- Row number to select most recent prescription for each member
        ROW_NUMBER() OVER (
            PARTITION BY f.member_id 
            ORDER BY GREATEST(
                IFNULL(STR_TO_DATE(f.fill_date1, '%m/%d/%Y'), '1970-01-01'),
                IFNULL(STR_TO_DATE(f.fill_date2, '%m/%d/%Y'), '1970-01-01'),
                IFNULL(STR_TO_DATE(f.fill_date3, '%m/%d/%Y'), '1970-01-01')
            ) DESC
        ) AS rn
    FROM 
        DiaKhosla_Final_Project.fact_prescriptions f
    JOIN 
        DiaKhosla_Final_Project.dim_member m ON f.member_id = m.member_id
    JOIN 
        DiaKhosla_Final_Project.dim_drug d ON f.drug_ndc = d.drug_ndc
    -- Excluding rows where all fill dates are NULL
    WHERE 
        f.fill_date1 IS NOT NULL OR f.fill_date2 IS NOT NULL OR f.fill_date3 IS NOT NULL
)
SELECT 
    member_id, 
    member_first_name, 
    member_last_name, 
    drug_name, 
    most_recent_fill_date, 
    insurance_paid
FROM 
    RecentPrescriptions
WHERE 
    rn = 1;