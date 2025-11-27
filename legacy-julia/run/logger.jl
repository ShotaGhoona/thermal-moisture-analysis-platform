mutable struct Logger
    file::Array{IOStream,1}         # データを格納するcsvファイル
    file_name::String               # csvファイルの名称
    logging_interval::Float64       # データのロギング間隔
    data_type::Array{String,1}      # ロギングするデータの種類
    logging_data::Any               # ロギングするデータ
end

function set_logger( file_name::String, logging_interval, data_type::Array{String,1}, logging_data )
    # ファイルの作成
    if data_type == ["room_analysis"]
        file = [ open("./output_data/" * file_name * string(i) * ".csv", "w") for i = 1 : length(logging_data.rooms) ]
    else
        file = [ open("./output_data/"*file_name*".csv", "w") ]
    end
    # 書き込む情報の作成
    logger = Logger(file, file_name, logging_interval, data_type, logging_data)    
    return logger
end

function set_logger( file_name::String, logging_interval, data_type::Array{String,1}, data... )
    return set_logger( file_name, logging_interval, data_type, vcat(data...) )
end

function write_header_to_logger( logger::Logger )
    if logger.data_type == ["room_analysis"]
        write_header_room_analysis( logger )
    else
        write_header_basic( logger )
    end
end

function write_header_basic( logger::Logger )
    
    for n = 1 : length(logger.file)

        # date行は飛ばす
        print(logger.file[n], "," )
        log_num = length(logger.data_type)
            
        # 各種位置情報の書き出し
        for i = 1 : length(logger.logging_data)
            for j = 1 : log_num
                if typeof(logger.logging_data[i]) == Air
                    print(logger.file[n], logger.logging_data[i].name, "," )
                elseif typeof(logger.logging_data[i]) == BC_Dirichlet
                    print(logger.file[n], logger.logging_data[i].name, "," )
                elseif typeof(logger.logging_data[i]) == BC_Neumann
                    print(logger.file[n], logger.logging_data[i].name, "," )
                elseif typeof(logger.logging_data[i]) == BC_Robin
                    print(logger.file[n], logger.logging_data[i].air.name, "," )
                elseif typeof(logger.logging_data[i]) == Room
                    print(logger.file[n], "room"*string(num(logger.logging_data[i])), "," )
                elseif typeof(logger.logging_data[i]) == Cell
                    print(logger.file[n], "wall"*string(logger.logging_data[i].i[1]), "," )
                end
            end
        end       
        println(logger.file[n])

        # 時刻データの書き出し
        print(logger.file[n], " ," )

        # 記録するデータの種類を書き出す
        for i = 1 : length(logger.logging_data)
            for j = 1 : log_num
                print(logger.file[n], logger.data_type[j], ",")
            end
        end       

        println(logger.file[n])

    end
    
end

# ----------------
# 出力内容
# 室の温湿度・周辺壁の温度・相対湿度・絶対湿度　＋　熱流・水分流量、　換気流量、
# ----------------

function write_header_room_analysis( logger::Logger )

    network = logger.logging_data
    first_header_name  = String[]
    second_header_name = String[]

    # 各部屋に対する計算
    for r = 1 : length(network.rooms)
        
        # 空のヘッダーの作成
        first_header_name  = String[]
        second_header_name = String[]

        # 時刻・各部屋の情報の入力
        push!(first_header_name,  " ")
        push!(second_header_name, " ")
        for element = [ "temp", "rh", "ah" ]
            push!(first_header_name,  "room"*string(r) )
            push!(second_header_name, element)
        end

        # インシデンス行列により壁と面するかの判定
        for i = 1 : length(network.walls)
            if network.IC_walls[r,i] == 1
                wall_num = string(i) * "_IP"
            elseif network.IC_walls[r,i] == -1
                wall_num = string(i) * "_IM"
            else
                continue # 以下の動作をスキップ
            end
            # 値の書き込み
            for element = [ "temp", "rh", "ah", "Hw", "Jwv", "Jwl" ]
                push!(first_header_name,  "wall"*string(wall_num) )
                push!(second_header_name, element)
            end
        end

        # インシデンス行列により部屋との換気が生じているかの判定
        for i = 1 : length(network.openings)
            if network.IC_openings[r,i] == 1
                room_num = IM(network.openings[i])
            elseif network.IC_openings[r,i] == -1
                room_num = IP(network.openings[i])
            else
                continue # 以下の動作をスキップ
            end
            # 値の書き込み
            for element = [ "temp", "rh", "ah" ]
                push!(first_header_name,  "room"*string(room_num) )
                push!(second_header_name, element)
            end
            for element = [ "Hv", "Jv" ]
                push!(first_header_name,  "opening"*string(i) )
                push!(second_header_name, element)
            end
        end

        # 発熱源・発湿源
        push!(first_header_name,  "Heat source", "Moisture source" )
        push!(second_header_name, "Hin", "Jin")

        # 第一ヘッダーを記述
        for header_name = first_header_name
            print( logger.file[r], header_name,  " , " )
        end
        println( logger.file[r])

        # 第二ヘッダーを記述
        for header_name = second_header_name
            print( logger.file[r], header_name,  " , " )
        end
        println( logger.file[r])

    end

