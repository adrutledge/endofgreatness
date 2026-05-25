class_name Helpers
extends RefCounted


static func fmt_money(amount: int) -> String:
	if amount >= 1000000:
		var m = amount / 1000000
		var frac = (amount % 1000000) / 100000
		return str(m) + "." + str(frac) + "M CSB"
	elif amount >= 1000:
		var k = amount / 1000
		var frac = (amount % 1000) / 100
		return str(k) + "." + str(frac) + "K CSB"
	return str(amount) + " CSB"
