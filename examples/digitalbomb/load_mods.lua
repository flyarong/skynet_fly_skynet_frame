return {
	--共享配置
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			--room_game_login用的配置
			room_game_login = {
				--gate连接配置
				gateconf = {
					address = '0.0.0.0',
					port = 8001,
					maxclient = 2048,
				},
				--wsgate连接配置
				wsgateconf = {
					address = '0.0.0.0',
					port = 8002,
					maxclient = 2048,
				},
				login_plug = "login.login_plug",
			},

			server_cfg = {
				loglevel = "info",
			}
		}
	},

	--大厅服
	room_game_hall_m = {
		launch_seq = 2,
		launch_num = 6,
		default_arg = {
			hall_plug = "hall.hall_plug",
		}
	},

	--桌子分配服
	room_game_alloc_m = {
		launch_seq = 3,
		launch_num = 1,
		default_arg = {
			alloc_plug = "alloc.alloc_plug",
			MAX_TABLES = 10000,				--最多创建1万个桌子
			max_empty_time = 60,            --空置一分钟就解散
		}
	},

	--桌子服
	room_game_table_m = {
		launch_seq = 4,
		launch_num = 6,
		mod_args = {
			{instance_name = "room_1", table_plug = "table.table_plug2", table_conf = {player_num = 2,}},
			{instance_name = "room_2", table_plug = "table.table_plug2", table_conf = {player_num = 2,}},
			{instance_name = "room_3", table_plug = "table.table_plug2", table_conf = {player_num = 2,}},
			{instance_name = "room_4", table_plug = "table.table_plug2", table_conf = {player_num = 2,}},
			{instance_name = "room_5", table_plug = "table.table_plug2", table_conf = {player_num = 2,}},
			{instance_name = "room_6", table_plug = "table.table_plug2", table_conf = {player_num = 2,}},
		},
	},

	--测试客户端
	client_m = {
		launch_seq = 5,
		launch_num = 2,
		delay_run = true,       --延迟运行
		mod_args = {
			{account = "skynet",password = '123456',player_id = 10000, protocol = "websocket"},
			{account = "skynet_fly",password = '123456',player_id = 10001, protocol = "socket"},
		}
	}
}