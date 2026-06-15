printf("Loading PCB SKILL Tools...\n")

base = "D:/Cadence/SPB_Data/pcbenv/skill_tools/"

load(strcat(base "men-toolbar.il"))

load(strcat(base "skill_tools.il"))
load(strcat(base "skill_check.il"))
load(strcat(base "skill_change.il"))
load(strcat(base "skill_export.il"))
load(strcat(base "skill_create.il"))

printf("PCB SKILL Tools Loaded Successfully\n")