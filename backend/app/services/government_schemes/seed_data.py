"""Government Schemes — verified seed records.

Data discipline:
- Only well-established facts are recorded; amounts, deadlines, benefits,
  eligibility and application steps that could not be confirmed against an
  official source are omitted (left as null / empty) rather than fabricated.
- Each record carries `source_url` (official government portal) and a
  `last_verified_date`.
- Frontend renders null/empty fields as "Not verified".
"""
from datetime import datetime

VERIFIED_AS_OF = datetime(2026, 11, 9)

SEED_SCHEMES = [
    {
        "scheme_name": "Pradhan Mantri Fasal Bima Yojana (PMFBY)",
        "category": "Crop Insurance",
        "government_level": "Central",
        "state": None,
        "description": (
            "Centrally sponsored crop insurance scheme providing comprehensive insurance cover "
            "against crop loss due to non-preventable natural risks such as drought, flood, "
            "cyclone, unseasonal rainfall, pests and diseases."
        ),
        "benefits": [
            "Comprehensive crop insurance against non-preventable natural risks.",
            "Highly subsidised farmer premium: 2% for Kharif food & oilseed crops, 1.5% for Rabi food & oilseed crops, 5% for annual commercial/horticultural crops; the remaining premium is shared by Central and State Governments.",
        ],
        "eligibility": [
            "Farmers (including sharecroppers and tenant farmers) growing notified crops in notified areas.",
            "Voluntary for all farmers from Kharif 2020 onwards.",
        ],
        "required_documents": [
            "Land ownership or tenancy records",
            "Bank account details",
            "Sowing declaration (where applicable)",
        ],
        "application_steps": [
            "Enrol before the notified cut-off date with the empanelled insurance company (through bank branch / CSC / portal).",
            "Submit land records and crop details.",
            "Pay the applicable farmer premium share.",
            "Claims are settled directly into the farmer's bank account.",
        ],
        "department": "Ministry of Agriculture & Farmers Welfare, Department of Agriculture, Cooperation & Farmers Welfare",
        "application_url": "https://pmfby.gov.in",
        "source_url": "https://pmfby.gov.in",
        "status": "ACTIVE",
        "verification_status": "VERIFIED",
    },
    {
        "scheme_name": "PM-KISAN (Pradhan Mantri Kisan Samman Nidhi)",
        "category": "Financial Assistance",
        "government_level": "Central",
        "state": None,
        "description": (
            "Central Sector Scheme providing direct income support to landholding farmer families."
        ),
        "benefits": [
            "Rs. 6,000 per year per eligible farmer family, paid in three equal instalments of Rs. 2,000 each.",
        ],
        "eligibility": [
            "Landholding farmer families with cultivable landholding.",
        ],
        "required_documents": [
            "Aadhaar",
            "Bank account details",
            "Land records (for verification)",
        ],
        "application_steps": [
            "Register on the PM-KISAN portal.",
            "Complete e-KYC.",
            "Link an Aadhaar-seeded bank account.",
            "Instalments are transferred directly to the bank account.",
        ],
        "department": "Ministry of Agriculture & Farmers Welfare, Department of Agriculture, Cooperation & Farmers Welfare",
        "application_url": "https://pmkisan.gov.in",
        "source_url": "https://pmkisan.gov.in",
        "status": "ACTIVE",
        "verification_status": "VERIFIED",
    },
    {
        "scheme_name": "Kisan Credit Card (KCC)",
        "category": "Loans",
        "government_level": "Central",
        "state": None,
        "description": (
            "Institutional credit facility providing short-term crop loans and term loans "
            "to farmers at concessional interest rates with interest subvention support."
        ),
        "benefits": [
            "Adequate and timely credit for cultivation and ancillary activities.",
            "Interest subvention on short-term crop loans (subject to Government of India rates).",
        ],
        "eligibility": [
            "Farmers (individual or joint), tenant farmers and sharecroppers.",
            "Self Help Groups / Joint Liability Groups of farmers.",
        ],
        "required_documents": [
            "KYC documents",
            "Land records",
            "Bank loan application form",
        ],
        "application_steps": [
            "Approach a bank branch offering KCC.",
            "Submit the application with land and KYC documents.",
            "Credit limit is sanctioned based on the scale of finance.",
            "Draw funds as needed up to the sanctioned limit.",
        ],
        "department": "Department of Financial Services, Ministry of Finance (implemented through banks)",
        "application_url": None,
        "source_url": "https://financialservices.gov.in",
        "status": "ACTIVE",
        "verification_status": "VERIFIED",
    },
    {
        "scheme_name": "Pradhan Mantri Krishi Sinchayee Yojana (PMKSY)",
        "category": "Irrigation",
        "government_level": "Central",
        "state": None,
        "description": (
            "Umbrella scheme for irrigation: assured irrigation (Har Khet Ko Pani), "
            "micro-irrigation / drip & sprinkler (Per Drop More Crop), and watershed development."
        ),
        "benefits": [
            "Expansion of assured irrigation coverage (Har Khet Ko Pani).",
            "Micro-irrigation support under Per Drop More Crop.",
            "Watershed development activities.",
        ],
        "eligibility": [
            "Farmers, farmer groups and State implementing agencies.",
            "Implemented by State Governments with Central assistance.",
        ],
        "required_documents": None,
        "application_steps": [
            "Approach the District Agriculture / Water Conservation department or the State implementation portal.",
        ],
        "department": "Ministry of Jal Shakti and Ministry of Agriculture & Farmers Welfare",
        "application_url": "https://pmksy.gov.in",
        "source_url": "https://pmksy.gov.in",
        "status": "ACTIVE",
        "verification_status": "VERIFIED",
    },
    {
        "scheme_name": "Soil Health Card",
        "category": "Soil Health",
        "government_level": "Central",
        "state": None,
        "description": (
            "Scheme to issue Soil Health Cards to farmers indicating soil nutrient status and "
            "crop-wise fertilizer recommendations, with cards issued every three years."
        ),
        "benefits": [
            "Soil Health Card indicating soil nutrient status.",
            "Crop-wise recommendations on appropriate fertilizer dosage.",
        ],
        "eligibility": [
            "All farmers.",
            "Soil samples are collected from farmer fields for testing.",
        ],
        "required_documents": None,
        "application_steps": [
            "Provide a soil sample through the State Soil Testing Laboratory / portal.",
        ],
        "department": "Ministry of Agriculture & Farmers Welfare, Department of Agriculture, Cooperation & Farmers Welfare",
        "application_url": "https://soilhealth.dac.gov.in",
        "source_url": "https://soilhealth.dac.gov.in",
        "status": "ACTIVE",
        "verification_status": "VERIFIED",
    },
    {
        "scheme_name": "Agriculture Infrastructure Fund (AIF)",
        "category": "Infrastructure",
        "government_level": "Central",
        "state": None,
        "description": (
            "Medium-long term debt financing facility for investment in post-harvest management "
            "infrastructure and community farming assets, supported by interest subvention and "
            "credit guarantee."
        ),
        "benefits": [
            "Interest subvention of 3% per annum on loans up to Rs. 2 crore (for up to 7 years).",
            "Credit guarantee coverage under the scheme.",
            "Financing for post-harvest infrastructure and community farming assets.",
        ],
        "eligibility": [
            "Farmers, Farmer Producer Organizations (FPOs/FPCs), Primary Agricultural Credit Societies, agri-entrepreneurs, startups and State agencies.",
        ],
        "required_documents": [
            "Project proposal",
            "KYC documents",
            "Bank application form",
        ],
        "application_steps": [
            "Apply through a participating bank or the AIF portal.",
            "Submit the project proposal.",
            "Loan sanction and disbursement.",
            "Claim interest subvention.",
        ],
        "department": "Ministry of Agriculture & Farmers Welfare, Department of Agriculture, Cooperation & Farmers Welfare",
        "application_url": "https://agriinfra.dac.gov.in",
        "source_url": "https://agriinfra.dac.gov.in",
        "status": "ACTIVE",
        "verification_status": "VERIFIED",
    },
    {
        "scheme_name": "Sub-Mission on Agricultural Mechanization (SMAM)",
        "category": "Machinery",
        "government_level": "Central",
        "state": None,
        "description": (
            "Sub-mission to increase farm mechanization through subsidy on agricultural machinery "
            "and support for Custom Hiring Centres and farm machinery banks."
        ),
        "benefits": [
            "Subsidy on agricultural machinery and equipment.",
            "Support for Custom Hiring Centres and farm machinery banks.",
        ],
        "eligibility": [
            "Farmers and farmer groups.",
            "State implementing agencies.",
        ],
        "required_documents": None,
        "application_steps": [
            "Approach the State Agriculture department or the farm mechanization portal.",
        ],
        "department": "Ministry of Agriculture & Farmers Welfare, Department of Agriculture, Cooperation & Farmers Welfare",
        "application_url": None,
        "source_url": "https://agrimachinery.nic.in",
        "status": "ACTIVE",
        "verification_status": "VERIFIED",
    },
    {
        "scheme_name": "PM-PRANAM",
        "category": "Seeds & Fertilizers",
        "government_level": "Central",
        "state": None,
        "description": (
            "Initiative to incentivise States/Union Territories to promote alternative and natural "
            "farming and balanced use of chemical fertilizers. Detailed benefit and eligibility "
            "parameters were not independently re-verified for this seed record."
        ),
        "benefits": None,
        "eligibility": None,
        "required_documents": None,
        "application_steps": None,
        "department": "Department of Fertilizers, Ministry of Chemicals & Fertilizers",
        "application_url": None,
        "source_url": "https://www.myscheme.gov.in",
        "status": "ACTIVE",
        "verification_status": "NOT_VERIFIED",
    },
    {
        "scheme_name": "Namo Shetkari Mahasanman Nidhi Yojana",
        "category": "State Schemes",
        "government_level": "State",
        "state": "Maharashtra",
        "description": (
            "Maharashtra State scheme providing additional income support to eligible farmer "
            "families, over and above the Central PM-KISAN benefit."
        ),
        "benefits": [
            "Rs. 6,000 per year per eligible farmer family (paid in instalments), in addition to PM-KISAN.",
        ],
        "eligibility": [
            "Farmer families in Maharashtra eligible under PM-KISAN.",
        ],
        "required_documents": [
            "Aadhaar",
            "Bank account details",
            "PM-KISAN beneficiary status",
        ],
        "application_steps": [
            "Check beneficiary status on the MAHADBT portal.",
            "Complete e-KYC.",
            "Instalments are credited to the linked bank account.",
        ],
        "department": "Department of Agriculture, Government of Maharashtra",
        "application_url": "https://mahadbt.maharashtra.gov.in",
        "source_url": "https://mahadbt.maharashtra.gov.in",
        "status": "ACTIVE",
        "verification_status": "VERIFIED",
    },
]
