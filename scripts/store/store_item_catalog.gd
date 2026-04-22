extends RefCounted

const ITEMS := [
	{
		"id": "engine_tune",
		"name": "Engine Tune",
		"description": "increase top speed and acceleration",
		"cost": 250,
		"cost_step": 70,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "brake_kit",
		"name": "Brake Kit",
		"description": "improve braking power",
		"cost": 200,
		"cost_step": 55,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "fuel_efficiency",
		"name": "Fuel Efficiency",
		"description": "less gas consumption and slightly cheaper boost",
		"cost": 150,
		"cost_step": 60,
		"type": "upgrade",
		"max_level": 5,
	},
	{
		"id": "yosi",
		"name": "Warlboro Blue",
		"description": "Restore energy. May cause negative effects",
		"cost": 25,
		"type": "energy",
		"energy": 2,
	},
	
	{
		"id": "energy_snack",
		"name": "Energy Bar",
		"description": "Restore 2 energy",
		"cost": 50,
		"type": "energy",
		"energy": 2,
	},
	{
		"id": "full_meal",
		"name": "Budget Meal",
		"description": "Restore 5 energy",
		"cost": 120,
		"type": "energy",
		"energy": 5,
	},
	{
		"id": "gas_can",
		"name": "Gas Can",
		"description": "Add 10% gas",
		"type": "gas",
		"gas": 10.0,
	},
]
