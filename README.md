# Logistics Rate Card Reconciliation & PostgreSQL Audit Dashboard

## 📊 Audit Executive Summary
* **Net Verified Overcharge:** **₹14,003.91**
* **Database Engine:** PostgreSQL (JSONB Bulk Ingestion & CTE Architecture)

---

## 📈 Breakdown by Overbilling Type

| Overbilling Type | Total Amount (₹) | Share (%) | Root Cause |
| :--- | :--- | :--- | :--- |
| **Delivered RTO Charges** | **₹4,445.53** | 31.7% | Carriers charging return fees on delivered orders |
| **Weight Slab Mismatch** | **₹3,987.97** | 28.5% | Up-billing physical weight brackets |
| **Zone Discrepancy** | **₹3,097.50** | 22.1% | Destination zone inflation |
| **Uncontracted Misc Fees** | **₹1,370.73** | 9.8% | Surcharges missing from baseline contract |
| **Prepaid COD Fees** | **₹1,102.18** | 7.9% | COD collection fees levied on prepaid orders |
| **Total Net Overcharge** | **₹14,003.91** | **100.0%** | **Deduplicated Total** |

---

## 🚚 Breakdown by Carrier

| Carrier | Weight Slab (₹) | Zone (₹) | Prepaid COD (₹) | Delivered RTO (₹) | Misc (₹) | Total Overcharge (₹) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **BlueDart** | ₹724.24 | ₹628.09 | ₹288.06 | ₹1,527.12 | ₹222.56 | **₹3,390.07** |
| **DTDC** | ₹1,015.48 | ₹421.76 | ₹182.96 | ₹782.95 | ₹217.69 | **₹2,620.84** |
| **Shadowfax** | ₹541.08 | ₹766.83 | ₹129.03 | ₹568.98 | ₹378.38 | **₹2,384.30** |
| **Xpressbees** | ₹954.53 | ₹403.93 | ₹93.69 | ₹571.04 | ₹100.92 | **₹2,124.11** |
| **Delhivery** | ₹409.29 | ₹637.34 | ₹171.20 | ₹549.68 | ₹259.09 | **₹2,026.60** |
| **Ecom Express** | ₹343.35 | ₹239.55 | ₹237.24 | ₹445.76 | ₹192.09 | **₹1,457.99** |
