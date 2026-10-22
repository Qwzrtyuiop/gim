extends RefCounted


static func gas_price(player_state) -> int:
	return max(0, player_state.gas_price)


static func gas_price_text(player_state) -> String:
	return "PhP %d.00" % gas_price(player_state)


static func gas_price_change_text(player_state) -> String:
	var absolute_delta: int = player_state.gas_price_delta
	if absolute_delta < 0:
		absolute_delta *= -1
	if player_state.gas_price_delta > 0:
		return "+PhP %d.00" % absolute_delta
	if player_state.gas_price_delta < 0:
		return "-PhP %d.00" % absolute_delta
	return "PhP 0.00"


static func gas_price_yesterday_percent_text(player_state) -> String:
	var yesterday_price: float = maxf(1.0, float(player_state.previous_gas_price))
	var raw_percent_change: float = (float(gas_price(player_state)) - yesterday_price) / yesterday_price * 100.0
	var percent_change: float = clampf(raw_percent_change, -player_state.DAILY_GAS_PRICE_MAX_PERCENT_CHANGE, player_state.DAILY_GAS_PRICE_MAX_PERCENT_CHANGE)
	if percent_change > 0.0:
		return "+%.1f%%" % percent_change
	if percent_change < 0.0:
		return "%.1f%%" % percent_change
	return "0.0%"


static func set_gas_price(player_state, price: int) -> void:
	player_state.gas_price = max(0, price)
	player_state.gas_price_delta = player_state.gas_price - player_state.previous_gas_price
	player_state.save_progress()


static func current_weather(player_state) -> String:
	return stage_weather(player_state, player_state.get_current_time_of_day())


static func current_weather_text(player_state) -> String:
	return weather_text(player_state, current_weather(player_state))


static func today_weather_forecast(player_state) -> String:
	return weather_forecast_for_day(player_state, player_state.get_current_day())


static func tomorrow_weather_forecast(player_state) -> String:
	return weather_forecast_for_day(player_state, player_state.get_current_day() + 1)


static func weather_forecast_for_day(player_state, day_number: int) -> String:
	var safe_day: int = maxi(1, day_number)
	ensure_weather_forecast_for_day(player_state, safe_day)
	return normalize_weather(player_state, str(player_state.weather_forecasts.get(safe_day, player_state.DEFAULT_WEATHER)))


static func stage_weather(player_state, day_time: String = "") -> String:
	var safe_day: int = player_state.get_current_day()
	if safe_day < player_state.WEATHER_SYSTEM_START_DAY:
		return player_state.DEFAULT_WEATHER

	ensure_weather_forecast_for_day(player_state, safe_day)
	var safe_time: String = str(day_time).strip_edges().to_lower()
	if not player_state.STAGE_TIMES.has(safe_time):
		safe_time = player_state.get_current_time_of_day()
	var phase_key: String = weather_phase_key(safe_day, safe_time)
	if not player_state.weather_phase_cache.has(phase_key):
		player_state.weather_phase_cache[phase_key] = roll_weather_for_phase(player_state, weather_forecast_for_day(player_state, safe_day), safe_time)
		player_state.save_progress()

	player_state.current_weather = normalize_weather(player_state, str(player_state.weather_phase_cache.get(phase_key, player_state.DEFAULT_WEATHER)))
	return player_state.current_weather


static func weather_text(player_state, weather_value: String) -> String:
	var safe_weather: String = normalize_weather(player_state, weather_value)
	if safe_weather == player_state.WEATHER_CLOUDY:
		return "Cloudy"
	if safe_weather == player_state.WEATHER_RAIN:
		return "Rain"
	if safe_weather == player_state.WEATHER_HEAVY_RAIN:
		return "Heavy Rain"
	return "Clear"


static func daily_news_text(player_state) -> String:
	return "TODAY'S NEWS\nGas Price:   %s      %s\nChange:   %s\n\nWeather forecast\nToday:   %s\nTomorrow:   %s" % [
		gas_price_text(player_state),
		gas_price_yesterday_percent_text(player_state),
		gas_price_change_text(player_state),
		weather_text(player_state, today_weather_forecast(player_state)),
		weather_text(player_state, tomorrow_weather_forecast(player_state)),
	]


static func ensure_daily_conditions_for_current_day(player_state) -> void:
	var safe_day: int = player_state.get_current_day()
	var needs_save: bool = false
	if player_state.daily_conditions_day != safe_day:
		roll_daily_conditions_for_day(player_state, safe_day)
		needs_save = true
	if ensure_weather_forecast_for_day(player_state, safe_day):
		needs_save = true
	if ensure_weather_forecast_for_day(player_state, safe_day + 1):
		needs_save = true
	if needs_save:
		player_state.save_progress()


