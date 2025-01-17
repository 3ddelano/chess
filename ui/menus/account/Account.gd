extends Control

onready var flags: PoolStringArray = ["rainbow"]
onready var flagchoice: GridMenuButton = $choose/signup/flag
onready var status: InfoLabel = $H/InfoLabel  # not a StatusLabel
onready var loading = $LoadingAnimation

onready var tabs := {
	"signup": $choose/signup/usernamepass,
	"signin": $choose/signin/usernamepass,
}

var signed_in = false setget set_signed_in
var autologin = true

onready var tabcontainer = $choose


func set_signed_in(new):
	signed_in = new
	Events.emit_signal("set_signed_in", new)


func _ready():
	loading.show()
	tabcontainer.hide()
	PacketHandler.connect("signinresult", self, "_on_signin_result")
	PacketHandler.connect("signupresult", self, "_on_signup_result")
	PacketHandler.connect("connection_established", self, "attempt_autologin")
	flags.append_array(Utils.walk_dir("res://assets/flags", false, ["rainbow"]))
	for i in flags:  # add the items
		flagchoice.add_icon_item(load("res://assets/flags/%s.png" % i), i.replace("_", " "))
	flagchoice.selected = 0


func attempt_autologin():
	if Creds.data.name and Creds.data.password:
		PacketHandler.signin(Creds.data)
	else:
		reset("", false)


func signin():
	$choose/signin/signinbutton.disabled = true
	update_data(tabs.signin.username, tabs.signin.pw)
	PacketHandler.signin(Creds.data)


func _on_signin_result(result):
	var status_set = !autologin
	if autologin:
		autologin = false
		yield(get_tree().create_timer(.5), "timeout")
	$choose/signin/signinbutton.disabled = false
	if typeof(result) == TYPE_STRING:  # ew, error, get it away from me
		return reset(result, status_set)
	Creds.data.uuid = result.id  # server uses `id` instead of `uuid`...
	Creds.data.country = result.country
	on_successful()


func signup():
	$choose/signup/signupbutton.disabled = true
	Creds.data.country = flags[flagchoice.selected]
	update_data(tabs.signup.username, tabs.signup.pw)
	PacketHandler.signup(Creds.data)


func _on_signup_result(result: String):
	$choose/signup/signupbutton.disabled = false
	if "err:" in result:  # ew error go awway
		return reset(result)
	Creds.data.uuid = result
	on_successful()


func reset(reason: String, set_status := true):
	if set_status:
		status.set_text(reason, 0)
	Creds.reset()
	tabcontainer.show()
	loading.hide()
	set_signed_in(false)


func on_successful():
	Creds.save()
	loading.hide()
	status.set_text("Signed in to " + Creds.get("name"), 0)
	set_signed_in(true)  # yay
	$H/LogOut.show()
	tabcontainer.hide()


func update_data(username, pw):
	Creds.data.name = username.get_text()
	Creds.data.password = pw.get_text()
	Creds.save()


func _on_choose_tab_changed(tab: int):
	var new: VBoxContainer = $choose.get_children()[tab].get_node("usernamepass")
	var old = $choose.get_children()[1 if tab == 0 else 0].get_node("usernamepass")
	new.update_data(old.export_data())


func log_out():
	$H/LogOut.hide()
	reset("You are now logged out!")
