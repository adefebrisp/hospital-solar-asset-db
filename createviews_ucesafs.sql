-- create latest parameters view

drop view if exists ucesafs.latest_parameters cascade;

create view ucesafs.latest_parameters as

-- 1. Find the latest parameter record using a group by statement
with 
latest_parameters as
(select parameter_type, parameter_name, parameter_subname,  max(date_created) as date_created
from ucesafs.parameters
group by parameter_type, parameter_name, parameter_subname)

-- 2. Inner join to get the rest of the parameter details
select a.parameter_id, a.parameter_value, b.* from ucesafs.parameters a inner join 
latest_parameters b
on a.parameter_type = b.parameter_type
and a.parameter_name = b.parameter_name
and a.parameter_subname = b.parameter_subname 
and a.date_created = b.date_created;

--===========================================================================================
-- Create a view to get details of the error sensor(required for decision A2) - Lower Level

drop view if exists ucesafs.sensor_error cascade;

create view ucesafs.sensor_error as

-- 1. Get the replacement year of panel_temperature_sensors from the parameters table.
with
temperature_sensor_renewal as (
select parameter_value from ucesafs.latest_parameters 
where parameter_type = 'renewal' and 
parameter_name = 'panel_temperature_sensors' and 
parameter_subname = 'replacement_age'),

-- 2. Get the sensor that is more than 5 years old.
age_over_5years as (
select sensor_id from ucesafs.panel_temperature_sensors
where EXTRACT(YEAR FROM date_trunc('YEAR', age(now(), installation_date)))::double precision > (select parameter_value from temperature_sensor_renewal)),

-- 3. Count the number of null temperature values from each sensor.
null_temp as (select panel_sensor_id, count(*) as number_null from ucesafs.temperature_sensor_values 
where temperature_celcius is null group by panel_sensor_id),

-- 4. Join the previous tables of age_over_5years and null_temp, then put the name 'sensor_null_old' for the new table.
sensor_null_old as (
select a.*, c.number_null, d.solar_panel_id, d.solar_panel_name, e.hospital_buildings_id, e.building_name from ucesafs.panel_temperature_sensors a
inner join age_over_5years b on a.sensor_id = b.sensor_id
inner join null_temp c on b.sensor_id = c.panel_sensor_id
inner join ucesafs.solar_panels d on a.solar_panel_id = d.solar_panel_id
inner join ucesafs.hospital_buildings e on d.building_id = e.hospital_buildings_id),

-- 5. Get the details of the temperature value at each sensor.
temp_value as (
select panel_sensor_id, temperature_celcius, record_date
from ucesafs.temperature_sensor_values),

-- 6. Join table of sensor_null_old and temp_value
sensor_details as (
select a.*, b.* from sensor_null_old a 
inner join temp_value b on a.sensor_id = b.panel_sensor_id),

-- 7. Get the value of the maximum temperature that indicates an error in the sensor from the parameters table.
max_temp_error as (
select parameter_value from ucesafs.latest_parameters 
where parameter_type = 'error' and 
parameter_name = 'panel_temperature_sensors' and 
parameter_subname = 'max_temp'),

-- 8. Get the value of the minimum temperature that indicates an error in the sensor from the parameters table.
min_temp_error as (
select parameter_value from ucesafs.latest_parameters
where parameter_type = 'error' and 
parameter_name = 'panel_temperature_sensors' and 
parameter_subname = 'min_temp')

-- 9. Get all the details of the error sensor, including the number of null values, the error temperature value, and the first time the error temperature value is recorded.
select distinct on (sensor_id) sensor_id, sensor_name, installation_date, number_null, 
temperature_celcius as temperature_error_value, record_date as first_error_record_date, solar_panel_name, building_name, hospital_buildings_id, location from sensor_details where 
temperature_celcius > (select parameter_value from max_temp_error) 
or temperature_celcius < (select parameter_value from min_temp_error) or temperature_celcius is null;

--=========================================================================================================
-- Create a view to get details of the panels that require renewal(required for decision A1)-- Middle Level

drop view if exists ucesafs.solar_panel_renewal cascade;

