## The Chat app's record of a console session: its events in `seq` order,
## each once, and the permission answers the hub recorded. It draws
## nothing; `ChatRows` draws what it holds.
##
## A refusal (an event with `seq` 0, outside the hub's order) is kept where
## it arrived, after whatever was newest then, so drawing the transcript
## again puts it back in the same place.
class_name ChatTranscript
extends RefCounted

## What taking an event did: nothing (a repeat), added it at the end (the
## newest, or a refusal), or put it before newer ones (a late event, after
## which the transcript is drawn again).
enum Taken { REPEAT, NEWEST, NOTICE, LATE }

## Every event, in the order shown.
var events: Array = []
## Each answered permission request's `permission-answer` payload, by the
## request's seq.
var answers := {}

## The seqs taken.
var _seen := {}
var _newest := 0


## Takes one event, once; see `Taken`.
func take(acp_event: Dictionary) -> Taken:
	var seq := int(acp_event.get("seq", 0))
	if seq == 0:
		events.append(acp_event)
		return Taken.NOTICE
	if _seen.has(seq):
		return Taken.REPEAT
	_seen[seq] = true
	if str(acp_event.get("type", "")) == "permission-answer":
		var payload = acp_event.get("payload")
		if payload is Dictionary:
			answers[int(payload.get("requestSeq", 0))] = payload
	if seq > _newest:
		_newest = seq
		events.append(acp_event)
		return Taken.NEWEST
	var at := events.size()
	for i in events.size():
		if int(events[i].get("seq", 0)) > seq:
			at = i
			break
	events.insert(at, acp_event)
	return Taken.LATE


## The answer recorded for the request at `request_seq`, or null.
func answer_to(request_seq: int) -> Variant:
	return answers.get(request_seq)


func clear() -> void:
	events.clear()
	answers.clear()
	_seen.clear()
	_newest = 0
