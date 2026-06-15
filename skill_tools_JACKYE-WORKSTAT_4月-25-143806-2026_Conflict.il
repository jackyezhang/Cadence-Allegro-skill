;==================================================
; Basic PCB SKILL Tools
;==================================================

;----------------------------------
; Auto Artwork
;----------------------------------
axlCmdRegister("Autoart" 'Autoart)

procedure(Autoart()
    let((oldartlayerlist deloldartlayerlist layerlist namelist num layername layeradd 
         posbdrillist drilllayerlist drillname layercheck)

        ; 1. 删除旧的 Artwork 定义
        oldartlayerlist = axlGetParam("artwork")->groupMembers
        deloldartlayerlist = list()
        foreach(layername oldartlayerlist
            push(axlGetParam(strcat("artwork:" layername)) deloldartlayerlist)
        )
        if(deloldartlayerlist then
            axlDeleteObject(deloldartlayerlist)
        )

        ; 2. 获取所有 Etch 层
        layerlist = axlGetParam("paramLayerGroup:ETCH")->groupMembers
        namelist = list("01_" "02_" "03_" "04_" "05_" "06_" "07_" "08_" "09_" "10_" 
                        "11_" "12_" "13_" "14_" "15_" "16_" "17_" "18_" "19_" "20_")
        
        num = 0
        foreach(etchLayer layerlist
            layername = strcat(nth(num namelist) etchLayer)
            layeradd = list("BOARD GEOMETRY/OUTLINE" 
                            strcat("ETCH/" etchLayer) 
                            strcat("VIA CLASS/" etchLayer) 
                            strcat("PIN/" etchLayer))
            
            Filmcreat(layername layeradd)
            num++
        )

        ; 3. 处理 Drill (钻孔层)
        drillname = "DRILL"
        drilllayerlist = list("BOARD GEOMETRY/OUTLINE" "BOARD GEOMETRY/DIMENSION")
        
        ; 自动寻找所有含 NCLEGEND 的层 (支持多层钻孔表)
        posbdrillist = axlGetParam("paramLayerGroup:MANUFACTURING")->groupMembers
        foreach(mLayer posbdrillist
            if(rexMatchp("NCLEGEND" mLayer) then
                push(strcat("MANUFACTURING/" mLayer) drilllayerlist)
            )
        )
        Filmcreat(drillname drilllayerlist)

        ; 4. 标准层定义 (Masks / Silk / Paste)
        Filmcreat("PASTEMASK_TOP"    '("BOARD GEOMETRY/OUTLINE" "PIN/PASTEMASK_TOP" "PACKAGE GEOMETRY/PASTEMASK_TOP"))
        Filmcreat("PASTEMASK_BOTTOM" '("BOARD GEOMETRY/OUTLINE" "PIN/PASTEMASK_BOTTOM" "PACKAGE GEOMETRY/PASTEMASK_BOTTOM"))
        
        Filmcreat("SOLDERMASK_TOP"   '("BOARD GEOMETRY/OUTLINE" "PIN/SOLDERMASK_TOP" "PACKAGE GEOMETRY/SOLDERMASK_TOP" 
                                       "BOARD GEOMETRY/SOLDERMASK_TOP" "VIA CLASS/SOLDERMASK_TOP"))
        Filmcreat("SOLDERMASK_BOTTOM" '("BOARD GEOMETRY/OUTLINE" "PIN/SOLDERMASK_BOTTOM" "PACKAGE GEOMETRY/SOLDERMASK_BOTTOM" 
                                        "BOARD GEOMETRY/SOLDERMASK_BOTTOM" "VIA CLASS/SOLDERMASK_BOTTOM"))
        
        Filmcreat("SILKSCREEN_TOP"    '("BOARD GEOMETRY/OUTLINE" "REF DES/SILKSCREEN_TOP" "PACKAGE GEOMETRY/SILKSCREEN_TOP" "BOARD GEOMETRY/SILKSCREEN_TOP"))
        Filmcreat("SILKSCREEN_BOTTOM" '("BOARD GEOMETRY/OUTLINE" "REF DES/SILKSCREEN_BOTTOM" "PACKAGE GEOMETRY/SILKSCREEN_BOTTOM" "BOARD GEOMETRY/SILKSCREEN_BOTTOM"))

        ; 辅助层 (Assembly/All)
        Filmcreat("ADT" '("BOARD GEOMETRY/OUTLINE" "REF DES/SILKSCREEN_TOP" "PIN/TOP" "PACKAGE GEOMETRY/SILKSCREEN_TOP"))
        Filmcreat("ADB" '("BOARD GEOMETRY/OUTLINE" "REF DES/SILKSCREEN_BOTTOM" "PIN/BOTTOM" "PACKAGE GEOMETRY/SILKSCREEN_BOTTOM"))
        Filmcreat("ALL" '("BOARD GEOMETRY/OUTLINE" "PACKAGE GEOMETRY/SILKSCREEN_TOP" "PACKAGE GEOMETRY/SILKSCREEN_BOTTOM" "PIN/TOP" "PIN/BOTTOM"))

        axlMsgPut("Artwork films created successfully for 17.4.")
    )
)

procedure( Filmcreat(FilmName artList)
    let((validLayers)
        ; 检查图层是否存在，避免 17.4 报错
        validLayers = nil
        foreach(lyr artList
            if(axlIsLayer(lyr) then push(lyr validLayers))
        )
        
        if(validLayers then
            axlVisibleDesign(nil)
            foreach(layer validLayers axlVisibleLayer(layer t))
            axlUIWRedraw(nil)
            
            ; axlDBCreateFilmRec 在 17.4 的参数建议设定：
            ; 参数说明: Name, Rotation, Undersize, Width, ShapeBound, MaxStep, PlotMode, CheckNonEtch, ...
            ; 这里保持基本兼容，但确保了关键标志位正确
            axlDBCreateFilmRec(FilmName 0 0 0 6000 100000 1 0 0 0 0 0 1 1)
        else
            axlMsgPut("Warning: Film %s has no valid layers, skipping." FilmName)
        )
    )
)

;----------------------------------
; Gerber Setup
;----------------------------------
axlCmdRegister("gerber_setup" 'gerber_setup)

(defun gerber_setup ()

 axlMsgPut("Open Gerber Setup")

 axlShell("artwork")

)

;----------------------------------
; Grid Setup
;----------------------------------
axlCmdRegister("quick_grids" 'quick_grids)

(defun quick_grids ()

 axlMsgPut("Set Grid 1 mil")

 axlShell("setgrid 1 1")

 axlUIConfirm("Grid set to 1 mil")

)
;###############################################################################
; show_library path
;###############################################################################

axlCmdRegister("show_library" 'show_library)

defun( show_library ()
    let((board comps libSet pathMsg psmPaths)
        
        board = axlDBGetDesign()
        
        if( !board then
            axlUIConfirm("Error: No design is currently open!")
            return(nil)
        )

        ; --- 2. 收集元件封装路径 ---
        comps = board->components
        libSet = nil 
        foreach(c comps
            ; 尝试从 symbol 获取路径
            let((dir)
                dir = c->symbol->libDir
                if(dir && dir != "" && !member(dir libSet) then
                    libSet = cons(dir libSet)
                )
            )
        )

        ; --- 3. 构造显示信息 ---
        pathMsg = "--- Components Library Paths ---\n"
        if(libSet then
            libSet = sort(libSet 'alphalessp)
            foreach(p libSet
                pathMsg = strcat(pathMsg "- " p "\n")
            )
        else
            pathMsg = strcat(pathMsg "(No external component paths linked)\n")
        )

        ; --- 4. 增加系统 psmpath 路径显示 (这才是你真正想看的库配置) ---
        pathMsg = strcat(pathMsg "\n--- System Footprint Search Paths (psmpath) ---\n")
        psmPaths = axlGetVariable("psmpath")
        if(listp(psmPaths) then
            foreach(path psmPaths
                pathMsg = strcat(pathMsg "- " path "\n")
            )
        else
            pathMsg = strcat(pathMsg "- " psmPaths "\n")
        )

        ; --- 5. 弹出报告窗口 ---
        display_library_report(pathMsg)
    )
)

; 辅助函数：弹出文本窗口（支持复制）
defun( display_library_report (msg)
    let((p_out tmpFile)
        tmpFile = "lib_report.txt"
        p_out = outfile(tmpFile "w")
        fprintf(p_out "%s" msg)
        close(p_out)
        
        axlUIViewFileCreate(tmpFile "Library Path Report" nil)
        
        ; 使用 deleteFile 替代 axlDeleteFile 避免 undefined 错误
        if(isFile(tmpFile) then deleteFile(tmpFile))
    )
)

; 辅助函数：使用报告窗口显示，方便复制路径
defun( display_library_report (msg)
    let((p_out)
        p_out = outfile("lib_paths_report.txt" "w")
        fprintf(p_out "%s" msg)
        close(p_out)
        axlUIViewFileCreate("lib_paths_report.txt" "Library Path Report" nil)
        ; 安全删除临时文件 (在 Allegro 中推荐使用 deleteFile)
        if(isFile("lib_paths_report.txt") then deleteFile("lib_paths_report.txt"))
    )
)
;------------------------------
; MM ↔ MIL convert
;----------------------------------
axlCmdRegister("conv" 'conv)
;###############################################################################
;单位转换工具
;###############################################################################
defun( conv ()
    let((time_info day month year date_str)
        ; 获取日期
        time_info = parseString(getCurrentTime())
        day   = nth(1 time_info)
        month = upperCase(car(time_info))
        year  = nth(3 time_info)
        date_str = strcat("Date: " day "-" month "-" year)

        ; 生成并显示表单
        create_conv_v3_form()
        display_conv_v3_form(date_str)
    )
)

; --- 创建表单文件 (增加 Groupbox 和更好的间距) ---
defun( create_conv_v3_form ()
    let((p)
        p = outfile("conv_v3.form" "w")
        fprintf(p "FILE_TYPE=FORM_DEFN VERSION=2\n")
        fprintf(p "FORM\n")
        fprintf(p "FIXED\n")
        fprintf(p "PORT 40 15\n") ; 调整窗口宽度
        fprintf(p "HEADER \"Conversion Tool Pro\"\n\n")
        fprintf(p "TILE\n")

        ; 增加一个视觉分组框
        fprintf(p "GROUP \"Unit Conversion\"\n")
        fprintf(p "GLOC 2 1\n")
        fprintf(p "GSIZE 36 8\n")
        fprintf(p "ENDGROUP\n\n")

        ; Mils 部分
        fprintf(p "TEXT \"Mils:\"\n")
        fprintf(p "TLOC 5 3\n")
        fprintf(p "ENDTEXT\n")
        fprintf(p "FIELD mils\n")
        fprintf(p "FLOC 12 3\n")
        fprintf(p "STRFILLIN 18 25\n")
        fprintf(p "ENDFIELD\n\n")

        ; MM 部分
        fprintf(p "TEXT \"mm:\"\n")
        fprintf(p "TLOC 5 6\n")
        fprintf(p "ENDTEXT\n")
        fprintf(p "FIELD mm\n")
        fprintf(p "FLOC 12 6\n")
        fprintf(p "STRFILLIN 18 25\n")
        fprintf(p "ENDFIELD\n\n")

        ; 按钮
        fprintf(p "FIELD Done\n")
        fprintf(p "FLOC 14 11\n")
        fprintf(p "MENUBUTTON \"Close\" 12 3\n")
        fprintf(p "ENDFIELD\n\n")

        fprintf(p "ENDTILE\n")
        fprintf(p "ENDFORM\n")
        close(p)
    )
)

; --- 显示表单 ---
defun( display_conv_v3_form (date_str)
    let((convform)
        ; 使用 gensym 确保表单 ID 唯一
        convform = axlFormCreate((gensym) "conv_v3.form" '(inner_beam) 'conv_v3_action t)
        axlFormDisplay(convform)
        
        ; 修正点：使用 axlUIWPrint 打印到 Form 的消息行 (底部状态栏)
        ; 这样不会触发 "too few arguments" 错误
        axlUIWPrint(convform date_str)
    )
)

; --- 动作处理 (增强数值验证) ---
defun( conv_v3_action (f)
    case(f->curField
        ("Done"
            axlFormClose(f)
            if(isFile("conv_v3.form") then axlDeleteFile("conv_v3.form"))
        )
        ("mils"
            let((val)
                val = f->curValue
                ; 允许输入数字和小数点
                if(rexMatchp("^[0-9.]+$" val) then
                    val = atof(val)
                    axlFormSetField(f "mm" sprintf(nil "%.4f" axlMKSConvert(val "MILS" "MM")))
                    axlUIWPrint(f sprintf(nil "Converted %.2f mils to mm" val))
                else
                    axlFormSetField(f "mils" "")
                    axlUIWPrint(f "Error: Please enter a valid number.")
                )
            )
        )
        ("mm"
            let((val)
                val = f->curValue
                if(rexMatchp("^[0-9.]+$" val) then
                    val = atof(val)
                    axlFormSetField(f "mils" sprintf(nil "%.2f" axlMKSConvert(val "MM" "MILS")))
                    axlUIWPrint(f sprintf(nil "Converted %.3f mm to mils" val))
                else
                    axlFormSetField(f "mm" "")
                    axlUIWPrint(f "Error: Please enter a valid number.")
                )
            )
        )
    )
)

;=========================================================
; XSection Stackup Display Tool                          #       
;=========================================================

axlCmdRegister("xs" 'LGS_XSection_Main ?cmdType "interactive")

defun( LGS_XSection_Main ()
  let( (stack_layer display l_layer nbLayer unit accuracy u
        pointStart Px Py totalThickness layerType layerName 
        f_Thickness s_Temp l_DBUnits fmt_spec)

    stack_layer = "MANUFACTURING/STACKUP_FIGURE"

    ; 1. 初始化环境
    unless(axlIsLayer(stack_layer) axlLayerCreateNonConductor(stack_layer))
    
    display = axlVisibleGet()
    axlVisibleDesign(nil)
    axlVisibleLayer(stack_layer t)

    ; 清理旧图形
    axlSetFindFilter(?enabled '(noall shapes text) ?onButtons '(noall shapes text))
    axlAddSelectAll()
    axlDeleteObject(axlGetSelSet())
    axlClearSelSet()

    ; 2. 获取单位与精度 (增加安全处理)
    l_DBUnits = axlDBGetDesignUnits()
    unit = car(l_DBUnits)
    ; 如果精度读取失败，默认设为 2
    accuracy = cadr(l_DBUnits) || 2
    
    ; 缩放因子 u
    u = case(unit ("millimeters" 1.0) ("mils" 40.0) ("microns" 1000.0) (t 1.0))

    l_layer = axlGetXSection()
    nbLayer = length(l_layer)
    
    axlMsgPut(">>> Generating Stackup...")

    ; 3. 交互选点
    pointStart = axlEnterPoint(?prompts "Pick location for X-Section Figure")
    unless(pointStart return(nil))
    Px = xCoord(pointStart)
    Py = yCoord(pointStart)

    totalThickness = 0.0

    ; 4. 构建格式化字符串：手动将变量拼入格式串，避开 %.*f
    fmt_spec = sprintf(nil "%%.%df %%s" accuracy)

    ; 5. 绘图循环
    for(p 1 nbLayer-2
        let( (layerData)
            layerData = nth(p l_layer)
            layerName = car(layerData)
            layerType = cadr(layerData)
            f_Thickness = atof(nth(3 layerData)) 

            ; 使用修复后的格式串
            s_Temp = sprintf(nil fmt_spec f_Thickness unit)
            fullLayerName = strcat(layerName " (" s_Temp ")")

            case(layerType
                ("DIELECTRIC"
                    LGS_DrawRect(Px+10*u Py-(p*6*u) 25*u 5*u stack_layer nil)
                    LGS_DrawText(fullLayerName list(Px+37*u Py-(p*6*u)+2*u) "left" stack_layer)
                    LGS_DrawText(nth(2 layerData) list(Px+22.5*u Py-(p*6*u)+2*u) "center" stack_layer)
                )
                ("PLANE"
                    LGS_DrawRect(Px+5*u Py-(p*6*u)+1.5*u 35*u 2*u stack_layer t)
                    LGS_DrawText(fullLayerName list(Px+45*u Py-(p*6*u)+1.5*u) "left" stack_layer)
                )
                ("CONDUCTOR"
                    LGS_DrawRect(Px+5*u Py-(p*6*u)+1.5*u 10*u 2*u stack_layer t)
                    LGS_DrawRect(Px+17*u Py-(p*6*u)+1.5*u 10*u 2*u stack_layer t)
                    LGS_DrawRect(Px+30*u Py-(p*6*u)+1.5*u 10*u 2*u stack_layer t)
                    LGS_DrawText(fullLayerName list(Px+45*u Py-(p*6*u)+1.5*u) "left" stack_layer)
                )
            )
            totalThickness = totalThickness + f_Thickness
        )
    )

    ; 6. 输出汇总信息 (同样应用修复后的格式串)
    LGS_DrawText(strcat("TOTAL THICKNESS: " sprintf(nil fmt_spec totalThickness unit) " (+/-10%)") 
                 list(Px+3*u Py-(nbLayer*6*u)) "left" stack_layer)

    axlVisibleSet(display)
    axlMsgPut(">>> X-Section Generated Successfully.")
  )
)

; --- 辅助绘图函数 ---

defun( LGS_DrawRect (x y w h layer fill)
    axlDBCreateRectangle(list(x:y (x+w):(y+h)) fill layer)
)

defun( LGS_DrawText (str pt just layer)
    let( (orient)
        orient = make_axlTextOrientation(?textBlock "4" ?rotation 0 ?mirrored nil ?justify just)
        axlDBCreateText(str pt orient layer nil)
    )
)

;----------------------------------
; Help
;----------------------------------
axlCmdRegister("Skill_help" 'Skill_help)

(defun Skill_help ()

 axlUIConfirm("PCB SKILL Tools by jackye design")

)


