WITH shipment_rates AS (
    SELECT 
        s.carrier,
        s.payment_mode,
        s.delivered,
        s.actual_weight_slab,
        s.billed_weight_slab,
        s.destination_zone,
        s.billed_zone,
        s.billed_rate,
        s.cod_charge,
        s.rto_charge,
        s.misc_charges,

        COALESCE(r_actual.rate, s.contracted_rate) AS actual_contracted_rate,

        COALESCE(
            r_actual_slab_billed_zone.rate,
            s.billed_rate
        ) AS actual_slab_billed_zone_rate

    FROM shipments s

    LEFT JOIN carrier_rates r_actual
        ON s.carrier = r_actual.carrier_name
       AND s.destination_zone = r_actual.zone
       AND s.actual_weight_slab = r_actual.weight_slab

    LEFT JOIN carrier_rates r_actual_slab_billed_zone
        ON s.carrier = r_actual_slab_billed_zone.carrier_name
       AND s.billed_zone = r_actual_slab_billed_zone.zone
       AND s.actual_weight_slab = r_actual_slab_billed_zone.weight_slab
),

overbilling AS (

    -- ==========================================
    -- WEIGHT + ZONE BOTH OVERCHARGED
    -- ==========================================

    SELECT
        carrier,
        'Weight + Zone Both Overcharged' AS overbilling_type,
        billed_rate - actual_contracted_rate AS amount

    FROM shipment_rates

    WHERE actual_weight_slab != billed_weight_slab
      AND destination_zone != billed_zone
      AND billed_rate - actual_slab_billed_zone_rate > 0
      AND actual_slab_billed_zone_rate - actual_contracted_rate > 0


    UNION ALL


    -- ==========================================
    -- WEIGHT SLAB ONLY
    -- ==========================================

    SELECT
        carrier,
        'Weight Slab Mismatch',
        billed_rate - actual_slab_billed_zone_rate

    FROM shipment_rates

    WHERE actual_weight_slab != billed_weight_slab
      AND destination_zone = billed_zone
      AND billed_rate - actual_slab_billed_zone_rate > 0


    UNION ALL


    -- ==========================================
    -- ZONE ONLY
    -- ==========================================

    SELECT
        carrier,
        'Zone Discrepancy',
        actual_slab_billed_zone_rate - actual_contracted_rate

    FROM shipment_rates

    WHERE destination_zone != billed_zone
      AND actual_weight_slab = billed_weight_slab
      AND actual_slab_billed_zone_rate - actual_contracted_rate > 0


    UNION ALL


    -- ==========================================
    -- PREPAID COD
    -- ==========================================

    SELECT
        carrier,
        'Prepaid COD Charges',
        cod_charge

    FROM shipment_rates

    WHERE payment_mode = 'Prepaid'
      AND cod_charge > 0


    UNION ALL


    -- ==========================================
    -- DELIVERED RTO
    -- ==========================================

    SELECT
        carrier,
        'Delivered RTO Charges',
        rto_charge

    FROM shipment_rates

    WHERE delivered = TRUE
      AND rto_charge > 0


    UNION ALL


    -- ==========================================
    -- MISCELLANEOUS
    -- ==========================================

    SELECT
        carrier,
        'Uncontracted Misc Charges',
        misc_charges

    FROM shipment_rates

    WHERE misc_charges > 0
),

summary AS (
    SELECT
        overbilling_type,

        SUM(amount) FILTER (
            WHERE carrier = 'BlueDart'
        ) AS "BlueDart",

        SUM(amount) FILTER (
            WHERE carrier = 'DTDC'
        ) AS "DTDC",

        SUM(amount) FILTER (
            WHERE carrier = 'Shadowfax'
        ) AS "Shadowfax",

        SUM(amount) FILTER (
            WHERE carrier = 'Xpressbees'
        ) AS "Xpressbees",

        SUM(amount) FILTER (
            WHERE carrier = 'Delhivery'
        ) AS "Delhivery",

        SUM(amount) FILTER (
            WHERE carrier = 'Ecom Express'
        ) AS "Ecom Express",

        SUM(amount) AS total_overbilling

    FROM overbilling

    GROUP BY overbilling_type
)

SELECT
    overbilling_type,

    ROUND(COALESCE("BlueDart", 0)::numeric, 2) AS "BlueDart",
    ROUND(COALESCE("DTDC", 0)::numeric, 2) AS "DTDC",
    ROUND(COALESCE("Shadowfax", 0)::numeric, 2) AS "Shadowfax",
    ROUND(COALESCE("Xpressbees", 0)::numeric, 2) AS "Xpressbees",
    ROUND(COALESCE("Delhivery", 0)::numeric, 2) AS "Delhivery",
    ROUND(COALESCE("Ecom Express", 0)::numeric, 2) AS "Ecom Express",

    ROUND(total_overbilling::numeric, 2) AS "Total Overbilling"

FROM summary

ORDER BY
    CASE overbilling_type
        WHEN 'Weight Slab Mismatch' THEN 1
        WHEN 'Zone Discrepancy' THEN 2
        WHEN 'Weight + Zone Both Overcharged' THEN 3
        WHEN 'Prepaid COD Charges' THEN 4
        WHEN 'Delivered RTO Charges' THEN 5
        WHEN 'Uncontracted Misc Charges' THEN 6
    END;