create view ucesafs.solar_panel_renewal as

-- 1. Get the value of the maximum temperature that indicates an overheat in the in-roof solar panel from the parameters table.
with
max_temp_overheat as (
select parameter_value from ucesafs.latest_parameters 
where parameter_type = 'overheat' and 
parameter_name = 'solar_panels' and 
parameter_subname = 'max_temp'),

-- 2. Get the value of the minimum temperature that indicates an overheat in the in-roof solar panel from the parameters table.
min_temp_overheat as (
select parameter_value from ucesafs.latest_parameters 
where parameter_type = 'overheat' and 
parameter_name = 'solar_panels' and 
parameter_subname = 'min_temp'),

-- 3. Get the value of the maximum number of overheatings for in-roof solar panels from the parameters table.
overheat as (
select parameter_value from ucesafs.latest_parameters 
where parameter_type = 'overheat' and 
parameter_name = 'solar_panels' and 
parameter_subname = 'number_of_overheating'),

-- 4. Get the replacement year of solar_panels from the parameters table.
solar_panel_renewal as (
select parameter_value from ucesafs.latest_parameters 
where parameter_type = 'renewal' and 
parameter_name = 'solar_panels' and 
parameter_subname = 'replacement_age'),

-- 5. Count the number of overheatings for each solar panel.
panel_overheat as (
select panel_sensor_id, count(*) as number_overheat from ucesafs.temperature_sensor_values where 
temperature_celcius > (select parameter_value from min_temp_overheat) and 
temperature_celcius < (select parameter_value from max_temp_overheat) group by panel_sensor_id order by panel_sensor_id),

-- 6. Get the in-roof solar panel that has a number of overheatings that exceed the maximum threshold. 
panel_overheat_many_times as (
select a.solar_panel_id, a.sensor_id, b.* from ucesafs.panel_temperature_sensors a 
inner join panel_overheat b on a.sensor_id = b.panel_sensor_id where number_overheat >= (select parameter_value from overheat)),

-- 7. Get the in-roof solar panel that is more than 5 years old.
age_over_5years as (
select solar_panel_id from ucesafs.solar_panels
where EXTRACT(YEAR FROM date_trunc('YEAR', age(now(), installation_date)))::double precision > (select parameter_value from solar_panel_renewal)),

-- 8. Get the id of condition = Poor - cracks, significant scratches, moderate soiling, renewal required
require_renewal_status as (select physical_status_id from ucesafs.panel_physical_indicator where physical_status_description like '%Poor%'),

-- 9. Get the solar panel that has an average condition that is equal to or more than "Poor - cracks, significant scratches, moderate soiling, renewal required."
panel_require_renewal as (
select solar_panel_id, avg(physical_status)::INTEGER as average_physical from 
ucesafs.solar_panel_condition group by solar_panel_id having avg(physical_status) >= (select physical_status_id from require_renewal_status)),

-- 10. Adding a description of physical status to table panel_require_renewal using join 
insert_condition as 
(select a.solar_panel_id, b.physical_status_description as panel_condition from panel_require_renewal a inner join ucesafs.panel_physical_indicator b 
on a.average_physical = b.physical_status_id),

-- 11. Joining all of the previous tables to get details of panels that require renewal
panel_details as (
select a.solar_panel_id, a.solar_panel_name, d.panel_condition as average_panel_condition, e.number_overheat, a.installation_date, f.building_name, f.hospital_buildings_id, a.location 
from ucesafs.solar_panels a inner join age_over_5years b on a.solar_panel_id = b.solar_panel_id 
inner join panel_require_renewal c on b.solar_panel_id = c.solar_panel_id 
inner join insert_condition d on c.solar_panel_id = d.solar_panel_id 
inner join panel_overheat_many_times e on d.solar_panel_id = e.solar_panel_id
inner join ucesafs.hospital_buildings f on a.building_id = f.hospital_buildings_id)

select * from panel_details;

--=============================================================================================================
-- Create a view to get details of annual energy production from hospital(required for decision E2)-- Top Level

drop view if exists ucesafs.annual_energy_production cascade;

