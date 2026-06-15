;#######################################################################
;#                                                                     #
;#           Function: Delete Dangling Lines (自动删除悬空线)           #
;#           Compatibility: Allegro 17.2, 17.4, 22.x                   #
;#                                                                     #
;#######################################################################
axlCmdRegister("ddl" 'DeleteDanglingLines_Pro)

defun( DeleteDanglingLines_Pro ()
    let( (dangling_list delete_count design_clines min_length)
        delete_count = 0
        dangling_list = nil
        ; 定义微短线阈值：小于 0.01mm 的线段即便有连接也可能被视为垃圾
        min_length = 0.01 
        
        axlMsgPut("Pro-Scanning: Analyzing connectivity and segment length...")

        ; 获取所有走线段
        design_clines = axlDBGetDesign()->clines
        
        foreach(cline_parent design_clines
            foreach(seg cline_parent->segments
                when(axlIsAlive(seg) && seg->objType == "path"
                    ; 逻辑 1：基础物理断开检查
                    ; 逻辑 2：长度过滤（可选，防止误删，可根据需要调整）
                    if(_IsDanglingAdvanced(seg) then
                        push(seg dangling_list)
                    )
                )
            )
        )

        if(dangling_list then
            delete_count = length(dangling_list)
            axlDeleteObject(dangling_list)
            axlMsgPut("SUCCESS: %d dangling lines removed from database." delete_count)
            axlUIConfirm(sprintf(nil "Cleaned %d segments." delete_count))
        else
            axlMsgPut("VERIFIED: No dangling lines found in current database logic.")
        )
    )
)

defun(_IsDanglingAdvanced (obj)
    let((start_conn end_conn is_dangling)
        is_dangling = nil
        
        ; 检查两端的物理连接
        start_conn = axlDBGetConnect(obj t)
        end_conn   = axlDBGetConnect(obj nil)

        ; 如果任一端的连接列表长度为 0，说明它是真正的悬空
        if(length(start_conn) == 0 || length(end_conn) == 0 then
            is_dangling = t
        )
        
        is_dangling
    )
)
;#######################################################################
;#                                                                     #
;#  LGS Master Tool v3.1 - 工业级全集成架构 (Venture 兼容修复版)         #
;#                                                                     #
;#######################################################################

axlCmdRegister("lgs_check" 'LGS_Master_Entry)

;-----------------------------------------------------------------------
; 1. 核心向量引擎与拓扑算法 (修复函数未定义问题)
;-----------------------------------------------------------------------

; 获取线段单位向量
defun( _LGS_Get_Vector (seg)
    let( (p1 p2 dx dy len)
        p1 = car(seg->startEnd)
        p2 = cadr(seg->startEnd)
        dx = xCoord(p2) - xCoord(p1)
        dy = yCoord(p2) - yCoord(p1)
        len = sqrt(dx*dx + dy*dy)
        if(len > 0.0001 then list(dx/len dy/len) else list(0 0))
    )
)

; 算法：90度角检测
defun( _LGS_Algo_Check90 (net_name)
    let( (net_obj err_found v1 v2 dot)
        net_obj = axlDBFindByName('net net_name)
        err_found = nil
        foreach(br net_obj->branches
            let( (segs)
                segs = setof(x br->children x->objType == "path")
                foreach(path segs
                    foreach(seg path->segments
                        let( (conns)
                            conns = setof(c axlDBGetConnect(seg t) c->objType == "path")
                            foreach(next_seg conns
                                when(next_seg != seg
                                    v1 = _LGS_Get_Vector(seg)
                                    v2 = _LGS_Get_Vector(next_seg)
                                    dot = (car(v1)*car(v2) + cadr(v1)*cadr(v2))
                                    if(abs(dot) < 0.05 then err_found = car(seg->startEnd))
                                )
                            )
                        )
                    )
                )
            )
        )
        err_found
    )
)

; 算法：环路拓扑检测
defun( _LGS_Algo_CheckLoop (net_name)
    let( (net_obj has_loop)
        net_obj = axlDBFindByName('net net_name)
        has_loop = nil
        foreach(br net_obj->branches
            let( (segs nodes)
                segs = setof(x br->children x->objType == "path")
                nodes = makeTable('nodes nil)
                foreach(s segs
                    foreach(seg s->segments
                        nodes[car(seg->startEnd)] = t
                        nodes[cadr(seg->startEnd)] = t
                    )
                )
                if(length(segs) > 0 && length(segs) >= length(nodes) then
                    has_loop = car(car(segs)->startEnd)
                )
            )
        )
        has_loop
    )
)

; 调度引擎
defun( _LGS_Core_Engine (mode)
    let( (all_nets err_list err_xy total count)
        all_nets = axlDBGetDesign()->nets
        err_list = nil
        err_xy = nil
        total = length(all_nets)
        count = 0
        foreach(net_obj all_nets
            count++
            when(mod(count 200) == 0 axlMsgPut("Scanning: %d/%d" count total))
            let( (res)
                res = if(mode == "Loop" _LGS_Algo_CheckLoop(net_obj->name) _LGS_Algo_Check90(net_obj->name))
                when(res push(net_obj->name err_list) push(res err_xy))
            )
        )
        list(err_list err_xy)
    )
)

;-----------------------------------------------------------------------
; 2. UI 界面生成 (修复 Venture 兼容性)
;-----------------------------------------------------------------------

defun( _LGS_Create_Venture_Form ()
    let( (f_path f)
        f_path = "./lgs_v31.form"
        f = outfile(f_path)
        fprintf(f "FILE_TYPE=FORM_DEFN VERSION=2\nFORM\nFIXED\nPORT 32 35\nHEADER \"LGS Pro v3.1\"\n")
        fprintf(f "TILE\n")
        fprintf(f "TEXT \"1. Operations\"\nTLOC 2 1\nENDTEXT\n")
        fprintf(f "FIELD btn_check_90\nFLOC 2 4\nMENUBUTTON \"Check 90 Degree\" 28 3\nENDFIELD\n")
        fprintf(f "FIELD btn_check_loop\nFLOC 2 8\nMENUBUTTON \"Check Net Loops\" 28 3\nENDFIELD\n")
        fprintf(f "TEXT \"2. Result List (Zoom)\"\nTLOC 2 14\nENDTEXT\n")
        fprintf(f "FIELD err_list\nFLOC 2 16\nLIST \"\" 28 10\nENDFIELD\n")
        fprintf(f "FIELD btn_close\nFLOC 10 30\nMENUBUTTON \"CLOSE\" 12 3\nENDFIELD\n")
        fprintf(f "ENDTILE\nENDFORM\n")
        close(f)
        f_path
    )
)

;-----------------------------------------------------------------------
; 3. 回调处理
;-----------------------------------------------------------------------

defun( _LGS_V31_Callback (f)
    case(f->curField
        ("btn_check_90"   _LGS_Execute_and_Update(f "90_Deg"))
        ("btn_check_loop" _LGS_Execute_and_Update(f "Loop"))
        ("err_list"       
            let( (idx xy)
                idx = f->curValueInt
                xy = nthelem(idx+1 LGS_STATE['err_xy])
                when(xy axlWindowBoxSet(list(xCoord(xy)-50:yCoord(xy)-50 xCoord(xy)+50:yCoord(xy)+50)))
            )
        )
        ("btn_close"      axlFormClose(f))
    )
)

defun( _LGS_Execute_and_Update (f mode)
    let( (res)
        axlMsgPut("LGS Engine Running: %s..." mode)
        res = _LGS_Core_Engine(mode)
        LGS_STATE['err_list] = car(res)
        LGS_STATE['err_xy] = cadr(res)
        axlFormListDeleteAll(f "err_list")
        axlFormSetField(f "err_list" reverse(LGS_STATE['err_list]))
        LGS_STATE['err_xy] = reverse(LGS_STATE['err_xy])
        axlUIConfirm(sprintf(nil "Scan Finished. Found %d issues." length(LGS_STATE['err_list])))
    )
)

;-----------------------------------------------------------------------
; 4. 主进入函数
;-----------------------------------------------------------------------

defun( LGS_Master_Entry ()
    let( (f_path)
        ; 初始化状态表
        (unless (boundp 'LGS_STATE) (setq LGS_STATE (makeTable 'lgs_state nil)))
        f_path = _LGS_Create_Venture_Form()
        if( isFile(f_path) then
            LGS_STATE['form] = axlFormCreate((gensym) f_path '(e outer) '_LGS_V31_Callback t)
            if(LGS_STATE['form] then 
                axlFormDisplay(LGS_STATE['form]) 
            else 
                axlMsgPut("Error: Form creation failed.")
            )
        else
            axlMsgPut("Error: Cannot write form file.")
        )
    )
)

;#######################################################################
;#                                                                     #
;#  Check Cross Plane - 工业级跨平面走线检查                             #
;#                                                                     #
;#######################################################################

axlCmdRegister("check_cross" 'LGS_CP_Start)

defun( LGS_CP_Start ()
    let( (nets net_obj err_count count total)
        err_count = 0
        count = 0
        ; 过滤信号网络
        nets = setof(n axlDBGetDesign()->nets !n->isPower && !n->isGround)
        total = length(nets)

        axlMsgPut("---- Cross Plane Scan Start v7.1 ----")

        foreach(net_obj nets
            count++
            when(mod(count 50) == 0
                axlMsgPut("Scanning %d/%d nets..." count total)
            )

            ; 使用 errset 保护，防止个别 Net 数据损坏导致闪退
            errset(
                foreach(br net_obj->branches
                    foreach(seg br->segments
                        ; 增加安全性检查：确保 seg 及其属性存在
                        when(seg && seg->objType == "path" && seg->startEnd
                            unless(_LGS_Seg_Supported_Internal(seg)
                                err_count++
                                axlMsgPut("[CROSS] %s  Layer:%s  At:%L" 
                                    net_obj->name seg->layer car(seg->startEnd))
                                axlHighlightObject(net_obj)
                            )
                        )
                    )
                )
            t)
        )

        axlMsgPut("---- Scan Done ----")
        axlMsgPut("Total Issues: %d" err_count)
        axlUIConfirm(sprintf(nil "Scan Complete\nIssues Found: %d" err_count))
    )
)

;#######################################################################
;#                                                                     #
;#  Check no refdes  - 确认器件位号是否丢失                              #
;#                                                                     #
;#######################################################################

axlCmdRegister( "check_no_refdes" 'Check_No_Refdes)

defun( Check_No_Refdes ()

        axlVisibleDesign(nil)
 	axlVisibleLayer( "BOARD GEOMETRY/OUTLINE" t )
	axlVisibleLayer( "PIN/TOP" t )
	axlVisibleLayer( "PIN/BOTTOM" t )
	axlVisibleLayer( "REF DES/SILKSCREEN_TOP" t )
	axlVisibleLayer( "REF DES/SILKSCREEN_BOTTOM" t )
	axlVisibleLayer( "PACKAGE GEOMETRY/SILKSCREEN_TOP" t )
	axlVisibleLayer( "PACKAGE GEOMETRY/SILKSCREEN_BOTTOM" t )

	logfile = axlDMOpenLog("no_refdes.log")
	fprintf(logfile "#Check the component without refdes . \n\n")
	fprintf(logfile "REF_DES  COORDIRATION\n")

	setq(allsym axlDBGetDesign()->symbols)
	axlDehighlightObject(allsym)
	noref = nil
	norefcnt = 0
	foreach(symbol allsym 
		text= axlDBGetAttachedText(symbol)
		txt = nil
		foreach(find text
			if(find->layer == "REF DES/SILKSCREEN_TOP" || 
			find->layer == "REF DES/SILKSCREEN_BOTTOM" then 									
				txt = find			
			)								
		)
		if(txt == nil && symbol->refdes != nil then 
			axlHighlightObject(symbol)
			fprintf(logfile "%-8s %L\n" symbol->refdes symbol->xy)
			;noref = cons(symbol->refdes noref)
			++norefcnt
		)
	);foreach-end

	fprintf(logfile "\nTotal of no refdes: %d\n" norefcnt)
	axlDMClose(logfile)
	
	axlMsgPut("Total component without refdes: %d\n" norefcnt)
	axlMsgPut("Components without refdes , please view logfile.")        
);defun_end

;-----------------------------------------------------------------------
; 内部支撑算法：三点采样法
;-----------------------------------------------------------------------
defun( _LGS_Seg_Supported_Internal (seg)
    let( (p1 p2 mid layer refs covered all_shapes_at_pt)
        layer = seg->layer
        ; 适配参考层 (请根据实际情况修改层名)
        refs = case(layer
            ("TOP" list("GND2"))
            ("BOTTOM" list("GND5"))
            (t list("GND2" "GND5"))
        )

        p1 = car(seg->startEnd)
        p2 = cadr(seg->startEnd)
        mid = list((xCoord(p1) + xCoord(p2)) / 2.0 (yCoord(p1) + yCoord(p2)) / 2.0)

        covered = nil
        ; 遍历起点、中点、终点进行采样
        foreach(pt list(p1 mid p2)
            unless(covered ; 如果已经发现覆盖，则跳过后续采样点
                ; 获取该坐标点的所有 Shapes
                all_shapes_at_pt = axlDBGetShapes(list(pt pt))
                when(all_shapes_at_pt
                    ; 检查是否有 Shape 位于参考层
                    foreach(s all_shapes_at_pt
                        when(member(s->layer refs)
                            covered = t
                        )
                    )
                )
            )
        )
        covered ; 返回布尔值
    )
)

;#######################################################################
;#                                                                     #
;#  Check Pin No Solder Mask - 工业级阻焊开窗检查工具                    #
;#  功能：自动识别 SMD 焊盘并检查其在 Solder Mask 层是否有开窗           #
;#                                                                     #
;#######################################################################

axlCmdRegister("check_solder" 'LGS_Check_Solder_Entry)

defun( LGS_Check_Solder_Entry ()
    let( (all_pins err_list err_xy count total)
        err_list = nil
        err_xy = nil
        ; 获取设计中所有的 Pins
        all_pins = axlDBGetDesign()->pins
        total = length(all_pins)
        count = 0
        
        axlMsgPut(">>> Starting Solder Mask Check...")
        
        foreach(pin all_pins
            count++
            when(mod(count 500) == 0 axlMsgPut("Checking Pins: %d/%d" count total))
            
            ; 逻辑：如果是 SMD 焊盘，且没有被排除，则检查其阻焊层
            unless(pin->isThrough
                let( (layer_base sm_layer pin_pads has_solder)
                    ; 确定焊盘所在顶层或底层
                    layer_base = if(rexMatchp("TOP" pin->layer) "TOP" "BOTTOM")
                    sm_layer = sprintf(nil "SOLDERMASK_%s" layer_base)
                    
                    ; 获取该 Pin 在阻焊层的 Pad 定义
                    pin_pads = axlDBGetPad(pin sm_layer "REGULAR")
                    
                    ; 如果阻焊层 Pad 不存在或尺寸为 0，则记录错误
                    if( !pin_pads || pin_pads->bBox == list(0:0 0:0) then
                        push(sprintf(nil "%s.%s" pin->parent->name pin->number) err_list)
                        push(pin->xy err_xy)
                    )
                )
            )
        )
        
        ; 结果处理
        if(err_list then
            _LGS_Show_Solder_Results(reverse(err_list) reverse(err_xy))
        else
            axlUIConfirm("Success: All SMD pins have Solder Mask openings.")
        )
    )
)

;-----------------------------------------------------------------------
; 结果显示与交互界面
;-----------------------------------------------------------------------
defun( _LGS_Show_Solder_Results (names xys)
    let( (f_path f form)
        f_path = "./solder_check.form"
        f = outfile(f_path)
        fprintf(f "FILE_TYPE=FORM_DEFN VERSION=2\nFORM\nFIXED\nPORT 35 30\nHEADER \"Solder Mask Errors\"\n")
        fprintf(f "TILE\n")
        fprintf(f "TEXT \"Missing Solder Mask on Pins:\"\nTLOC 2 1\nENDTEXT\n")
        fprintf(f "FIELD err_list\nFLOC 2 3\nLIST \"\" 30 10\nENDFIELD\n")
        fprintf(f "FIELD btn_close\nFLOC 10 25\nMENUBUTTON \"CLOSE\" 12 3\nENDFIELD\n")
        fprintf(f "ENDTILE\nENDFORM\n")
        close(f)
        
        ; 存储全局数据用于回调
        (unless (boundp 'LGS_SOLDER_STATE) (setq LGS_SOLDER_STATE (makeTable 'solder nil)))
        LGS_SOLDER_STATE['xys] = xys
        
        form = axlFormCreate((gensym) f_path '(e outer) '_LGS_Solder_Callback t)
        axlFormSetField(form "err_list" names)
        axlFormDisplay(form)
    )
)

defun( _LGS_Solder_Callback (f)
    case(f->curField
        ("err_list"
            let( (idx xy)
                idx = f->curValueInt
                xy = nthelem(idx+1 LGS_SOLDER_STATE['xys])
                when(xy axlWindowBoxSet(list(xCoord(xy)-100:yCoord(xy)-100 xCoord(xy)+100:yCoord(xy)+100)))
            )
        )
        ("btn_close" axlFormClose(f))
    )
)

;#######################################################################
;#                                                                     #
;#  Check Single Pin Net - 工业级单端网络检查工具                        #
;#  功能：识别全板仅连接 1 个 Pin 的网络，支持 17.4 高速数据库遍历         #
;#                                                                     #
;#######################################################################

; 显式注册命令，确保在脚本加载时立即生效
axlCmdRegister("check_single" 'LGS_Check_SinglePin_Entry)

defun( LGS_Check_SinglePin_Entry ()
    let( (all_nets err_list err_xy total count pin_count)
        (unless (boundp 'LGS_SINGLE_STATE) (setq LGS_SINGLE_STATE (makeTable 'single nil)))
        err_list = nil
        err_xy = nil
        all_nets = axlDBGetDesign()->nets
        total = length(all_nets)
        count = 0
        
        axlMsgPut(">>> Starting Single Pin Net Scan...")
        
        foreach(net_obj all_nets
            count++
            when(mod(count 200) == 0 axlMsgPut("Scanning Nets: %d/%d" count total))
            
            ; 工业级判定：Pin 计数等于 1 的网络即为异常
            pin_count = length(net_obj->pins)
            
            if(pin_count == 1 then
                push(net_obj->name err_list)
                ; 记录该唯一引脚的坐标用于定位
                push(car(net_obj->pins)->xy err_xy)
            )
        )
        
        if(err_list then
            _LGS_Show_Single_Results(reverse(err_list) reverse(err_xy))
        else
            axlUIConfirm("Success: No single-pin nets found.")
        )
    )
)

;-----------------------------------------------------------------------
; 结果交互界面 (采用最保守的 Form 语法以确保兼容性)
;-----------------------------------------------------------------------
defun( _LGS_Show_Single_Results (names xys)
    let( (f_path f form)
        f_path = "./single_pin.form"
        f = outfile(f_path)
        fprintf(f "FILE_TYPE=FORM_DEFN VERSION=2\nFORM\nFIXED\nPORT 35 35\nHEADER \"Single Pin Net Errors\"\n")
        fprintf(f "TILE\n")
        fprintf(f "TEXT \"Single Pin Nets Found:\"\nTLOC 2 1\nENDTEXT\n")
        fprintf(f "FIELD err_list\nFLOC 2 3\nLIST \"\" 30 12\nENDFIELD\n")
        fprintf(f "FIELD btn_close\nFLOC 10 30\nMENUBUTTON \"CLOSE\" 12 3\nENDFIELD\n")
        fprintf(f "ENDTILE\nENDFORM\n")
        close(f)
        
        LGS_SINGLE_STATE['xys] = xys
        form = axlFormCreate((gensym) f_path '(e outer) '_LGS_Single_Callback t)
        axlFormSetField(form "err_list" names)
        axlFormDisplay(form)
    )
)

defun( _LGS_Single_Callback (f)
    case(f->curField
        ("err_list"
            let( (idx xy)
                idx = f->curValueInt
                xy = nthelem(idx+1 LGS_SINGLE_STATE['xys])
                when(xy 
                    axlWindowBoxSet(list(xCoord(xy)-150:yCoord(xy)-150 xCoord(xy)+150:yCoord(xy)+150))
                    axlHighlightObject(axlDBFindByName('net nthelem(idx+1 axlFormGetField(f "err_list"))))
                )
            )
        )
        ("btn_close" axlFormClose(f))
    )
)

;#######################################################################
;#                                                                     #
;#  Check Text Overlap - 丝印重叠焊盘检查                               #
;#                                                                     #
;#######################################################################

axlCmdRegister("check_text" 'LGS_Check_Text)

defun( LGS_Check_Text ()
    let( (texts err_count count total bbox overlaps txt_obj)

        err_count = 0
        count = 0

        ; 获取所有丝印层文字
        texts = setof(t axlDBGetDesign()->text
                  rexMatchp("SILKSCREEN" t->layer))

        total = length(texts)
        axlMsgPut("Total Text Objects: %d" total)

        foreach(txt_obj texts
            count++

            when(mod(count 50) == 0
                axlMsgPut("Scanning %d/%d..." count total)
            )

            errset(
                when(txt_obj->bBox
                    ; 将检索范围略微扩大 (0.1mm 或 4mils 左右即可)，防止过度检索
                    bbox = axlBBoxGrow(txt_obj->bBox 0.2)
                    overlaps = axlDBGetOverlaps(bbox)

                    foreach(obj overlaps
                        ; 检查对象是否为引脚 (pin)
                        when(obj->objType == "pin"
                            ; 调用层匹配辅助函数
                            when(_LGS_Is_Layer_Match_Internal(txt_obj->layer obj->layer)
                                ; axlAirGap < 0 表示物理碰撞
                                when(axlAirGap(txt_obj obj) < 0
                                    err_count++
                                    axlMsgPut("[OVERLAP] %s At %L" 
                                              txt_obj->text txt_obj->xy)

                                    axlHighlightObject(txt_obj)
                                    axlHighlightObject(obj)
                                )
                            )
                        )
                    )
                )
            t)
        )

        axlMsgPut("------------------------------------")
        axlMsgPut("TOTAL OVERpad: %d" err_count)

        axlUIConfirm(
            sprintf(nil "Text overpad check done\nFound %d issues" err_count)
        )
    )
)

;-----------------------------------------------------------------------
; 辅助函数：判断文字层与焊盘层是否在同侧
;-----------------------------------------------------------------------
defun( _LGS_Is_Layer_Match_Internal (txt_ly pad_ly)
    let( (is_match)
        is_match = nil
        when( (rexMatchp("TOP" txt_ly) && rexMatchp("TOP" pad_ly)) ||
              (rexMatchp("BOTTOM" txt_ly) && rexMatchp("BOTTOM" pad_ly))
            is_match = t
        )
        is_match
    )
)

;#######################################################################
;#                                                                     #
;#  Check Text Over Via - 丝印覆盖过孔检查 (v1.2 修复版)                 #
;#  修正：统一命令名称为 check_over_via，修复 defun 语法嵌套错误          #
;#                                                                     #
;#######################################################################
axlCmdRegister("check_over_via" 'LGS_Check_Text_Via)

defun( LGS_Check_Text_Via ()
    let( (texts err_count total count via_total bbox overlaps txt_obj)

        err_count = 0
        count = 0

        ; 获取丝印层对象
        texts = setof(t axlDBGetDesign()->text
                      rexMatchp("SILKSCREEN" t->layer))

        total = length(texts)
        via_total = length(axlDBGetDesign()->vias)

        axlMsgPut(sprintf(nil "Texts: %d   Vias: %d" total via_total))

        foreach(txt_obj texts
            count++

            when(mod(count 50) == 0
                axlMsgPut(sprintf(nil "Scanning %d/%d texts..." count total))
            )

            ; errset 保护防止 Venture 版 MiniDump 崩溃
            errset(
                when(txt_obj->bBox
                    ; 安全检索半径，防止内存溢出
                    bbox = axlBBoxGrow(txt_obj->bBox 0.2)
                    overlaps = axlDBGetOverlaps(bbox)

                    foreach(obj overlaps
                        when(obj->objType == "via"
                            ; 调用内部层匹配函数
                            when(_LGS_Internal_Via_Match(txt_obj->layer obj)
                                ; 物理间距小于 0 代表碰撞
                                when(axlAirGap(txt_obj obj) < 0
                                    err_count++
                                    axlMsgPut(sprintf(nil "[VIA_OVERLAP] %s At %L" 
                                              txt_obj->text txt_obj->xy))

                                    axlHighlightObject(txt_obj)
                                    axlHighlightObject(obj)
                                )
                            )
                        )
                    )
                )
            t)
        )

        axlMsgPut("--------------------------------------------")
        axlMsgPut(sprintf(nil "TOTAL VIA OVERLAPS: %d" err_count))

        axlUIConfirm(
            sprintf(nil "Check finished\nFound %d issues" err_count)
        )
    )
)

;-----------------------------------------------------------------------
; 辅助函数：过孔层匹配 (确保只检查同侧)
;-----------------------------------------------------------------------
defun( _LGS_Internal_Via_Match (silk_ly via_obj)
    let( (match is_top is_bot v_layers)
        match = nil
        is_top = rexMatchp("TOP" silk_ly)
        is_bot = rexMatchp("BOTTOM" silk_ly)
        v_layers = via_obj->startEnd
        
        ; 判定逻辑：丝印在 TOP，则检查过孔是否有 TOP 端的开口
        when( (is_top && (member("TOP" v_layers) || rexMatchp("TOP" car(v_layers)))) ||
              (is_bot && (member("BOTTOM" v_layers) || rexMatchp("BOTTOM" car(v_layers))))
            match = t
        )
        match
    )
)