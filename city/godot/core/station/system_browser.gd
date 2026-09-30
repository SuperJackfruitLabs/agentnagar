## How a page opens in the system browser. Every page the station computer
## opens (a sign-in, a Disconnect, the AgentPod console, Superpipeline)
## goes through `open`. The test runner puts in an opener that does
## nothing, so no test opens a real browser, whatever it forgot to script.
## It stands alone, with nothing to load, so the runner can reach it
## without loading the station computer.
class_name SystemBrowser
extends RefCounted

## Opens a page instead of the system browser when set; unset in play.
static var opener := Callable()


static func open(url: String) -> void:
	if opener.is_valid():
		opener.call(url)
	else:
		OS.shell_open(url)