create view ucesafs.annual_energy_production as

-- 1. Get the value of the annual electricity consumption from the parameters table.
with
annual_electricity_consumption as (
select parameter_value from ucesafs.latest_parameters 
where parameter_type = 'electricity' and 
parameter_name = 'hospital_buildings' and 
parameter_subname = 'annual_electricity_consumption'),

-- 2. Get the value of the annual solar electricity percentage cover target from the parameters table.
annual_electricity_target as (
select parameter_value from ucesafs.latest_parameters 
where parameter_type = 'electricity' and 
parameter_name = 'solar_electricity_target' and 
parameter_subname = 'annual_percentage_cover'),

-- 3. Calculate the total energy produced by each year.
energy_produce as (select date_part('year', output_date) as year, sum(energy_output_watt)/1000 as total_energy_produces_in_kWH 
from ucesafs.solar_panel_values group by date_part('year', output_date) order by date_part('year', output_date))

-- 4. Calculate the percentage of the electricity covered and give information on whether to install more in-roof solar panels or not.
select a.*, round(((select a.total_energy_produces_in_kWH / (select parameter_value from annual_electricity_consumption))*100)::numeric ,1) as electricity_percentage_cover_from_solar_panels, 
round(((select a.total_energy_produces_in_kWH / (select parameter_value from annual_electricity_consumption))*100)::numeric ,1) < (select parameter_value from annual_electricity_target) as install_more_solar_panels
from energy_produce a;

--=================================================================================================================
-- Create a view to get details of total energy production from each building(required for decision E1)-- Top Level

drop view if exists ucesafs.energy_production_per_building cascade;

create view ucesafs.energy_production_per_building as

-- 1. Calculate the total energy produced by each in-roof solar panel.
with 
average as (select solar_panel_id, sum(energy_output_watt) as sum_output from ucesafs.solar_panel_values group by solar_panel_id),

-- 2. Join table solar panels and table average.

src as (select a.solar_panel_name, a.building_id, b.sum_output, a.location from ucesafs.solar_panels a inner join average b on a.solar_panel_id = b.solar_panel_id),

-- 3. Calculate the total amount of solar energy (kWh) produced per building.
total_building as (select src.building_id, (sum(src.sum_output))/1000 as total_output_building_in_kWh from src group by building_id),

-- 4. Get the details of the building and assign the total energy output per building. 
building as (select a.hospital_buildings_id, a.building_name, a.address, a.year_established, b.total_output_building_in_kWh, a.location from ucesafs.hospital_buildings a 
inner join total_building b on a.hospital_buildings_id = b.building_id)

select * from building;

-- =======================================================================================================================
-- ======================================= The views for the 3 levels of pyramid nesting =================================

--------------------------------------------------------------------------------------------------------------------------
-- create a view to calculate the cost of replacing panel_temperature_sensors per sensor (required for decision B3) 
--------------------------------------------------------------------------------------------------------------------------
drop view if exists ucesafs.cost_sensor_renewal cascade;

create view ucesafs.cost_sensor_renewal as 

-- 1. List the error panel temperature sensor from ucesafs.sensor_error.
with
list_sensor as (select * from ucesafs.sensor_error),

-- 2. Count the number.
count_sensor as (
select sensor_id, count(*) as num_sensor from ucesafs.sensor_error group by sensor_id),

-- 3. Get the price of panel_temperature_sensors from the parameters table. 
sensor_price as (
select parameter_value from ucesafs.latest_parameters 
where parameter_type = 'cost' and 
parameter_name = 'panel_temperature_sensors' and 
parameter_subname = 'price'),

-- 4. Calculate the sensor renewal cost. 
sensor_cost as (
select sensor_id, ((select parameter_value from sensor_price) * num_sensor) as cost_sensor_in_pounds from count_sensor)

-- 5. Link back to the panel_temperature_sensors table.
select b.sensor_id, (case when a.cost_sensor_in_pounds is null then 0 else a.cost_sensor_in_pounds end) as cost_per_sensor_in_pounds, b.sensor_name, 
b.installation_date, b.location, b.solar_panel_id from sensor_cost a
right join ucesafs.panel_temperature_sensors b on a.sensor_id = b.sensor_id order by cost_per_sensor_in_pounds DESC;

