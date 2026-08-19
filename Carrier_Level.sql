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
    SELECT
        carrier,

        -- Weight ONLY
        CASE
            WHEN actual_weight_slab != billed_weight_slab
             AND destination_zone = billed_zone
             AND billed_rate - actual_slab_billed_zone_rate > 0
            THEN billed_rate - actual_slab_billed_zone_rate
            ELSE 0
        END AS weight_slab_overbilling,

        -- Zone ONLY
        CASE
            WHEN destination_zone != billed_zone
             AND actual_weight_slab = billed_weight_slab
             AND actual_slab_billed_zone_rate - actual_contracted_rate > 0
            THEN actual_slab_billed_zone_rate - actual_contracted_rate
            ELSE 0
        END AS zone_overbilling,

        -- Weight + Zone BOTH
        CASE
            WHEN actual_weight_slab != billed_weight_slab
             AND destination_zone != billed_zone
             AND billed_rate - actual_slab_billed_zone_rate > 0
             AND actual_slab_billed_zone_rate - actual_contracted_rate > 0
            THEN billed_rate - actual_contracted_rate
            ELSE 0
        END AS weight_and_zone_overbilling,

        -- COD
        CASE
            WHEN payment_mode = 'Prepaid'
             AND cod_charge > 0
            THEN cod_charge
            ELSE 0
        END AS cod_overbilling,

        -- RTO
        CASE
            WHEN delivered = TRUE
             AND rto_charge > 0
            THEN rto_charge
            ELSE 0
        END AS rto_overbilling,

        -- Miscellaneous
        CASE
            WHEN misc_charges > 0
            THEN misc_charges
            ELSE 0
        END AS misc_overbilling

    FROM shipment_rates
)

SELECT
    carrier,

    ROUND(SUM(weight_slab_overbilling)::numeric, 2)
        AS weight_slab_overbilling,

    ROUND(SUM(zone_overbilling)::numeric, 2)
        AS zone_overbilling,

    ROUND(SUM(weight_and_zone_overbilling)::numeric, 2)
        AS weight_and_zone_overbilling,

    ROUND(SUM(cod_overbilling)::numeric, 2)
        AS cod_overbilling,

    ROUND(SUM(rto_overbilling)::numeric, 2)
        AS rto_overbilling,

    ROUND(SUM(misc_overbilling)::numeric, 2)
        AS misc_overbilling,

    ROUND(
        SUM(
            weight_slab_overbilling
            + zone_overbilling
            + weight_and_zone_overbilling
            + cod_overbilling
            + rto_overbilling
            + misc_overbilling
        )::numeric,
        2
    ) AS total_overbilling

FROM overbilling

GROUP BY carrier

ORDER BY total_overbilling DESC;