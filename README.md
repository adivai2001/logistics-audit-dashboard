# 🚚 Logistics Carrier Overbilling & Audit Reconciliation System

An enterprise SQL audit engine and interactive reconciliation dashboard built to analyze **8,000 shipment records** across **6 major carriers** (BlueDart, DTDC, Shadowfax, Xpressbees, Delhivery, and Ecom Express) against contracted rate cards to detect, categorize, and quantify systematic carrier overbilling.

---

## 🎯 Verification Key Performance Metrics

| Audit Metric | Amount (₹) |
| :--- | :---: |
| **Total Gross Overbilled Amount** | **₹14,438.07** |
| **Total Undercharged Adjustments (The total amount the merchant underpaid the carriers)** | **(₹434.16)** |
| **Net Recoverable Amount Owed** | **₹14,003.91** |

---

## 📊 Overbilling Breakdown Matrix (Carrier vs. Discrepancy Type)

| Overbilling Type | BlueDart (₹) | DTDC (₹) | Shadowfax (₹) | Xpressbees (₹) | Delhivery (₹) | Ecom Express (₹) | Total Overbilling (₹) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| **Weight Slab Mismatch** | 739.42 | 1,015.48 | 571.21 | 1,038.42 | 444.29 | 361.31 | **4,170.13** |
| **Zone Discrepancy** | 667.95 | 437.32 | 769.64 | 493.66 | 586.29 | 239.55 | **3,194.41** |
| **Weight + Zone Both Overcharged** | 0.00 | 0.00 | 0.00 | 0.00 | 155.09 | 0.00 | **155.09** |
| **Prepaid COD Charges** | 288.06 | 182.96 | 129.03 | 93.69 | 171.20 | 237.24 | **1,102.18** |
| **Delivered RTO Charges** | 1,527.12 | 782.95 | 568.98 | 571.04 | 549.68 | 445.76 | **4,445.53** |
| **Uncontracted Misc Charges** | 222.56 | 217.69 | 378.38 | 100.92 | 259.09 | 192.09 | **1,370.73** |
| **Total Gross Overbilling** | **3,445.11** | **2,636.40** | **2,417.24** | **2,297.73** | **2,165.64** | **1,475.95** | **₹14,438.07** |

---

## 📝 Executive Write-Up (Audit Findings & Recommendations)

### 1. Approach & Audit Logic
We built an automated relational SQL pipeline that cross-joins shipment billing entries against rate cards (`sc_rate_card.json` / `carrier_rates` table). Every shipment is evaluated across five overbilling vectors:
* **Weight Slab Mismatch:** Re-evaluates actual package weight against contract weight tiers (`actual_weight_slab != billed_weight_slab`).
* **Zone Discrepancy:** Catches zone reclassifications (`destination_zone != billed_zone`).
* **Prepaid COD Fraud:** Identifies COD collection fees levied on orders paid online (`payment_mode = 'Prepaid' AND cod_charge > 0`).
* **Delivered RTO Fraud:** Flags Return-to-Origin fees assessed on successfully delivered packages (`delivered = TRUE AND rto_charge > 0`).
* **Uncontracted Misc Charges:** Flags undocumented handling or documentation surcharges (`misc_charges > 0`).

### 2. Worst Offenders & Pattern Analysis
* **Top Offending Carrier:** **BlueDart** generated the largest single overbilling footprint at **₹3,445.11**, primarily driven by **Delivered RTO Charges (₹1,527.12)**.
* **Top Discrepancy Category:** **Delivered RTO Charges** across all carriers accounted for **₹4,445.53** (30.8% of total overbilling), followed closely by **Weight Slab Mismatch** at **₹4,170.13** (28.9%).
* **Systemic Fraud vs. Mistakes:** While Weight & Zone errors appear scattered across all carriers, **Prepaid COD Charges** and **Delivered RTO Charges** show systemic programmatic billing bugs on carrier API integrations.

### 3. Recommended Remediation & Action Plan
1. **Immediate Billing Clawback:** Issue debit notes to BlueDart (₹3,445.11) and DTDC (₹2,636.40) to recover **₹14,003.91 (Net)** immediately.
2. **Automated API Pre-Audit:** Implement real-time rate card verification prior to invoice clearance. Automatically block automated payouts whenever a delivered order contains an RTO line-item or a prepaid shipment includes a COD surcharge.
3. **Contract Surcharge Hardening:** Formalize contract amendments explicitly capping uncontracted miscellaneous handling fees to zero.

---

## 🛠️ Repository File Structure

```text
├── SQL/
│   ├── Overbilling_Total_2.sql    # Total overbilling summary & undercharge net calculations
│   ├── Overbilling_level_2.sql    # 2D Matrix of overbilling categories by carrier
│   └── Carrier_Level_2.sql        # Aggregated carrier metrics
├── Dashboard/
│   └── dashboard.html             # Client-side HTML5/Chart.js reconciliation dashboard
└── README.md                      # Audit documentation & write-up
