defun(toolmenucreate (arg)

 SKILLToolsMenu = '(
   (popup "PCB Skill Tools")

   ("Auto Artwork" "Autoart")
   ("Gerber Setup" "gerber_setup")
   ("Set Grid" "quick_grids")
   ("Convert mm-mil" "conv")
   ("Show_library_Path" "show_library")
   ("Quick_colorset" "Quick_ColorSet")
   ("Quick_stackup" "xs")
   ("Fabrication Notes" "fn")
   (separator)

   (popup "Check Tools")

     ("Delete Dangling" "ddl")
     ("Check 90 Trace" "lgs_check")
     ("Check Cross Plane" "check_cross")
     ("check_no_refdes" "Check_No_Refdes")
     ("check_pin_no_solder" "check_solder")
     ("check_single_net" "check_single")
     ("check_text_overpad" "check_text")
     ("check_text_overvia" "check_over_via")
   (end)

   (separator)

   (popup "Change Tools")

     ("Change Width" "cwidth")
     ("Replace Via" "replace_via")
     ("Align Component" "al")

   (end)

   (separator)

   (popup "Export Tools")

     ("Export Gerber" "export_gerber")
     ("Export_bom" "export_bom")
     ("Export_Pick_Place" "export_place")
     ("Extract_iBOM" "ibom")

   (end)

   (separator)

   (popup "Symbol Tools")

     
     ("auto_symbol" "auto_sym")
     ("check_symbol" "check_pads")
     ("Rename Pin Batch" "rpn")

   (end)

   (separator)

   ("Skill tools Help" "Skill_help")
 )

 let((q)
   q = axlUIMenuFind(nil -1)
   axlUIMenuInsert(q SKILLToolsMenu)
 )

)

axlTriggerSet('menu 'toolmenucreate)