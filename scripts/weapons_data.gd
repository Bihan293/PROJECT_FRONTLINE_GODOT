extends Node
class_name WeaponsData

const WEAPONS = {
	"ak": {
		"name": "АК-74",
		"damage": 28,
		"fire_rate": 0.11,
		"mag": 30,
		"reserve": 150,
		"spread": 0.015,
		"pellets": 1,
		"range": 120.0,
		"automatic": true,
		"recoil": 0.25
	},
	"shotgun": {
		"name": "ДРОБОВИК",
		"damage": 14,
		"fire_rate": 0.75,
		"mag": 8,
		"reserve": 48,
		"spread": 0.08,
		"pellets": 8,
		"range": 30.0,
		"automatic": false,
		"recoil": 0.65
	},
	"sniper": {
		"name": "СВ (СНАЙПЕР)",
		"damage": 95,
		"fire_rate": 1.15,
		"mag": 5,
		"reserve": 30,
		"spread": 0.002,
		"pellets": 1,
		"range": 220.0,
		"automatic": false,
		"recoil": 0.85
	},
	"pistol": {
		"name": "ПМ (ПИСТОЛЕТ)",
		"damage": 24,
		"fire_rate": 0.22,
		"mag": 12,
		"reserve": 72,
		"spread": 0.02,
		"pellets": 1,
		"range": 60.0,
		"automatic": false,
		"recoil": 0.2
	}
}
