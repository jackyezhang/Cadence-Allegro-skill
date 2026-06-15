;#######################################################################
;#                                                                     #
;#  LGS Auto Symbol Generator - 自动化建库工具 (v1.1 极速版)             #
;#                                                                     #
;#######################################################################

axlCmdRegister("auto_sym" 'LGS_Auto_Symbol_Main)

defun( LGS_Auto_Symbol_Main ()
    let( (pad_stack center_pt)
        axlMsgPut(">>> Automation: Building Symbol Geometry...")

        ; 设置为封装模式
        axlSetSymbolType("PACKAGE")

        ; 2. 放置示例引脚 (X:Y 坐标)
        ; 注意：请确保 pad60r40 在你的 psmpath/padpath 中存在
        pad_stack = "pad60r40" 
        
        LGS_Internal_Place_Pin(pad_stack -100.0:-100.0 "1")
        LGS_Internal_Place_Pin(pad_stack  100.0:-100.0 "2")
        LGS_Internal_Place_Pin(pad_stack  100.0:100.0  "3")
        LGS_Internal_Place_Pin(pad_stack -100.0:100.0  "4")

        ; 3. 绘制丝印和位号
        LGS_Internal_Draw_Box(-120.0:-120.0 120.0:120.0 "PACKAGE GEOMETRY/SILKSCREEN_TOP")
        LGS_Internal_Add_Text("REF" 0.0:150.0 "REF DES/SILKSCREEN_TOP")

        axlMsgPut(">>> Process Complete. Please save the .dra file.")
        axlUIConfirm("Symbol automation finished.")
    )
)

; --- 内部支撑函数 (Static Methods) ---

defun( LGS_Internal_Place_Pin (pname pxy pno)
    let( (status)
        status = axlDBCreatePin(pname pxy pno)
        unless(status axlMsgPut(sprintf(nil "  ! Failed to place Pin %s" pno)))
    )
)

defun( LGS_Internal_Draw_Box (low high layer)
    let( (x1 y1 x2 y2 pts)
        x1 = xCoord(low) y1 = yCoord(low)
        x2 = xCoord(high) y2 = yCoord(high)
        pts = list(x1:y1 x2:y1 x2:y2 x1:y2 x1:y1)
        axlDBCreateLine(pts 5.0 layer)
    )
)

defun( LGS_Internal_Add_Text (txt xy ly)
    let( (ori)
        ori = make_axlTextOrientation(?textBlock "3" ?justify "center")
        axlDBCreateText(txt xy ori ly nil)
    )
)


;#######################################################################
;#                                                                     #
;#  LGS Padstack Auditor - 焊盘批量检查工具 (v1.0)                      #
;#                                                                     #
;#######################################################################

axlCmdRegister("check_pads" 'LGS_Fix_Pads_Main)

(defun LGS_Fix_Pads_Main ()
    ; 显式初始化局部变量
    (let ((pins nil) (count 0) (fixed_count 0) (sm_expansion 0.05))
        
        axlMsgPut(">>> Starting Pad Fix Procedure...")

        ; 1. 过滤选择：只处理元件 Pin
        axlClearSelSet()
        axlSetFindFilter(?enabled '("noall" "pins") ?onButtons '("noall" "pins"))
        pins = axlGetSelSet(axlAddSelectAll())
        axlClearSelSet()

        (unless pins 
            axlUIConfirm("No pins found in the current design.")
            return(nil)
        )

        ; 2. 核心修复逻辑
        (foreach pin pins
            (when (and pin->objType == "pin" pin->component)
                count++
                
                (foreach layer_pair '(("TOP" "SOLDERMASK_TOP") ("BOTTOM" "SOLDERMASK_BOTTOM"))
                    (let (reg_layer mask_layer mask_pad reg_pad bbox dx dy fig new_pad)
                        reg_layer  = car(layer_pair)
                        mask_layer = cadr(layer_pair)

                        ; 仅当 SolderMask 层存在且当前 Pin 缺失该层定义时执行
                        (when (and axlLayerGet(mask_layer) !axlDBGetPad(pin mask_layer "REGULAR"))
                            reg_pad = axlDBGetPad(pin reg_layer "REGULAR")
                            
                            (when reg_pad
                                bbox = reg_pad->bBox
                                ; 计算补偿后的尺寸
                                dx = abs(xCoord(nth(1 bbox)) - xCoord(nth(0 bbox))) + (2 * sm_expansion)
                                dy = abs(yCoord(nth(1 bbox)) - yCoord(nth(0 bbox))) + (2 * sm_expansion)
                                fig = (reg_pad->figureName || "CIRCLE")

                                ; 构造新的焊盘数据 (修正函数名为 make_axlPadStackPad)
                                new_pad = make_axlPadStackPad(
                                    ?layer  mask_layer
                                    ?type   "REGULAR"
                                    ?figure fig
                                    ?width  dx
                                    ?height dy
                                )

                                ; 局部修改 Padstack Instance
                                (if axlPadstackInstancePatch(pin new_pad)
                                    then fixed_count++
                                    else axlMsgPut("Warning: Failed to patch pin at %L" pin->xy)
                                )
                            )
                        )
                    )
                )
            )
        )

        ; 3. 统计输出
        axlMsgPut("-------------------------------------")
        axlMsgPut(sprintf(nil "Pins processed : %d" count))
        axlMsgPut(sprintf(nil "Masks added    : %d" fixed_count))
        axlMsgPut("-------------------------------------")

        axlUIConfirm(
            sprintf(nil "Pad Fix Finished\n\nScanned Pins: %d\nCreated Masks: %d" 
                    count fixed_count)
        )
    )
)