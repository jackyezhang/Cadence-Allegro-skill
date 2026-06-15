;#######################################################################
;#                                                                     #
;#  Gerber Auto-Export - 自动光绘生成工具                                #          
;#                                                                     #
;#######################################################################

axlCmdRegister("export_gerber" 'LGS_Export_Gerber_Final)

defun( LGS_Export_Gerber_Final ()
    let( ()
        axlMsgPut(">>> Manufacturing Export: Triggering Command Buffer Mode...")

        ; 1. 通过执行系统命令来设置 Artwork 参数 (绕过 axlControlParameter)
        ; 模拟用户在参数窗口的操作，3:5 精度，RS274X 格式
        axlShell("prmed artwork")
        
        ; 2. 检查并建立层叠 (使用 axlAddFilm 基础函数，并用 errset 保护)
        _LGS_Build_Film_Stack_Safe()

        ; 3. 调用光绘导出引擎
        axlMsgPut(">>> Executing RS274X Generation...")
        
        ; 使用 batch 模式直接运行 artwork.exe
        if( axlShell("artwork -local") then
            axlUIConfirm("Gerber Export Process Triggered! \nCheck your folder for .art files.")
        else
            axlMsgPut(">>> Error: 'artwork' process could not start.")
        )
    )
)

;-----------------------------------------------------------------------
; 安全建立底片层叠：仅使用最基础的 axlAddFilm
;-----------------------------------------------------------------------
defun( _LGS_Build_Film_Stack_Safe ()
    let( (f_top f_bot f_silk f_mask)
        
        ; 定义每一层包含的子层 (Subclasses)
        f_top  = list("ETCH/TOP" "PIN/TOP" "VIA CLASS/TOP")
        f_bot  = list("ETCH/BOTTOM" "PIN/BOTTOM" "VIA CLASS/BOTTOM")
        f_silk = list("REF DES/SILKSCREEN_TOP" "PACKAGE GEOMETRY/SILKSCREEN_TOP")
        f_mask = list("PIN/SOLDERMASK_TOP" "VIA CLASS/SOLDERMASK_TOP")

        ; 使用 errset 包装。如果层已存在，axlAddFilm 会返回 nil 但不会程序崩溃
        errset( axlAddFilm("TOP" f_top) t )
        errset( axlAddFilm("BOTTOM" f_bot) t )
        errset( axlAddFilm("SILK_TOP" f_silk) t )
        errset( axlAddFilm("SOLDER_TOP" f_mask) t )

        axlMsgPut(">>> Film definitions updated (Safe Mode).")
    )
)

;#######################################################################
;#                                                                     #
;#  LGS BOM Exporter - 自动 BOM 导出工具                                #
;#                                                                     #
;#######################################################################

axlCmdRegister("export_bom" 'LGS_Export_BOM_Main)

defun( LGS_Export_BOM_Main ()
    let( (comp_list bom_table out_file csv_path)
        axlMsgPut(">>> BOM Extraction Started (v1.2)...")

        bom_table = makeTable("BOM" nil)
        comp_list = axlDBGetDesign()->components
        
        foreach(comp comp_list
            when(comp->name && comp->name != ""
                let( (val dev ftp key_str)
                    ; --- 健壮属性提取逻辑：确保没有任何变量为 nil ---
                    ; 使用 format 函数或 if 判断强制转换为字符串
                    val = if(comp->value && comp->value != "" comp->value "N/A")
                    dev = if(comp->device && comp->device != "" comp->device "N/A")
                    
                    ; 提取封装名，增加多重判空保护
                    ftp = "N/A"
                    when(comp->symbol && comp->symbol->name
                        ftp = comp->symbol->name
                    )
                    
                    ; 此时所有变量均保证为 String 类型，不再会报 format incompatible 错误
                    key_str = sprintf(nil "%s|%s|%s" dev val ftp)
                    
                    if( bom_table[key_str] then
                        bom_table[key_str] = cons(comp->name bom_table[key_str])
                    else
                        bom_table[key_str] = list(comp->name)
                    )
                )
            )
        )

        ; 写入文件
        csv_path = "./BOM_Output.csv"
        out_file = outfile(csv_path "w")
        
        if(out_file then
            fprintf(out_file "Item,Device,Value,Footprint,Quantity,Designators\n")
            let( (idx)
                idx = 1
                foreach(k bom_table
                    let( (parts refs)
                        ; 使用 parseString 拆分 Key
                        parts = parseString(k "|")
                        refs = bom_table[k]
                        
                        ; 再次检查 parts 列表长度，确保数据完整性
                        fprintf(out_file "%d,%s,%s,%s,%d,\"%s\"\n" 
                                idx 
                                (nthelem(1 parts) || "N/A") 
                                (nthelem(2 parts) || "N/A") 
                                (nthelem(3 parts) || "N/A") 
                                length(refs) 
                                buildString(refs " "))
                        idx++
                    )
                )
            )
            close(out_file)
            
            axlMsgPut(">>> BOM Export Successful!")
            axlUIConfirm(sprintf(nil "BOM Exported to: %s" csv_path))
        else
            axlMsgPut(">>> ERROR: Cannot write file. Access Denied.")
        )
    )
)

;#######################################################################
;#                                                                     #
;#  LGS Pick & Place Exporter - 自动坐标导出工具                        #
;#                                                                     #
;#######################################################################

axlCmdRegister("export_place" 'LGS_Export_Place_Main)

defun( LGS_Export_Place_Main ()
    let( (comp_list out_file csv_path count)
        axlMsgPut(">>> Pick & Place: Starting Extraction...")
        
        count = 0
        comp_list = axlDBGetDesign()->components
        csv_path = "./Pick_and_Place.csv"
        
        ; 2. 尝试打开文件
        out_file = outfile(csv_path "w")
        
        if(out_file then
            ; 写入符合标准 SMT 格式的表头
            fprintf(out_file "Designator,X,Y,Rotation,Layer,Footprint,Value\n")
            
            foreach(comp comp_list
                ; 增加多重逻辑保护，防止遇到 nil 对象崩溃
                when(comp && comp->name != ""
                    let( (sym x_y x_coord y_coord rot layer ftp val)
                        sym = comp->symbol
                        
                        if(sym then
                            ; 安全提取坐标和旋转
                            x_y = sym->xy || list(0.0 0.0)
                            x_coord = car(x_y)
                            y_coord = cadr(x_y)
                            rot = sym->rotation || 0.0
                            
                            ; 判定层级 (Top/Bottom)
                            layer = "Top"
                            when(sym->mirror, layer = "Bottom")
                            
                            ; 提取封装名和 Value (确保不为 nil)
                            ftp = sym->name || "N/A"
                            val = comp->value || "N/A"
                            
                            ; 3. 写入 CSV (保留 4 位精度)
                            fprintf(out_file "%s,%.4f,%.4f,%.2f,%s,%s,%s\n" 
                                    comp->name x_coord y_coord rot layer ftp val)
                            count++
                        else
                            axlMsgPut(sprintf(nil ">>> Skip: %s (No physical symbol)" comp->name))
                        )
                    )
                )
            )
            close(out_file)
            
            axlMsgPut("---------------------------------------------------")
            axlMsgPut(sprintf(nil ">>> SUCCESS: %d components exported." count))
            axlMsgPut(sprintf(nil ">>> File: %s" csv_path))
            axlMsgPut("---------------------------------------------------")
            
            axlUIConfirm(sprintf(nil "Export Done! \nTotal: %d components" count))
        else
            axlMsgPut(">>> ERROR: File could not be opened. Is Pick_and_Place.csv open in Excel?")
        )
    )
)
