extends RefCounted

class_name TemporaryBuff

var remainingDuration: float
var property: String
var amount: float
var origin: String

func duplicate() -> TemporaryBuff:
	var tb = TemporaryBuff.new()
	tb.remainingDuration = remainingDuration
	tb.property = property
	tb.amount = amount
	tb.origin = origin
	return tb
