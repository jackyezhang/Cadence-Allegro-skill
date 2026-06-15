;###########################################################
;# 优化版: 批量修改线宽工具 (cwidth)
;# 改进点: 
;# 1. 使用 Table 提升去重性能
;# 2. 规范 let 作用域，防止全局变量污染
;# 3. 增强数据精度对比逻辑
;# 4. 优化 UI 刷新反馈
;###########################################################

axlCmdRegister("cwidth" 'lcb_changewidth_v2)

defun( lcb_changewidth_v2 (@optional (args ""))
    let( (dbaccuracy dbunits curdrcs changewidth_Form l_layers etchparam)
        ; 1. 初始化环境
        dbaccuracy = nthelem(2 axlDBGetDesignUnits())
        dbunits = nthelem(1 axlDBGetDesignUnits())
        curdrcs = axlDRCGetCount()
        
        ; 2. 获取层信息
        etchparam = axlGetParam("paramLayerGroup:ETCH")
        l_layers = etchparam->groupMembers
        
        ; 3. 创建动态 UI (使用临时目录)
        let( (formFile p)
            formFile = "cwidth_v2.form"
            _create_v2_form(formFile l_layers dbaccuracy)
            changewidth_Form = axlFormCreate((gensym) formFile nil 'changewidth_v2_action t)
            if(isFile(formFile) deleteFile(formFile))
        )
        
        ; 4. 显示并初始化
        axlFormDisplay(changewidth_Form)
        axlUIWPrint(changewidth_Form "** Current DRCs: %d **" curdrcs)
    )
)

; --- 高性能获取宽度列表 ---
defun( LCB_get_widths_fast (layername)
    let( (widthTable lallclinesegs layersegs class)
        widthTable = makeTable("widths" nil)
        class = strcat("ETCH/" upperCase(layername))
        
        ; 仅获取当前层线段
        lallclinesegs = axlVisGetObjects('("CLINESEGS") 'visible)
        layersegs = setof(s lallclinesegs s->layer == class)
        
        foreach(s layersegs
            widthTable[s->width] = t
        )
        
        ; 返回排序后的宽度列表 (字符串格式供 Popup 使用)
        sort(mapcar(lambda((w) list(sprintf(nil "%L" w) sprintf(nil "%L" w))) widthTable->?) 
             lambda((a b) atof(car(a)) < atof(car(b))))
    )
)

; --- Form 动作处理 ---
defun( changewidth_v2_action (f)
    let( (layername sourcewidth newwidth tol layersegs l_swidth)
        case(f->curField
            ("layers"
                layername = f->curValue
                ; 更新宽度下拉菜单
                axlFormBuildPopup(f "widths" LCB_get_widths_fast(layername))
                ; 自动高亮该层
                axlVisibleDesign(nil)
                axlVisibleLayer(strcat("ETCH/" layername) t)
                axlVisibleUpdate(t)
            )
            
            ("done"
                layername = axlFormGetField(f "layers")
                sourcewidth = atof(axlFormGetField(f "widths"))
                newwidth = f->allFields->newsegwidth ; 直接从 f 对象读取
                
                if(layername && sourcewidth && newwidth then
                    if(abs(sourcewidth - newwidth) < 0.0001 then
                        axlUIWPrint(f "Widths are identical. No change.")
                    else
                        _execute_change_width(layername sourcewidth newwidth)
                        axlUIWPrint(f "Change Done! DRCs: %d" axlDRCGetCount())
                    )
                else
                    axlUIWPrint(f "Please select Layer and Source Width.")
                )
            )
            
            ("close"
                axlFormClose(f)
            )
        )
    )
)

; --- 核心执行逻辑 ---
defun( _execute_change_width (lname sw nw)
    let( (class segs targetSegs count)
        class = strcat("ETCH/" upperCase(lname))
        segs = axlDBGetDesign()->clinesegs ; 遍历数据库对象
        targetSegs = setof(s segs s->layer == class && abs(s->width - sw) < 0.0001)
        count = 0
        
        axlMsgPut("Changing %d segments..." length(targetSegs))
        
        foreach(s targetSegs
            ; 优化：使用 axlDBChangeElementWidth 直接修改线宽
            ; 这样不需要删除重建，能保持数据库 ID 稳定并处理 Arc
            if(axlDBChangeElementWidth(s nw) then
                count++
            )
        )
        axlMsgPut("Successfully updated %d segments." count)
    )
)

; --- 简化版 Form 创建 ---
defun( _create_v2_form (file layers accuracy)
    let( (p)
        p = outfile(file "w")
        fprintf(p "FILE_TYPE=FORM_DEFN VERSION=2\nFORM\nFIXED\nPORT 40 12\nHEADER \"Width Changer Pro\"\nTILE\n")
        
        fprintf(p "GROUP \"Selection\"\nGLOC 1 1\nGSIZE 38 10\nENDGROUP\n")
        
        fprintf(p "TEXT \"Layer:\"\nTLOC 3 3\nENDTEXT\n")
        fprintf(p "FIELD layers\nFLOC 18 3\nENUMSET 15\nENDFIELD\n")
        
        fprintf(p "TEXT \"Old Width:\"\nTLOC 3 5\nENDTEXT\n")
        fprintf(p "FIELD widths\nFLOC 18 5\nENUMSET 15\nENDFIELD\n")
        
        fprintf(p "TEXT \"New Width:\"\nTLOC 3 7\nENDTEXT\n")
        fprintf(p "FIELD newsegwidth\nFLOC 18 7\nREALFILLIN 8 8\nDECIMAL %d\nENDFIELD\n" accuracy)
        
        fprintf(p "FIELD done\nFLOC 5 11\nMENUBUTTON \"Execute\" 12 3\nENDFIELD\n")
        fprintf(p "FIELD close\nFLOC 22 11\nMENUBUTTON \"Close\" 12 3\nENDFIELD\n")
        
        fprintf(p "ENDTILE\nENDFORM\n")
        close(p)
    )
)
;;###############################################################################
; replace_via.il (Fixed Version)
; 功能: 修正函数调用错误，实现过孔批量替换
;###############################################################################

axlCmdRegister("replace_via" 'replace_via_main)

defun( replace_via_main ()
    let((allPads viaNames)
        ; 1. 正确获取当前设计中所有已定义的 Padstack 名称
        allPads = axlDBGetDesign()->padstacks
        viaNames = nil
        foreach(p allPads
            ; 过滤掉可能是引脚(Pin)的定义，通常只收集 Via
            if(p->type == "VIA" || p->type == "NONE" then
                viaNames = cons(p->name viaNames)
            )
        )
        viaNames = sort(viaNames 'alphalessp)
        
        if(!viaNames then
            axlUIConfirm("Error: No via definitions found in this design.")
            return(nil)
        )

        ; 2. 创建并显示 UI
        create_replace_via_form(viaNames)
        display_replace_via_form()
    )
)

; --- 创建动态 Form ---
defun( create_replace_via_form (viaList)
    let((p)
        p = outfile("replace_via.form" "w")
        fprintf(p "FILE_TYPE=FORM_DEFN VERSION=2\n")
        fprintf(p "FORM\nFIXED\nPORT 42 16\n")
        fprintf(p "HEADER \"Replace Via Pro\"\n\n")
        fprintf(p "TILE\n")
        
        fprintf(p "GROUP \"Configuration\"\n")
        fprintf(p "GLOC 2 1\nGSIZE 38 10\nENDGROUP\n\n")

        fprintf(p "TEXT \"Target Via Type:\"\n")
        fprintf(p "TLOC 4 4\nENDTEXT\n")
        
        fprintf(p "FIELD target_via\n")
        fprintf(p "FLOC 18 4\n")
        fprintf(p "ENUMSET 18\n")
        fprintf(p "OPTIONS OWNERDESC\n")
        foreach(v viaList
            fprintf(p "ENUMERATED \"%s\"\n" v)
        )
        fprintf(p "ENDFIELD\n\n")

        fprintf(p "FIELD apply_btn\n")
        fprintf(p "FLOC 6 12\n")
        fprintf(p "MENUBUTTON \"Select & Replace\" 16 3\n")
        fprintf(p "ENDFIELD\n\n")

        fprintf(p "FIELD close_btn\n")
        fprintf(p "FLOC 24 12\n")
        fprintf(p "MENUBUTTON \"Close\" 10 3\n")
        fprintf(p "ENDFIELD\n\n")

        fprintf(p "ENDTILE\nENDFORM\n")
        close(p)
    )
)

; --- 显示 Form ---
defun( display_replace_via_form ()
    let((f)
        f = axlFormCreate((gensym) "replace_via.form" '(inner_beam) 'replace_via_action t)
        axlFormDisplay(f)
        axlUIWPrint(f "Select a via type and click Replace.")
    )
)

; --- 动作处理 ---
defun( replace_via_action (f)
    case(f->curField
        ("close_btn"
            axlFormClose(f)
            if(isFile("replace_via.form") then deleteFile("replace_via.form"))
        )
        ("apply_btn"
            let((targetName vias succ total)
                targetName = f->curValue
                
                ; 切换选择集
                axlClearSelSet()
                axlSetFindFilter(?enabled '("noall" "vias") ?onButtons '("noall" "vias"))
                axlMsgPut("Click and drag to select vias in canvas...")
                
                ; 阻塞式选择：等待用户选择完成
                if(axlSelect() then
                    vias = axlGetSelSet()
                    total = length(vias)
                    succ = 0
                    
                    foreach(v vias
                        ; 使用 axlReplaceVia 核心命令
                        if(axlReplaceVia(v targetName) then
                            succ++
                        )
                    )
                    axlUIWPrint(f sprintf(nil "Done: %d of %d replaced." succ total))
                    axlMsgPut("Replaced %d vias with %s." succ targetName)
                else
                    axlUIWPrint(f "No vias selected.")
                )
                axlClearSelSet()
            )
        )
    )
)

;;###############################################################################
; align component.il (Fixed Version)
; 功能: 修正函数调用错误，实现过孔批量替换
;###############################################################################

axlCmdRegister( "al" 'aln ?cmdType "interactive" ?doneCmd 'alnDone ?cancelCmd 'alnCancel )

;--- 2. 主逻辑程序 ---
procedure( aln()
    let( (formFile popupA)
        unless( axlOKToProceed() return(nil) )
        
        ; 初始化全局变量
        _alnFinish = nil
        _alnHandler = nil
        _alnSelectedObjects = nil
        
        ; 查找并加载 Form (自动搜索 skillpath)
        formFile = axlDMFindFile("form" "align.form" "r")
        if( formFile then
            _alnFormPtr = axlFormCreate( (gensym) formFile '(ne canvas msglines 0) 'alnFormCallBack t)
            axlFormDisplay(_alnFormPtr)
            
            popupA = axlUIPopupDefine( nil
                (list (list "Done" 'alnDone) (list "Oops" 'alnOops) (list "Cancel" 'alnCancel)))
            axlUIPopupSet( popupA )

            axlSetFindFilter(?enabled '(GROUPS SYMBOLS PINS VIAS TEXT NAMEFORM ) 
                             ?onButtons '(GROUPS SYMBOLS PINS VIAS TEXT))
            
            axlMsgPut("Select objects to align. Use Form or Hotkeys (W/A/S/D).")
            _alnTransactionMark = axlDBTransactionStart()
            
            while( !_alnFinish
                axlSelect(?groupMode nil)
                _alnSelectedObjects = axlGetSelSet()
                
                if( _alnHandler then
                    if( _alnSelectedObjects then
                        axlDBTransactionMark(_alnTransactionMark)
                        funcall(_alnHandler)
                        _alnSelectedObjects = alnRefreshIDs(_alnSelectedObjects)
                        axlSingleSelectObject(_alnSelectedObjects)
                    else
                        axlMsgPut("No objects selected!")
                    )
                    _alnHandler = nil
                )
            )
        else
            axlUIConfirm("Error: align.form not found in skillpath!")
        )
    )
)

;--- 3. 核心工具函数 (Utils) ---
defun( alnGetObjectLocation (object)
    let( (res)
        case( _alnFormData->snapPoint
            ( "origin" res = axlDBAltOrigin('origin object) )
            ( "center" res = axlDBAltOrigin('center object) )
            ( t res = axlDBAltOrigin('center object) )
        )
        res
    )
)

defun( alnGriddedPoint (point grids)
    let( (px py)
        px = xCoord(point) py = yCoord(point)
        if( _alnFormData->snapToGrid && grids then
            if(grids->xMajor > 0 px = round(px / grids->xMajor) * grids->xMajor + grids->xOrigin)
            if(grids->yMajor > 0 py = round(py / grids->yMajor) * grids->yMajor + grids->yOrigin)
        )
        list(px py)
    )
)

defun( alnRefreshIDs (lst) mapcar(lambda((o) if(axlIsDBId(o) o axlDBRefreshId(o))) lst))

;--- 4. 对齐动作执行 (Actions) ---
defun( alnOnTop () _alnHandler = 'alnDoTop axlFinishEnterFun())
defun( alnDoTop () axlDBCloak( 'alnDoMoveTop() 'shape ))
defun( alnDoMoveTop ()
    let( (lBBoxes maxY i obj boxY objY griddedY grids)
        lBBoxes = mapcar(lambda((o) o->bBox) _alnSelectedObjects)
        maxY = apply('max mapcar(lambda((b) yCoord(cadr(b))) lBBoxes))
        grids = axlDBGridGet(axlConductorTopLayer())
        
        foreach( obj _alnSelectedObjects
            boxY = yCoord(cadr(obj->bBox))
            objY = yCoord(alnGetObjectLocation(obj))
            griddedY = yCoord(alnGriddedPoint(list(0.0 (objY + (maxY - boxY))) grids))
            axlTransformObject(obj ?move list(0.0 (griddedY - objY)))
        )
    )
)

;--- 5. 回调与退出 ---
defun( alnFormCallBack (fw)
    case( fw->curField
        ("bnTop" alnOnTop())
        ("bnLeft" ( _alnHandler = 'alnDoLeft axlFinishEnterFun() ))
        ; 这里可以继续添加其他按钮关联
    )
)

defun( alnDone () _alnFinish = t axlDBTransactionCommit(_alnTransactionMark) axlFinishEnterFun() if(_alnFormPtr axlFormClose(_alnFormPtr)))
defun( alnCancel () _alnFinish = t axlDBTransactionRollback(_alnTransactionMark) axlCancelEnterFun() if(_alnFormPtr axlFormClose(_alnFormPtr)))
defun( alnOops () axlDBTransactionRollback(_alnTransactionMark) _alnTransactionMark = axlDBTransactionStart())