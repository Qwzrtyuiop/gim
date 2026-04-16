extends RefCounted


static func choose(rng: RandomNumberGenerator, options: Array) -> String:
	return options[rng.randi_range(0, options.size() - 1)]


static func choose_weighted(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var total_weight := 0.0
	for weight in weights.values():
		total_weight += float(weight)

	var roll := rng.randf_range(0.0, total_weight)
	var running_total := 0.0
	for key in weights.keys():
		running_total += float(weights[key])
		if roll <= running_total:
			return key

	return weights.keys()[0]
