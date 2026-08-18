-- =========================================================================
-- LOGISTICS FREIGHT RECONCILIATION & OVERCHARGE AUDIT ENGINE (PostgreSQL)
-- =========================================================================

-- 1. Base CTE: Evaluate actual vs. billed rates across weight slabs and zones
WITH shipment_rates AS (
    SELECT 
        s.awb_number,
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
        COALESCE(r_actual_slab_billed_zone.rate, s.billed_rate) AS actual_slab_billed_zone_rate
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

-- 2. Line-Item Overcharge Breakdown by Rule
overcharge_breakdown AS (
    SELECT 
        awb_number,
        carrier,
        CASE WHEN actual_weight_slab != billed_weight_slab THEN billed_rate - actual_slab_billed_zone_rate ELSE 0 END AS weight_slab_overcharge,
        CASE WHEN destination_zone != billed_zone THEN actual_slab_billed_zone_rate - actual_contracted_rate ELSE 0 END AS zone_overcharge,
        CASE WHEN payment_mode = 'Prepaid' AND cod_charge > 0 THEN cod_charge ELSE 0 END AS cod_overcharge,
        CASE WHEN delivered = TRUE AND rto_charge > 0 THEN rto_charge ELSE 0 END AS rto_overcharge,
        CASE WHEN misc_charges > 0 THEN misc_charges ELSE 0 END AS misc_overcharge
    FROM shipment_rates
)

-- 3. Final Aggregated Report: Breakdown by Carrier
SELECT 
    carrier,
    ROUND(SUM(weight_slab_overcharge), 2) AS weight_slab_overcharge,
    ROUND(SUM(zone_overcharge), 2) AS zone_overcharge,
    ROUND(SUM(cod_overcharge), 2) AS cod_overcharge,
    ROUND(SUM(rto_overcharge), 2) AS rto_overcharge,
    ROUND(SUM(misc_overcharge), 2) AS misc_overcharge,
    ROUND(SUM(weight_slab_overcharge + zone_overcharge + cod_overcharge + rto_overcharge + misc_overcharge), 2) AS total_overcharge
FROM overcharge_breakdown
GROUP BY carrier
ORDER BY total_overcharge DESC;
