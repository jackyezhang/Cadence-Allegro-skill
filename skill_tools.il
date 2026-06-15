;==================================================
; Basic PCB SKILL Tools
;==================================================

;----------------------------------
; Auto Artwork
;----------------------------------
axlCmdRegister("Autoart" 'Autoart)

(defun Autoart ()

 axlMsgPut("Start Artwork Setup")

 axlShell("artwork")

 axlUIConfirm("Artwork command executed")

)

;----------------------------------
; Gerber Setup
;----------------------------------
axlCmdRegister("gerber_setup" 'gerber_setup)

(defun gerber_setup ()

 axlMsgPut("Open Gerber Setup")

 axlShell("artwork")

)

/* 
├──────────────────────────────────────────────────────────────────
│ 程序名称： Quick_Grids_174_Professional
│ 优化方案： 
│   1. 使用 Transaction 事务处理，消除 SPMHDB-449 提示
│   2. 采用 Form 事件值直取法，规避 Handle Closed 警告
│   3. 强制类型转换保护，防止 atof 崩溃
└──────────────────────────────────────────────────────────────────
*/ 

axlCmdRegister("quick_grids" 'Quick_Grids)

defun( Quick_Grids ()
    let((GridsZoomListmil GridsZoomListmm curdsn_unit mark) ; 增加 mark 变量
        GridsZoomListmil = '(1 5 10 25 50 100)
        GridsZoomListmm  = '(0.05 0.1 0.2 0.25 0.5 1.0)
        curdsn_unit = axlGetParam("paramDesign")->units
        
        ; 1. 开启事务，并获取事务句柄 mark
        mark = axlDBTransactionStart()
        
        ; 2. 执行 Form 相关操作
        GridSetForm_174_Final(GridsZoomListmil GridsZoomListmm curdsn_unit)
        
        ; 3. 提交事务，必须传入 mark。如果执行失败，也可以用 axlDBTransactionRollback(mark)
        if(mark then
            axlDBTransactionCommit(mark)
        )
    )
)

defun( GridSetForm_174_Final (list_mil list_mm units)
    let((GridFormfile formport a displaygrdform)
        GridFormfile = "QuickGridForm.form"
        formport = outfile(GridFormfile "w")
        
        fprintf(formport "FILE_TYPE=FORM_DEFN VERSION=2\n")
        fprintf(formport "FORM\nFIXED\n")
        fprintf(formport "PORT 45 6\n")
        fprintf(formport "HEADER \"Quick Grids (%s)\"\n" units)
        fprintf(formport "TILE\n")
        
        ; --- Mil 区域 ---
        fprintf(formport "TEXT \"Mils:\"\nTLOC 2 1\nENDTEXT\n")
        a = 8
        foreach(val list_mil
            fprintf(formport "FIELD mil_%L\n" val)
            fprintf(formport "FLOC %d 1\n" a)
            fprintf(formport "FGROUP \"g_grp\"\n")
            ; Checklist 后面跟着的值是给回调函数用的直接数据
            fprintf(formport "CHECKLIST \"%L\" \"g_grp\"\n" val)
            fprintf(formport "ENDFIELD\n")
            a = a + 6
        )
        
        ; --- Mm 区域 ---
        fprintf(formport "TEXT \"mm:\"\nTLOC 2 3\nENDTEXT\n")
        a = 8
        foreach(val list_mm
            let((f_id)
                f_id = buildString(parseString(lsprintf("%L" val) ".") "_")
                fprintf(formport "FIELD mm_%s\n" f_id)
                fprintf(formport "FLOC %d 3\n" a)
                fprintf(formport "FGROUP \"g_grp\"\n")
                fprintf(formport "CHECKLIST \"%L\" \"g_grp\"\n" val)
                fprintf(formport "ENDFIELD\n")
                a = a + 6
            )
        )
        
        fprintf(formport "ENDTILE\nENDFORM\n")
        close(formport)
        
        displaygrdform = axlFormCreate((gensym) GridFormfile '(se inner) 'Grid_act_174_Final t)
        axlFormDisplay(displaygrdform)
        deleteFile(GridFormfile)
    )
)

defun( Grid_act_174_Final (f_obj)
    let((f_field cur_units set_val val_raw val_str target_is_mil)
        f_field = f_obj->curField
        cur_units = axlGetParam("paramDesign")->units
        
        ; 核心改进：使用 f_obj->curValue 而不是 axlFormGetField
        ; 这样即使 Form handle 在某些毫秒级瞬间失效，数据已经传递给回调了
        val_str = f_obj->curValue
        
        ; 只有当 val_str 是有效的字符串（Checklist 的 Label）且被选中时才执行
        when(val_str && stringp(val_str)
            val_raw = atof(val_str)
            target_is_mil = rexMatchp("^mil_" f_field)
            
            set_val = if(target_is_mil then
                case(cur_units
                    ("mils"         val_raw)
                    ("millimeters"  val_raw * 0.0254)
                    ("inches"       val_raw / 1000.0)
                    ("centimeters"  val_raw * 0.00254)
                    ("microns"      val_raw * 25.4)
                    (t val_raw)
                )
            else
                case(cur_units
                    ("mils"         val_raw / 0.0254)
                    ("millimeters"  val_raw)
                    ("inches"       val_raw / 25.4)
                    ("centimeters"  val_raw / 10.0)
                    ("microns"      val_raw * 1000.0)
                    (t val_raw)
                )
            )

            SetCurGrid_174_Final(set_val)
            axlMsgPut("Grid updated: %g %s" set_val cur_units)
        )
    )
)

defun( SetCurGrid_174_Final (gridnum)
    let((gridObj)
        gridObj = axlDBGridGet("TOP")
        gridObj->name = 'all
        gridObj->xGrids = gridnum
        gridObj->yGrids = gridnum
        axlDBGridSet(gridObj)
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
/* 
├──────────────────────────────────────────────────────────────────
│ 程序名称： Quick_ColorS
│ 修正内容：设置颜色和pads 一样
└──────────────────────────────────────────────────────────────────
*/ 

axlCmdRegister("quick_colorset" 'Quick_ColorSet)

defun( Quick_ColorSet ()
    let((etchcolorslist)
        
        axlColorSet('all '( (14 210 255) (255 0 0) (231 32 236) (0 181 77) (166 16 255) (2 39 249) (180 97 140) (215 215 62) 
                            (190 192 233) (5 148 123) (179 179 185) (70 168 102) (222 168 3) (255 178 255) (124 171 186) (67 134 188) 
                            (215 0 253) (181 145 0) (147 166 166) (227 98 66) (191 0 191) (215 0 107) (0 255 0) (131 131 131) 
                            (156 134 114) (202 133 106) (252 78 90) (239 155 63) (215 215 0) (129 180 78) (0 221 0) (0 215 155)
                            (240 240 0) (189 66 255) (255 51 153) (217 217 217) (185 241 255) (233 191 255) (255 176 216) (189 255 189)
                            (202 189 170) (130 130 255) (117 255 217) (189 255 189) (151 203 255) (0 64 64) (0 128 0) (128 128 0) )
        )

        etchcolorslist = list(1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16)
        
        ; 执行设置
        Quick_ColorSetTr_174(etchcolorslist)
        
        ; 统一更新视图
        axlVisibleUpdate(t)
        axlMsgPut("Color setup for Pads completed successfully.")
    )
)

defun( Quick_ColorSetTr_174 (etchcolorslist)
    let((etchl etchlayers etchlnum cursetlayer lObj i setcolor)

        ; --- 1. 处理 ETCH 和 PIN 层 ---
        etchl = axlGetParam("paramLayerGroup:ETCH")->groupMembers
        ; 保持与原逻辑一致：底部层放在列表最后处理
        etchlayers = etchl 
        etchlnum = length(etchlayers)

        for(i 0 (etchlnum - 1)
            cursetlayer = nth(i etchlayers)
            setcolor = (nth(i etchcolorslist) || 1)

            ; 设置 PIN 和 ETCH
            foreach(class '("PIN" "ETCH")
                lObj = axlLayerGet(sprintf(nil "%s/%s" class cursetlayer))
                when(lObj
                    lObj->color = setcolor
                    axlLayerSet(lObj)
                )
            )
        )

        ; --- 2. 批量处理层组的函数 ---
        defun( _SafeGroupColor (groupName colorIdx)
            let((groupParam layers)
                groupParam = axlGetParam(sprintf(nil "paramLayerGroup:%s" groupName))
                when(groupParam
                    layers = groupParam->groupMembers
                    foreach(layerName layers
                        let((lPath lObj)
                            lPath = sprintf(nil "%s/%s" groupName layerName)
                            lObj = axlLayerGet(lPath)
                            when(lObj
                                lObj->color = colorIdx
                                axlLayerSet(lObj)
                            )
                        )
                    )
                )
            )
        )

        _SafeGroupColor("Drc Error Class" 33)
        _SafeGroupColor("Via Class" 11)
        _SafeGroupColor("Boundary" 42)
        _SafeGroupColor("Anti Etch" 14)
        _SafeGroupColor("Constraint Region" 21)
        _SafeGroupColor("Via Keepout" 29)
        _SafeGroupColor("Route Keepout" 13)

        ; --- 3. 处理固定层颜色 (修正 cadr) ---
        let((fixedLayers)
            fixedLayers = list(
                list("PACKAGE GEOMETRY/SILKSCREEN_TOP" 36)
                list("PACKAGE GEOMETRY/SILKSCREEN_BOTTOM" 20)
                list("PACKAGE GEOMETRY/ASSEMBLY_TOP" 29)
                list("PACKAGE GEOMETRY/ASSEMBLY_BOTTOM" 7)
                list("BOARD GEOMETRY/SILKSCREEN_TOP" 39)
                list("BOARD GEOMETRY/SILKSCREEN_BOTTOM" 29)
                list("BOARD GEOMETRY/OUTLINE" 36)
                list("REF DES/SILKSCREEN_TOP" 36)
                list("REF DES/SILKSCREEN_BOTTOM" 20)
                list("PIN/SOLDERMASK_TOP" 23)
                list("PIN/SOLDERMASK_BOTTOM" 3)
                list("ROUTE KEEPIN/ALL" 17)
            )

            foreach(item fixedLayers
                lObj = axlLayerGet(car(item))
                when(lObj
                    lObj->color = cadr(item) ; 使用 cadr 获取列表第二个元素
                    axlLayerSet(lObj)
                )
            )
        )
    )
)
;=========================================================
; PCB Manufacturing Notes Generator                      #
;=========================================================

axlCmdRegister("fn" 'LGS_FabNotes_Main ?cmdType "interactive")

defun( LGS_FabNotes_Main ()
    let( (stack_layer display pointStart Px Py u unit l_DBUnits text_block line_spacing notes_list)

        stack_layer = "MANUFACTURING/FAB_NOTES"
        text_block = "3"      ; 字体大小，通常 3 或 4 比较合适
        line_spacing = 6.0    ; 行间距系数

        ; 1. 初始化环境
        unless(axlIsLayer(stack_layer) axlLayerCreateNonConductor(stack_layer))
        
        display = axlVisibleGet()
        axlVisibleLayer(stack_layer t)

        ; 2. 获取单位缩放 (保持与叠层工具一致的逻辑)
        l_DBUnits = axlDBGetDesignUnits()
        unit = car(l_DBUnits)
        u = case(unit ("millimeters" 1.0) ("mils" 40.0) ("microns" 1000.0) (t 1.0))

        ; 3. 定义大厂标准制造说明模板
        ; 你可以在这里直接修改默认参数
        notes_list = list(
            "GENERAL MANUFACTURING NOTES:"
            "1. MATERIAL: FR-4, TG150 (MINIMUM), HIGH TG PREFERRED FOR LEAD-FREE PROCESS."
            "2. BOARD THICKNESS: SEE STACK-UP DIAGRAM, TOLERANCE +/- 10%."
            "3. SURFACE FINISH: ENIG (ELECTROLESS NICKEL IMMERSION GOLD), AU > 0.05um, NI 3-5um."
            "4. SOLDER MASK: GREEN, MATTE FINISH, BOTH SIDES."
            "5. SILKSCREEN: WHITE, BOTH SIDES. MUST NOT COVER SOLDERABLE PADS."
            "6. COPPER WEIGHT: FINISHED OUTER LAYERS 1 OZ, INNER LAYERS 1 OZ (MIN)."
            "7. MINIMUM TRACK WIDTH/SPACING: PER DESIGN DATA."
            "8. DRILLING: ALL HOLES SIZE ARE FINISHED HOLE SIZE (FHS). TOLERANCE +/- 0.05mm."
            "9. VIA PROCESS: TENTING SOLDER MASK OVER VIAS BOTH SIDES."
            "10. IMPEDANCE CONTROL: SEE IMPEDANCE TABLE IF APPLICABLE (+/- 10%)."
            "11. ELECTRICAL TEST: 100% NETLIST CONTINUITY & ISOLATION TEST REQUIRED."
            "12. COMPLIANCE: ALL MATERIALS MUST BE RoHS COMPLIANT."
            "13. WORKMANSHIP: PER IPC-A-600 CLASS 2 (OR CLASS 3 IF SPECIFIED)."
        )

        ; 4. 交互选点
        axlMsgPut(">>> Pick location for Fabrication Notes.")
        pointStart = axlEnterPoint(?prompts "Pick location for Fabrication Notes")
        
        if(pointStart then
            Px = xCoord(pointStart)
            Py = yCoord(pointStart)

            ; 5. 循环绘制文字
            for(i 0 length(notes_list)-1
                let( (current_text current_pos)
                    current_text = nth(i notes_list)
                    ; 计算每行位置，y 坐标向下偏移
                    current_pos = list(Px Py-(i * line_spacing * u))
                    
                    LGS_DrawFabText(current_text current_pos text_block stack_layer)
                )
            )
            axlMsgPut(">>> Fabrication Notes Generated.")
        else
            axlMsgPut(">>> Command Canceled.")
        )
        
        axlVisibleSet(display)
    )
)

; --- 辅助绘图函数 ---

defun( LGS_DrawFabText (str pt block layer)
    let( (orient)
        ; 使用左对齐，不镜像
        orient = make_axlTextOrientation(?textBlock block ?rotation 0 ?mirrored nil ?justify "left")
        axlDBCreateText(str pt orient layer nil)
    )
)
;==========================================================
; 修正版: Extract_iBOM_Full.il
; 修复了 units 列表报错 和 axlDBGetProp 未定义函数错误
;==========================================================

axlCmdRegister("ibom" "Extract_iBOM_Full")

procedure( Extract_iBOM_Full()
    let( (file_port pcb_name json_name all_syms first_comp first_draw val pkg_name bBox units_info)
        
        pcb_name = axlCurrentDesign()
        json_name = strcat(pcb_name ".json")
        file_port = outfile(json_name "w")
        
        if(file_port then
            fprintf(file_port "{\n")
            
            ; --- 0. Metadata (元数据) ---
            bBox = axlDBGetDesign()->bBox
            units_info = axlDBGetDesignUnits()
            fprintf(file_port "  \"metadata\": {\n")
            fprintf(file_port "    \"title\": \"%s\",\n" pcb_name)
            fprintf(file_port "    \"units\": \"%s\",\n" car(units_info)) ; 修复：取列表第一个元素
            fprintf(file_port "    \"bbox\": [[%.3f, %.3f], [%.3f, %.3f]]\n" 
                    float(caar(bBox)) float(cadar(bBox)) float(caadr(bBox)) float(cadadr(bBox)))
            fprintf(file_port "  },\n")

            ; --- 1. 元器件数据 ---
            fprintf(file_port "  \"components\": [\n")
            all_syms = axlDBGetDesign()->symbols
            first_comp = t
            foreach(sym all_syms
                when(sym->type == "PACKAGE" && sym->refdes != "" && sym->refdes != nil
                    ; 修复：使用符号属性简写获取 VALUE
                    val = (sym->prop->VALUE || "N/A")
                    pkg_name = (sym->definition->name || "UNK")
                    
                    unless(first_comp fprintf(file_port ",\n"))
                    first_comp = nil
                    
                    fprintf(file_port "    {\n")
                    fprintf(file_port "      \"ref\": \"%s\",\n" sym->refdes)
                    fprintf(file_port "      \"package\": \"%s\",\n" pkg_name)
                    fprintf(file_port "      \"location\": [%.3f, %.3f],\n" float(car(sym->xy)) float(cadr(sym->xy)))
                    fprintf(file_port "      \"rotation\": %.1f,\n" float(sym->rotation || 0.0))
                    fprintf(file_port "      \"side\": \"%s\",\n" if(sym->isMirror "bottom" "top"))
                    fprintf(file_port "      \"value\": \"%s\",\n" val)
                    
                    ; --- Pads 数据 ---
                    fprintf(file_port "      \"pads\": [\n")
                    let((first_pad p_xy p_size p_shape p_pin_def)
                        first_pad = t
                        foreach(pin sym->pins
                            unless(first_pad fprintf(file_port ",\n"))
                            first_pad = nil
                            
                            p_xy = pin->xy
                            p_size = list(abs(caadr(pin->bBox) - caar(pin->bBox)) abs(cadadr(pin->bBox) - cadar(pin->bBox)))
                            
                            p_pin_def = pin->definition
                            p_shape = "rect"
                            cond(
                                (p_pin_def->type == "CIRCLE" p_shape = "circle")
                                (p_pin_def->type == "OBLONG" p_shape = "oblong")
                                (p_pin_def->type == "RECT" p_shape = "rect")
                            )
                            
                            fprintf(file_port "        {\n")
                            fprintf(file_port "          \"pin\": \"%s\",\n" (pin->number || ""))
                            fprintf(file_port "          \"pos\": [%.3f, %.3f],\n" float(car(p_xy)) float(cadr(p_xy)))
                            fprintf(file_port "          \"size\": [%.3f, %.3f],\n" float(car(p_size)) float(cadr(p_size)))
                            fprintf(file_port "          \"shape\": \"%s\"\n" p_shape)
                            fprintf(file_port "        }")
                        )
                    )
                    fprintf(file_port "\n      ]\n")
                    fprintf(file_port "    }")
                )
            )
            fprintf(file_port "\n  ],\n")

            ; --- 2. 丝印图形数据 ---
            fprintf(file_port "  \"drawings\": [\n")
            first_draw = t
            foreach(sym all_syms
                when(sym->type == "PACKAGE"
                    foreach(child sym->children
                        when(index(child->layer "SILKSCREEN")
                            cond(
                                (child->objType == "line"
                                    unless(first_draw fprintf(file_port ",\n"))
                                    first_draw = nil
                                    fprintf(file_port "    {\"type\": \"line\", \"start\": [%.3f, %.3f], \"end\": [%.3f, %.3f], \"side\": \"%s\"}" 
                                        float(car(child->start)) float(cadr(child->start)) 
                                        float(car(child->end)) float(cadr(child->end))
                                        if(sym->isMirror "bottom" "top"))
                                )
                                (child->objType == "arc"
                                    unless(first_draw fprintf(file_port ",\n"))
                                    first_draw = nil
                                    fprintf(file_port "    {\"type\": \"arc\", \"center\": [%.3f, %.3f], \"radius\": %.3f, \"start_angle\": %.2f, \"end_angle\": %.2f, \"side\": \"%s\"}" 
                                        float(car(child->xy)) float(cadr(child->xy))
                                        float(child->radius || 0.0) float(child->startAngle || 0.0) float(child->endAngle || 360.0)
                                        if(sym->isMirror "bottom" "top"))
                                )
                            )
                        )
                    )
                )
            )
            fprintf(file_port "\n  ],\n")

            ; --- 3. 板框 ---
            fprintf(file_port "  \"edges\": [\n")
            let( (layer_items first_edge start_pt end_pt)
                layer_items = axlDBGetShapes("BOARD GEOMETRY/DESIGN_OUTLINE")
                unless(layer_items, layer_items = axlDBGetShapes("BOARD GEOMETRY/OUTLINE"))
                unless(layer_items, layer_items = axlDBGetLines("BOARD GEOMETRY/DESIGN_OUTLINE"))
                
                first_edge = t
                foreach(item layer_items
                    let((segs)
                        segs = if(item->objType == "shape" item->segments list(item))
                        foreach(seg segs
                            start_pt = seg->start end_pt = seg->end
                            when(start_pt && end_pt
                                unless(first_edge fprintf(file_port ",\n"))
                                first_edge = nil
                                fprintf(file_port "    {\"start\": [%.3f, %.3f], \"end\": [%.3f, %.3f]}" 
                                    float(car(start_pt)) float(cadr(start_pt)) float(car(end_pt)) float(cadr(end_pt)))
                            )
                        )
                    )
                )
            )
            fprintf(file_port "\n  ]\n")
            
            fprintf(file_port "}\n")
            close(file_port)
            axlMsgPut("SUCCESS: JSON exported to %s" json_name)
        )
    )
)
;----------------------------------
; Help
;----------------------------------
axlCmdRegister("Skill_help" 'Skill_help)

(defun Skill_help ()

 axlUIConfirm("PCB SKILL Tools by jackye design")

)