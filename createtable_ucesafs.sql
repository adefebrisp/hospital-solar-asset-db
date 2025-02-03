-- Dropping the existing schema and create new schema 

drop schema if exists ucesafs cascade;
create schema ucesafs;
 
-- create the hospital_buildings table 

create table ucesafs.hospital_buildings (
	hospital_buildings_id serial not null,
	building_name character varying (10) not null,
	address character varying (150) not null,
	year_established integer not null);
	
-- add the geometry column in hospital_buildings table

select AddGeometryColumn('ucesafs','hospital_buildings','location',27700,'geometry',3);

----------------------------------------------------------------------------

-- create the solar_panels table 

create table ucesafs.solar_panels (
	solar_panel_id serial not null,
	building_id integer not null,
	solar_panel_name character varying (50) not null, 
	installation_date date not null);

-- add the geometry column in solar_panels table

select AddGeometryColumn('ucesafs','solar_panels','location',27700,'polygon',3);

----------------------------------------------------------------------------

-- create the panel_temperature_sensors table 

create table ucesafs.panel_temperature_sensors (
	sensor_id serial not null,
	solar_panel_id integer not null,
	sensor_name character varying (50) not null,
	installation_date date not null);
	
-- add the geometry column in panel_temperature_sensors table

select AddGeometryColumn('ucesafs','panel_temperature_sensors','location',27700,'point',3);

----------------------------------------------------------------------------

-- create the solar_panel_values table 

create table ucesafs.solar_panel_values (
	solar_value_id serial not null,
	solar_panel_id integer not null,
	energy_output_watt double precision not null,
	output_date date not null);
	
----------------------------------------------------------------------------

-- create the temperature_sensor_values table 

create table ucesafs.temperature_sensor_values (
	temperature_value_id serial not null,
	panel_sensor_id integer not null,
	temperature_celcius double precision,
	record_date date not null);

----------------------------------------------------------------------------

-- create the panel_physical_indicator table 

create table ucesafs.panel_physical_indicator (
	physical_status_id serial not null,
	physical_status_description character varying (200) not null);
	
----------------------------------------------------------------------------

-- create the solar_panel_condition table 

create table ucesafs.solar_panel_condition (
	solar_panel_condition_id serial not null,
	solar_panel_id integer not null,
	physical_status integer not null,
	report_date date not null);
	
----------------------------------------------------------------------------	

-- create the parameters table
 
create table ucesafs.parameters (
	parameter_id serial not null,
	parameter_type character varying (50) not null,
	parameter_name character varying (50) not null,
	parameter_subname character varying (50) not null,
	parameter_value double precision not null,
	parameter_units character varying (50) not null,
	date_created date not null);