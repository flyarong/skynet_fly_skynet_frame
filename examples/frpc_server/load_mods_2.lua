return {
	--共享配置
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			--frpc_server用的配置
			frpc_server = {
				host = "127.0.0.1:9689",
				--gate连接配置
				gateconf = {
					address = '127.0.0.1',
					port = 9689,
					maxclient = 2048,
				},
				secret_key = "safdsifuhiu34yjfindskj43hqfo32yosd",
				is_encrypt = true,
			},

			server_cfg = {
				svr_id = 2,
				debug_port = 9002,
				logpath = './logs_2/',
			}
		},
	},

	test_m = {
		launch_seq = 2,
		launch_num = 6,
		mod_args = {
			{instance_name = "test_one"},
			{instance_name = "test_one"},
			{instance_name = "test_one"},
			{instance_name = "test_two"},
			{instance_name = "test_two"},
			{instance_name = "test_two"},
		}
	}
}