end

function write_data_to_logger( logger::Logger, date::DateTime )
    # ロギングインターバル時に起動
    if mod(minute(date), Int(logger.logging_interval)) == 0 && second(date) == 0 && millisecond(date) == 0
       if logger.data_type == ["room_analysis"]        
            write_data_for_room_analysis( logger )
        else
            write_data_basic( logger, date )
        end
    end
end

function write_data_basic( logger::Logger, date::DateTime )

    for n = 1 : length(logger.file)

        # 時刻の書き出し
        print(logger.file[n], Dates.format(date, "yyyy/mm/dd HH:MM"), ",")

        # 記録するデータを書き出す
        try 
            if logger.data_type == ["temp"]
                for i = 1 : length(logger.logging_data); print(logger.file[n], round(temp(logger.logging_data[i]) - 273.15, digits = 3), "," ) end
            elseif logger.data_type == ["rh"]
                for i = 1 : length(logger.logging_data); print(logger.file[n], round(rh(logger.logging_data[i]), digits = 3), "," ) end
            elseif logger.data_type == ["pv"]
                for i = 1 : length(logger.logging_data); print(logger.file[n], round(pv(logger.logging_data[i]), digits = 5), "," ) end
            elseif logger.data_type == ["ah"]
                for i = 1 : length(logger.logging_data); print(logger.file[n], round(ah(logger.logging_data[i]), digits = 5), "," ) end
            elseif logger.data_type == ["miu"]
                for i = 1 : length(logger.logging_data); print(logger.file[n], round(miu(logger.logging_data[i]), digits = 5), "," ) end
            elseif logger.data_type == ["phi"]
                for i = 1 : length(logger.logging_data); print(logger.file[n], round(phi(logger.logging_data[i]), digits = 3), "," ) end
            elseif logger.data_type == ["temp","rh","ah"]
                for i = 1 : length(logger.logging_data)
                    print(logger.file[n], round(temp(logger.logging_data[i]) - 273.15, digits = 3), "," )
                    print(logger.file[n], round(rh(logger.logging_data[i]), digits = 3), "," ) 
                    print(logger.file[n], round(ah(logger.logging_data[i]), digits = 5), "," ) 
                end
            elseif logger.data_type == ["temp","rh","phi"]
                for i = 1 : length(logger.logging_data)
                    print(logger.file[n], round(temp(logger.logging_data[i]) - 273.15, digits = 3), "," )
                    print(logger.file[n], round(rh(logger.logging_data[i]), digits = 3), "," ) 
                    try print(logger.file[n], round(phi(logger.logging_data[i]), digits = 5), "," ) 
                    catch
                        print(logger.file[n], "Error", "," ) 
                    end
                end
            elseif logger.data_type == ["temp","rh","ah","phi"]
                for i = 1 : length(logger.logging_data)
                    print(logger.file[n], round(temp(logger.logging_data[i]) - 273.15, digits = 3), "," )
                    print(logger.file[n], round(rh(logger.logging_data[i]), digits = 3), "," ) 
                    print(logger.file[n], round(ah(logger.logging_data[i]), digits = 5), "," ) 
                    try print(logger.file[n], round(phi(logger.logging_data[i]), digits = 5), "," ) 
                    catch
                        print(logger.file[n], "Error", "," ) 
                    end
                end
            end       
        catch
            print(logger.file[n], "Error", "," ) 
        end
        println(logger.file[n])

    end

end 

function write_rawdata_to_logger( logger, data )
    for i = 1 : length(data)
        print(logger.file, data[i], "," )
    end
    println(logger.file)
end

function write_temp_to_logger( logger::Logger, date )
    print(logger.file, date, ",")
    for i = 1 : length(logger.logging_data)
        print(logger.file, round(temp(logger.logging_data[i]) - 273.15, digits = 2), "," )
    end
    println(logger.file)
end

function write_RH_to_logger( logger::Logger, date )
    print(logger.file, date, ",")
    for i = 1 : length(logger.logging_data)
        print(logger.file, round(rh(logger.logging_data[i]), digits = 2), "," )
    end
    println(logger.file)
end

function write_Pv_to_logger( logger::Logger, date )
    print(logger.file, date, ",")
    for i = 1 : length(logger.logging_data)
        print(logger.file, round(pv(logger.logging_data[i]), digits = 2), "," )
    end
    println(logger.file)
end

function write_Miu_to_logger( logger::Logger, date )
    print(logger.file, date, ",")
    for i = 1 : length(logger.logging_data)
        print(logger.file, round(miu(logger.logging_data[i]), digits = 2), "," )
    end
    println(logger.file)
end

