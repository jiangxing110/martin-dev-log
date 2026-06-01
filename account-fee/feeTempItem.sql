  -- 默认费率 0（无 provider，兜底）
  INSERT INTO fee_template_item (id, template_id, fee_name, channel, deduction_node, rate_type, rate_value, effective_time,expiration_time)
  VALUES (generate_snowflake_id(), 2054479724258758658, 'MonthlyActiveCardFee', NULL, 'monthly', 'fixed', 0, '2024-08-01', '2099-12-31');
  -- 各 provider 费率
  INSERT INTO fee_template_item (id, template_id, fee_name, channel, deduction_node, rate_type, rate_value, effective_time,expiration_time)
  VALUES (generate_snowflake_id(), 2054479724258758658, 'MonthlyActiveCardFee', 'QbitIssuing', 'monthly', 'fixed', 0.12, '2026-02-01','2099-12-31');

  INSERT INTO fee_template_item (id, template_id, fee_name, channel, deduction_node, rate_type, rate_value, effective_time, expiration_time)
  VALUES (generate_snowflake_id(), 2054479724258758658, 'MonthlyActiveCardFee', 'Slash', 'monthly', 'fixed', 0.10, '2026-02-01','2099-12-31');

  INSERT INTO fee_template_item (id, template_id, fee_name, channel, deduction_node, rate_type, rate_value, effective_time,expiration_time)
  VALUES (generate_snowflake_id(), 2054479724258758658, 'MonthlyActiveCardFee', 'BlueBanc', 'monthly', 'fixed', 0.12, '2026-02-01','2099-12-31');

  INSERT INTO fee_template_item (id, template_id, fee_name, channel, deduction_node, rate_type, rate_value, effective_time, expiration_time)
  VALUES (generate_snowflake_id(), 2054479724258758658, 'MonthlyActiveCardFee', 'I2c', 'monthly', 'fixed', 0.25, '2026-02-01', '2099-12-31');

  INSERT INTO fee_template_item (id, template_id, fee_name, deduction_node, rate_type, rate_value, effective_time,expiration_time)
  VALUES (generate_snowflake_id(), 2054479724258758658, 'KycInterfaceCallFee', 'monthly', 'fixed', 1.5, '2026-02-01', '2099-12-31');
	
	
	  -- 默认费率 0（无 provider，兜底）
  INSERT INTO fee_template_item (id, template_id, fee_name, channel, deduction_node, rate_type, rate_value, effective_time,expiration_time)
  VALUES (generate_snowflake_id(), 2054476247235284994, 'MonthlyActiveCardFee', NULL, 'monthly', 'fixed', 0, '2024-08-01', '2099-12-31');
  -- 各 provider 费率
  INSERT INTO fee_template_item (id, template_id, fee_name, channel, deduction_node, rate_type, rate_value, effective_time,expiration_time)
  VALUES (generate_snowflake_id(), 2054476247235284994, 'MonthlyActiveCardFee', 'QbitIssuing', 'monthly', 'fixed', 0.12, '2026-02-01','2099-12-31');

  INSERT INTO fee_template_item (id, template_id, fee_name, channel, deduction_node, rate_type, rate_value, effective_time, expiration_time)
  VALUES (generate_snowflake_id(), 2054476247235284994, 'MonthlyActiveCardFee', 'Slash', 'monthly', 'fixed', 0.10, '2026-02-01','2099-12-31');

  INSERT INTO fee_template_item (id, template_id, fee_name, channel, deduction_node, rate_type, rate_value, effective_time,expiration_time)
  VALUES (generate_snowflake_id(), 2054476247235284994, 'MonthlyActiveCardFee', 'BlueBanc', 'monthly', 'fixed', 0.12, '2026-02-01','2099-12-31');

  INSERT INTO fee_template_item (id, template_id, fee_name, channel, deduction_node, rate_type, rate_value, effective_time, expiration_time)
  VALUES (generate_snowflake_id(), 2054476247235284994, 'MonthlyActiveCardFee', 'I2c', 'monthly', 'fixed', 0.25, '2026-02-01', '2099-12-31');
	
  INSERT INTO fee_template_item (id, template_id, fee_name, deduction_node, rate_type, rate_value, effective_time,expiration_time)
  VALUES (generate_snowflake_id(), 2054476247235284994, 'KycInterfaceCallFee', 'monthly', 'fixed', 1.5, '2026-02-01', '2099-12-31');
	
	

 -- QuantumCardNotActiveFee（当前费率为 0）
  INSERT INTO fee_template_item (id, template_id, fee_name, deduction_node, rate_type, rate_value, effective_time,
  expiration_time)
  VALUES (generate_snowflake_id(), 2054476247235284994, 'QuantumCardNotActiveFee', 'monthly', 'fixed', 0, '2024-08-01', '2099-12-31');
	  INSERT INTO fee_template_item (id, template_id, fee_name, deduction_node, rate_type, rate_value, effective_time,
  expiration_time)
  VALUES (generate_snowflake_id(), 2054479724258758658, 'QuantumCardNotActiveFee', 'monthly', 'fixed', 0, '2024-08-01', '2099-12-31');

	