"""
Sentinel query tokens matching Rashkar FarmModel / SoilProfileModel column attributes
for non-invasive translation via RashkarAdaptedSession against CropNet's tables.
"""

class _QueryExpr:
    def __init__(self, col_name: str, other):
        self.col_name = col_name
        self.other = other

class _ColToken:
    def __init__(self, col_name: str):
        self.col_name = col_name
    def __eq__(self, other):
        return _QueryExpr(self.col_name, other)

class FarmModel:
    farm_id = _ColToken("farm_id")

class SoilProfileModel:
    farm_id = _ColToken("farm_id")
