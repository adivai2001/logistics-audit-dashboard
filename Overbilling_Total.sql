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

raw_diffs AS (
    SELECT 
        awb_number,
        carrier,

        (actual_weight_slab != billed_weight_slab) AS weight_wrong,
        (destination_zone != billed_zone) AS zone_wrong,

        CASE 
            WHEN actual_weight_slab != billed_weight_slab 
            THEN ROUND(
                (billed_rate - actual_slab_billed_zone_rate)::numeric, 
                2
            )
            ELSE 0 
        END AS weight_diff,

        CASE 
            WHEN destination_zone != billed_zone 
            THEN ROUND(
                (actual_slab_billed_zone_rate - actual_contracted_rate)::numeric, 
                2
            )
            ELSE 0 
        END AS zone_diff,

        CASE 
            WHEN payment_mode = 'Prepaid' 
             AND cod_charge > 0 
            THEN cod_charge 
            ELSE 0 
        END AS cod_overcharge,

        CASE 
            WHEN delivered = TRUE 
             AND rto_charge > 0 
            THEN rto_charge 
            ELSE 0 
        END AS rto_overcharge,

        CASE 
            WHEN misc_charges > 0 
            THEN misc_charges 
            ELSE 0 
        END AS misc_overcharge

    FROM shipment_rates
),

split AS (
    SELECT
        awb_number,
        carrier,

        weight_wrong,
        zone_wrong,

        -- Overcharge components
        GREATEST(weight_diff, 0) AS weight_overcharge_part,
        GREATEST(zone_diff, 0) AS zone_overcharge_part,

        -- Underpaid components
        GREATEST(-weight_diff, 0) AS weight_underpaid_part,
        GREATEST(-zone_diff, 0) AS zone_underpaid_part,

        cod_overcharge,
        rto_overcharge,
        misc_overcharge

    FROM raw_diffs
),

summary AS (
    SELECT 

        -- OVERCHARGE

        ROUND(
            SUM(
                CASE 
                    WHEN weight_wrong 
                     AND NOT zone_wrong
                    THEN weight_overcharge_part
                    ELSE 0
                END
            )::numeric, 2
        ) AS weight_only_overcharge,

        ROUND(
            SUM(
                CASE 
                    WHEN zone_wrong 
                     AND NOT weight_wrong
                    THEN zone_overcharge_part
                    ELSE 0
                END
            )::numeric, 2
        ) AS zone_only_overcharge,

        ROUND(
            SUM(
                CASE 
                    WHEN weight_wrong
                     AND zone_wrong
                     AND weight_overcharge_part > 0
                     AND zone_overcharge_part > 0
                    THEN weight_overcharge_part + zone_overcharge_part
                    ELSE 0
                END
            )::numeric, 2
        ) AS weight_and_zone_both_overcharge,

        ROUND(SUM(cod_overcharge)::numeric, 2) AS cod_overcharge,

        ROUND(SUM(rto_overcharge)::numeric, 2) AS rto_overcharge,

        ROUND(SUM(misc_overcharge)::numeric, 2) AS misc_overcharge,

        ROUND(
            SUM(
                weight_overcharge_part
                + zone_overcharge_part
                + cod_overcharge
                + rto_overcharge
                + misc_overcharge
            )::numeric, 2
        ) AS total_overcharge,


        -- UNDERPAID

        ROUND(
            SUM(
                CASE 
                    WHEN weight_wrong 
                     AND NOT zone_wrong
                    THEN weight_underpaid_part
                    ELSE 0
                END
            )::numeric, 2
        ) AS weight_slab_underpaid,

        ROUND(
            SUM(
                CASE 
                    WHEN zone_wrong 
                     AND NOT weight_wrong
                    THEN zone_underpaid_part
                    ELSE 0
                END
            )::numeric, 2
        ) AS zone_underpaid,

        ROUND(
            SUM(
                CASE 
                    WHEN weight_wrong
                     AND zone_wrong
                     AND weight_underpaid_part > 0
                     AND zone_underpaid_part > 0
                    THEN weight_underpaid_part + zone_underpaid_part
                    ELSE 0
                END
            )::numeric, 2
        ) AS weight_and_zone_both_underpaid,

        ROUND(
            SUM(
                weight_underpaid_part
                + zone_underpaid_part
            )::numeric, 2
        ) AS total_underpaid,


        -- NET

        ROUND(
            (
                SUM(
                    weight_overcharge_part
                    + zone_overcharge_part
                    + cod_overcharge
                    + rto_overcharge
                    + misc_overcharge
                )
                -
                SUM(
                    weight_underpaid_part
                    + zone_underpaid_part
                )
            )::numeric, 2
        ) AS net_amount_owed,


        -- SHIPMENT COUNTS

        COUNT(
            CASE 
                WHEN weight_wrong
                 AND NOT zone_wrong
                 AND weight_overcharge_part > 0
                THEN 1
            END
        ) AS weight_only_shipments,

        COUNT(
            CASE 
                WHEN zone_wrong
                 AND NOT weight_wrong
                 AND zone_overcharge_part > 0
                THEN 1
            END
        ) AS zone_only_shipments,

        COUNT(
            CASE 
                WHEN weight_wrong
                 AND zone_wrong
                 AND weight_overcharge_part > 0
                 AND zone_overcharge_part > 0
                THEN 1
            END
        ) AS both_overcharge_shipments,

        COUNT(
            CASE 
                WHEN weight_wrong
                 AND zone_wrong
                 AND weight_underpaid_part > 0
                 AND zone_underpaid_part > 0
                THEN 1
            END
        ) AS both_underpaid_shipments

    FROM split
)

SELECT 
    v.metric,
    v.value
FROM summary s

CROSS JOIN LATERAL (
    VALUES
        ('weight_only_overcharge', s.weight_only_overcharge::numeric),
        ('zone_only_overcharge', s.zone_only_overcharge::numeric),
        ('weight_and_zone_both_overcharge', s.weight_and_zone_both_overcharge::numeric),
        ('cod_overcharge', s.cod_overcharge::numeric),
        ('rto_overcharge', s.rto_overcharge::numeric),
        ('misc_overcharge', s.misc_overcharge::numeric),
        ('total_overcharge', s.total_overcharge::numeric),

        ('weight_slab_undercharge', s.weight_slab_underpaid::numeric),
        ('zone_undercharge', s.zone_underpaid::numeric),
        ('weight_and_zone_both_undercharge', s.weight_and_zone_both_underpaid::numeric),
        ('total_undercharge', s.total_underpaid::numeric),

        ('Total_Overcharged_Amount', s.net_amount_owed::numeric)
) v(metric, value);