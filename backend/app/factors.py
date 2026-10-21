"""Emission factors: kg CO2e per unit. Approximate averages, good enough for a
student project. Tweak the numbers here; nothing else needs to change."""

UNITS = {
    "transport": "km",
    "electricity": "kWh",
    "water": "litres",
    "waste": "kg",
}

FACTORS = {
    "transport": {
        "walk": 0.0,
        "bicycle": 0.0,
        "motorbike": 0.103,
        "car_petrol": 0.192,
        "car_diesel": 0.171,
        "car_electric": 0.050,
        "bus": 0.089,
        "train": 0.041,
        "metro": 0.030,
        "flight": 0.150,
    },
    "electricity": {
        "grid": 0.71,     # approx. India grid average, kg CO2 per kWh
        "solar": 0.0,
    },
    "water": {
        "tap": 0.000344,  # supply + treatment, kg CO2 per litre
        "rainwater": 0.0,
    },
    "waste": {
        "landfill": 0.45,
        "recycling": 0.021,
        "compost": 0.010,
        "reuse": 0.0,
    },
}


def is_valid(category, type_):
    return category in FACTORS and type_ in FACTORS[category]


def calculate_co2(category, type_, quantity):
    return round(quantity * FACTORS[category][type_], 4)
