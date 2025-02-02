-- Primary Key --

-- hospital_buildings table 
alter table ucesafs.hospital_buildings add constraint hospital_buildings_pk primary key (hospital_buildings_id);

-- solar_panels table
alter table ucesafs.solar_panels add constraint solar_panels_pk primary key (solar_panel_id);

-- panel_temperature_sensors table
alter table ucesafs.panel_temperature_sensors add constraint panel_temperature_sensors_pk primary key (sensor_id);

-- solar_panel_values table
alter table ucesafs.solar_panel_values add constraint solar_panel_values_pk primary key (solar_value_id);

-- temperature_sensor_values table 
alter table ucesafs.temperature_sensor_values add constraint temperature_sensor_values_pk primary key (temperature_value_id);

-- solar_panel_condition table 
alter table ucesafs.solar_panel_condition add constraint solar_panel_condition_pk primary key (solar_panel_condition_id);

-- panel_physical_indicator table 
alter table ucesafs.panel_physical_indicator add constraint panel_physical_indicator_pk primary key (physical_status_id);

-- parameters table 
alter table ucesafs.parameters add constraint parameters_pk primary key (parameter_id);

--==================================================================

-- Foreign Key --

-- solar_panels table
alter table ucesafs.solar_panels add constraint solarpanels_hospitalbuildings_fk foreign key (building_id) references ucesafs.hospital_buildings (hospital_buildings_id);

-- panel_temperature_sensors table
alter table ucesafs.panel_temperature_sensors add constraint panelsensor_solarpanel_fk foreign key (solar_panel_id) references ucesafs.solar_panels (solar_panel_id);

-- solar_panel_values table
alter table ucesafs.solar_panel_values add constraint panelvalues_solarpanel_fk foreign key (solar_panel_id) references ucesafs.solar_panels (solar_panel_id);

-- temperature_sensor_values
alter table ucesafs.temperature_sensor_values add constraint temperaturevalues_sensor_fk foreign key (panel_sensor_id) references ucesafs.panel_temperature_sensors (sensor_id);

-- solar_panel_condition table 
alter table ucesafs.solar_panel_condition add constraint panelcondition_physical_fk foreign key (physical_status) references ucesafs.panel_physical_indicator(physical_status_id);

--==================================================================

-- Check Constraint --

/* solar_panel_values table (energy_output_watt <= 300) */

alter table ucesafs.solar_panel_values add constraint output_watt_check check (energy_output_watt <= 300);

--==================================================================

-- Unique Constraint --

-- hospital_buildings table 
alter table ucesafs.hospital_buildings add constraint hospital_buildings_unique unique (building_name, location);

-- solar_panels table
alter table ucesafs.solar_panels add constraint solar_panels_unique unique (location);

-- panel_temperature_sensors table
alter table ucesafs.panel_temperature_sensors add constraint panel_temperature_sensors_unique unique (location);

-- solar_panel_values table
alter table ucesafs.solar_panel_values add constraint solar_panel_values_unique unique (solar_panel_id, output_date);

-- temperature_sensor_values table
alter table ucesafs.temperature_sensor_values add constraint sensor_values_unique unique (panel_sensor_id, record_date);

-- solar_panel_condition table
alter table ucesafs.solar_panel_condition add constraint panel_condition_unique unique (solar_panel_id, report_date); 

-- panel_physical_indicator table
alter table ucesafs.panel_physical_indicator add constraint physical_indicator_unique unique (physical_status_description);

-- parameter table
alter table ucesafs.parameters add constraint parameters_unique unique (parameter_type, parameter_name, parameter_subname, date_created);