function write_data_for_room_analysis( logger::Logger )

    network = logger.logging_data

    # 各部屋に対する計算
    for r = 1 : length(network.rooms)

        # 時刻の入力
        print( logger.file[r], Dates.format(network.climate.date, "yyyy/mm/dd HH:MM"), ",")

        # 各部屋の温湿度の入力
        print( logger.file[r],  temp(network.rooms[r])-273.15, ",")
        print( logger.file[r],  rh(network.rooms[r]), ",")
        print( logger.file[r],  ah(network.rooms[r]), ",")

        # インシデンス行列により壁と面するかの判定
        for i = 1 : length(network.walls)
            # 上流側の壁と面する場合
            if network.IC_walls[r,i] == 1
                qa = - cal_q( network.walls[i].target_model[1], network.walls[i].target_model[2])
                jv = - cal_jv( network.walls[i].target_model[1], network.walls[i].target_model[2])
                jl = - cal_jl( network.walls[i].target_model[1], network.walls[i].target_model[2], sin(network.walls[i].ION / (180.0/pi)))
                #println(" room = ", temp(network.walls[i].target_model[1])-273.15, " room = ", temp(network.walls[i].target_model[2])-273.15)
                #println(" r = ", r, " i = ",i, " qa = ",qa)
            elseif network.IC_walls[r,i] == -1
                qa = cal_q( network.walls[i].target_model[end-1], network.walls[i].target_model[end])
                jv = cal_jv( network.walls[i].target_model[end-1], network.walls[i].target_model[end])
                jl = cal_jl( network.walls[i].target_model[end-1], network.walls[i].target_model[end], sin(network.walls[i].ION / (180.0/pi)))
            else
                continue # 以下の動作をスキップ
            end
            print( logger.file[r],  temp(network.walls[i].target_model[2])-273.15, ",")
            print( logger.file[r],  rh(network.walls[i].target_model[2]), ",")
            print( logger.file[r],  ah(network.walls[i].target_model[2]), ",")
            print( logger.file[r],  area(network.walls[i]) * qa, ",")
            print( logger.file[r],  area(network.walls[i]) * jv, ",")
            print( logger.file[r],  area(network.walls[i]) * jl, ",")        
        end

        # インシデンス行列により部屋との換気が生じているかの判定
        for i = 1 : length(network.openings)
            # 空気の比熱容量：乾き空気＋水蒸気の比熱
            ca_IP   = 1005.0 + 1846.0 * ah(room_IP(network.openings[i]))
            ca_IM   = 1005.0 + 1846.0 * ah(room_IM(network.openings[i]))
            # 空気の密度：ボイルシャルルの法則より
            rho_IP  =  353.25 / temp(room_IP(network.openings[i]))
            rho_IM  =  353.25 / temp(room_IM(network.openings[i]))
            # 上流側に室がある場合
            if network.IC_openings[r,i] == 1 
                # 換気量の計算
                Qvent_in  =   Qup(network.openings[i]) * ca_IM  * rho_IM * temp(room_IM(network.openings[i]))
                Qvent_out = - Qdw(network.openings[i]) * ca_IP  * rho_IP * temp(room_IP(network.openings[i]))
                Jvent_in  =   Qup(network.openings[i]) * rho_IM * ah(room_IM(network.openings[i]))
                Jvent_out = - Qdw(network.openings[i]) * rho_IP * ah(room_IP(network.openings[i]))                
                print( logger.file[r],  temp(room_IM(network.openings[i]))-273.15, ",")
                print( logger.file[r],  rh(room_IM(network.openings[i])), ",")
                print( logger.file[r],  ah(room_IM(network.openings[i])), ",")
            # 下流側に室がある場合
            elseif network.IC_openings[r,i] == -1
                # 換気量の計算
                Qvent_in  =   Qdw(network.openings[i]) * ca_IP  * rho_IP * temp(room_IP(network.openings[i]))
                Qvent_out = - Qup(network.openings[i]) * ca_IM  * rho_IM * temp(room_IM(network.openings[i]))
                Jvent_in  =   Qdw(network.openings[i]) * rho_IP * ah(room_IP(network.openings[i]))              
                Jvent_out = - Qup(network.openings[i]) * rho_IM * ah(room_IM(network.openings[i]))
                print( logger.file[r],  temp(room_IP(network.openings[i]))-273.15, ",")
                print( logger.file[r],  rh(room_IP(network.openings[i])), ",")
                print( logger.file[r],  ah(room_IP(network.openings[i])), ",")
            else
                continue # 以下の動作をスキップ
            end
            print( logger.file[r],  Qvent_in + Qvent_out, ",")
            print( logger.file[r],  Jvent_in + Jvent_out, ",")
        end

        # 発熱源・発湿源
        print( logger.file[r],  H_in(network.rooms[r].air), ",")
        print( logger.file[r],  J_in(network.rooms[r].air), ",")

        println(logger.file[r])

    end

end