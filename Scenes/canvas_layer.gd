class_name UILayer
extends CanvasLayer

@onready var gear_label: Label = $GearLabel
@onready var rpm_label: Label = $RPMLabel
@onready var rpm_pbar: ProgressBar = $RPMProgressBar

func update_engine_rpm_info(rpm: float) -> void:
	rpm_label.text = "RPM: %s" % str(int(rpm))
	rpm_pbar.value = rpm

func update_engine_gear_info(gear: String) -> void:
	gear_label.text = "Gear: %s" % gear
	