---------------------------------------------------------------------------------------------------------------------------------------------------------
-- Create a view to calculate the cost of replacing the in-roof solar panel per panel, including the sensor that lies on it. (required for decision B2) 
---------------------------------------------------------------------------------------------------------------------------------------------------------

drop view if exists ucesafs.total_cost_solar_panel_renewal cascade;

create view ucesafs.total_cost_solar_panel_renewal as 

-- 1. List the number of solar panels that need renewal from ucesafs.solar_panel_renewal.
with
list_solar_panel as (select * from ucesafs.solar_panel_renewal),

-- 2. Count the number.
count_solar_panel as (
select solar_panel_id, count(*) as num_solar_panel from ucesafs.solar_panel_renewal group by solar_panel_id),

-- 3. Get the price of panel_temperature_sensors from the parameters table. 
solar_panels_price as (
select parameter_value from ucesafs.latest_parameters 
where parameter_type = 'cost' and 
parameter_name = 'solar_panels' and 
parameter_subname = 'price'),

-- 4. Calculate the solar panel renewal cost.
panel_cost as (
select solar_panel_id, ((select parameter_value from solar_panels_price) * a.num_solar_panel) as cost_solar_panel_in_pounds from count_solar_panel a),

-- 5. Link back to the solar_panels table.
solar_panel_cost_details as (select b.solar_panel_id, (case when a.cost_solar_panel_in_pounds is null then 0 else a.cost_solar_panel_in_pounds end) as cost_solar_panel_in_pounds, 
b.solar_panel_name, b.installation_date, b.location, b.building_id from panel_cost a 
right join ucesafs.solar_panels b on a.solar_panel_id = b.solar_panel_id)

-- 6. Sum all costs from the bottom level to the middle level (using lower-level views ucesafs.cost_sensor_renewal)
select b.solar_panel_id, (a.cost_per_sensor_in_pounds + b.cost_solar_panel_in_pounds) as total_cost_per_panel_in_pounds, b.solar_panel_name, 
b.installation_date, b.location, b.building_id from ucesafs.cost_sensor_renewal a inner join solar_panel_cost_details b on a.solar_panel_id = b.solar_panel_id 
order by total_cost_per_panel_in_pounds DESC;

---------------------------------------------------------------------------------------------------------------------------------------------------------
-- Create a view to calculate the total renewal cost per building, including the total cost of the solar panel and sensor.(required for decision B1) 
---------------------------------------------------------------------------------------------------------------------------------------------------------

drop view if exists ucesafs.total_renewal_cost_per_building cascade;

create view ucesafs.total_renewal_cost_per_building as 

-- 1. Calculate the total cost per building using input from the middle-level view (ucesafs.total_cost_solar_panel_renewal)
with
total_cost_per_building as (select building_id, sum(total_cost_per_panel_in_pounds) as total_cost_per_building_in_pounds 
from ucesafs.total_cost_solar_panel_renewal group by building_id),

-- 2. Get the budget for renewal per building from the parameters table.
renewal_budget_per_building as (
select parameter_value from ucesafs.latest_parameters
where parameter_type = 'budget' and 
parameter_name = 'hospital_buildings' and 
parameter_subname = 'total_budget_for_renewal_per_building')

-- 3. Link back to the hospital_buildings table.
select a.hospital_buildings_id, a.building_name, b.total_cost_per_building_in_pounds, (select parameter_value from renewal_budget_per_building) as total_renewal_budget_per_building_in_pounds,
((select parameter_value from renewal_budget_per_building)- b.total_cost_per_building_in_pounds) as remaining_budget_in_pounds, ((select parameter_value from renewal_budget_per_building)- b.total_cost_per_building_in_pounds)/(select parameter_value from renewal_budget_per_building)*100 as percent_of_remaining_budget, 
a.address, a.year_established, a.location from total_cost_per_building b right join ucesafs.hospital_buildings a on a.hospital_buildings_id = b.building_id; 













