static func roll_daily_conditions_for_day(player_state, day_number: int) -> void:
	var safe_day: int = maxi(1, day_number)
	player_state.previous_gas_price = player_state.gas_price
	player_state.daily_conditions_day = safe_day
	if safe_day > 1:
		var percent_delta: float = player_state.rng.randf_range(-player_state.DAILY_GAS_PRICE_MAX_PERCENT_CHANGE, player_state.DAILY_GAS_PRICE_MAX_PERCENT_CHANGE)
		var previous_price_float: float = maxf(1.0, float(player_state.previous_gas_price))
		var raw_price: int = roundi(previous_price_float * (1.0 + percent_delta / 100.0))
		var min_price: int = ceili(previous_price_float * (1.0 - player_state.DAILY_GAS_PRICE_MAX_PERCENT_CHANGE / 100.0))
		var max_price: int = floori(previous_price_float * (1.0 + player_state.DAILY_GAS_PRICE_MAX_PERCENT_CHANGE / 100.0))
		player_state.gas_price = clampi(raw_price, min_price, maxi(min_price, max_price))
	else:
		player_state.gas_price = player_state.DEFAULT_GAS_PRICE
	player_state.gas_price_delta = player_state.gas_price - player_state.previous_gas_price
	ensure_weather_forecast_for_day(player_state, safe_day)
	ensure_weather_forecast_for_day(player_state, safe_day + 1)
	player_state.current_weather = normalize_weather(player_state, str(player_state.weather_forecasts.get(safe_day, player_state.DEFAULT_WEATHER)))


static func ensure_weather_forecast_for_day(player_state, day_number: int) -> bool:
	var safe_day: int = maxi(1, day_number)
	if player_state.weather_forecasts.has(safe_day):
		player_state.weather_forecasts[safe_day] = normalize_weather(player_state, str(player_state.weather_forecasts.get(safe_day, player_state.DEFAULT_WEATHER)))
		return false

	if safe_day < player_state.WEATHER_SYSTEM_START_DAY:
		player_state.weather_forecasts[safe_day] = player_state.DEFAULT_WEATHER
	else:
		player_state.weather_forecasts[safe_day] = roll_weather_forecast(player_state)
	return true


static func roll_weather_forecast(player_state) -> String:
	var roll: int = player_state.rng.randi_range(1, 100)
	if roll <= 45:
		return player_state.DEFAULT_WEATHER
	if roll <= 70:
		return player_state.WEATHER_CLOUDY
	if roll <= 93:
		return player_state.WEATHER_RAIN
	return player_state.WEATHER_HEAVY_RAIN


static func roll_weather_for_phase(player_state, day_forecast: String, day_time: String) -> String:
	var safe_forecast: String = normalize_weather(player_state, day_forecast)
	var safe_time: String = day_time
	if not player_state.STAGE_TIMES.has(safe_time):
		safe_time = "morning"
	if safe_time == "night":
		return roll_night_weather_for_forecast(player_state, safe_forecast)

	var roll: int = player_state.rng.randi_range(1, 100)
	if safe_forecast == player_state.WEATHER_CLOUDY:
		if roll <= 70:
			return player_state.WEATHER_CLOUDY
		return player_state.DEFAULT_WEATHER
	if safe_forecast == player_state.WEATHER_RAIN:
		if roll <= 68:
			return player_state.WEATHER_RAIN
		return player_state.WEATHER_CLOUDY
	if safe_forecast == player_state.WEATHER_HEAVY_RAIN:
		if roll <= 52:
			return player_state.WEATHER_HEAVY_RAIN
		if roll <= 87:
			return player_state.WEATHER_RAIN
		return player_state.WEATHER_CLOUDY
	if roll <= 82:
		return player_state.DEFAULT_WEATHER
	return player_state.WEATHER_CLOUDY


static func roll_night_weather_for_forecast(player_state, day_forecast: String) -> String:
	var safe_forecast: String = normalize_weather(player_state, day_forecast)
	var roll: int = player_state.rng.randi_range(1, 100)
	if safe_forecast == player_state.WEATHER_CLOUDY:
		if roll <= 18:
			return player_state.WEATHER_RAIN
		return player_state.DEFAULT_WEATHER
	if safe_forecast == player_state.WEATHER_RAIN:
		if roll <= 82:
			return player_state.WEATHER_RAIN
		return player_state.WEATHER_HEAVY_RAIN
	if safe_forecast == player_state.WEATHER_HEAVY_RAIN:
		if roll <= 62:
			return player_state.WEATHER_HEAVY_RAIN
		return player_state.WEATHER_RAIN
	return player_state.DEFAULT_WEATHER


static func weather_phase_key(day_number: int, day_time: String) -> String:
	return "%d:%s" % [maxi(1, day_number), day_time]


static func normalize_weather(player_state, weather_value: String) -> String:
	var safe_weather: String = str(weather_value).strip_edges().to_lower()
	if safe_weather == "heavy-rain" or safe_weather == "heavy_rain":
		safe_weather = player_state.WEATHER_HEAVY_RAIN
	if player_state.WEATHER_TYPES.has(safe_weather):
		return safe_weather
	return player_state.DEFAULT_WEATHER


static func reset_weather_state(player_state) -> void:
	player_state.gas_price = player_state.DEFAULT_GAS_PRICE
	player_state.gas_price_delta = 0
	player_state.previous_gas_price = player_state.DEFAULT_GAS_PRICE
	player_state.current_weather = player_state.DEFAULT_WEATHER
	player_state.weather_forecasts.clear()
	player_state.weather_forecasts[1] = player_state.DEFAULT_WEATHER
	player_state.weather_phase_cache.clear()
	player_state.daily_conditions_day = 1
