class_name SlimerotRoster
extends RefCounted

# Slimerot's canonical 24 base entries. Stats are derived from threshold N.
const ROWS := [
	["tung_tung_tung_sahur", "Tung Tung Tung Sahur", 1, 2],
	["brr_brr_patapim", "Brr Brr Patapim", 1, 12],
	["chimpanzini_bananini", "Chimpanzini Bananini", 1, 75],
	["ballerina_cappuccina", "Ballerina Cappuccina", 2, 20],
	["cappuccino_assassino", "Cappuccino Assassino", 2, 120],
	["tralalero_tralala", "Tralalero Tralala", 2, 800],
	["lirili_larila", "Lirili Larila", 3, 100],
	["frigo_camelo", "Frigo Camelo", 3, 700],
	["bombardiro_crocodilo", "Bombardiro Crocodilo", 3, 4000],
	["trippi_troppi", "Trippi Troppi", 4, 400],
	["bombombini_gusini", "Bombombini Gusini", 4, 2500],
	["girafa_celestre", "Girafa Celestre", 4, 15000],
	["orangutini_ananasini", "Orangutini Ananasini", 5, 1500],
	["bobritto_bandito", "Bobritto Bandito", 5, 10000],
	["la_vaca_saturno_saturnita", "La Vaca Saturno Saturnita", 5, 60000],
	["cacto_hipopotamo", "Cacto Hipopotamo", 6, 6000],
	["glorbo_fruttodrillo", "Glorbo Fruttodrillo", 6, 40000],
	["talpa_di_ferro", "Talpa Di Ferro", 6, 250000],
	["blueberrinni_octopussini", "Blueberrinni Octopussini", 7, 20000],
	["chef_crabracadabra", "Chef Crabracadabra", 7, 150000],
	["celestial_tralalero", "Celestial Tralalero", 7, 900000],
	["cosmic_tung_tung_sahur", "Cosmic Tung Tung Sahur", 8, 80000],
	["nuclear_bombardiro", "Nuclear Bombardiro", 8, 600000],
	["brainrot_singularity", "Brainrot Singularity", 8, 4000000],
]

static func damage(threshold: int) -> int:
	return roundi(6.0 * pow(threshold, 0.32))

static func sell_value(threshold: int) -> int:
	return maxi(1, roundi(4.0 * pow(threshold, 0.45)))
