--Create temporary schema to store the transformed data.
--There is no required fields in temporary schema in order to facility the data transformation.
--The OMOP schema must be built first! (The public schema in codes is the OMOP CDM schema)

create schema public_temp;
set search_path = public_temp;

--5.Transforming drug_exposure table
--5.1.导入drug_exposure_id, person_id, drug_concept_id, lot_number, drug_source_value, route_source_value, dose_unit_source_value
--lot_number, drug_source_value长度不够，改为不定长
drop table if exists drug_exposure;
create table drug_exposure as 
(select * from public.drug_exposure limit 0);

drop sequence if exists drug_exposure_id_seq;
create sequence drug_exposure_id_seq
    start with 1
    increment by 1
    no minvalue
    no maxvalue
    cache 1;

alter table drug_exposure alter column drug_exposure_id set default nextval('drug_exposure_id_seq');
alter table drug_exposure add column drug_exposure_source_id bigint;
alter table drug_exposure alter lot_number type varchar;
alter table drug_exposure alter drug_source_value type varchar;

truncate table drug_exposure;
insert into drug_exposure
(drug_exposure_source_id, person_id, drug_concept_id, lot_number, drug_source_value, route_source_value, dose_unit_source_value)
(select cast((primaryid || drug_seq) as bigint), 
 cast(caseid as int), 
 standard_concept_id,
 lot_num,
 drugname,
 route,
 dose_unit
from standard_faers.standard_drug);

--5.2.规范化并选择单方剂量(不包括复方剂量)，并导入effective_drug_dose
update standard_faers.standard_drug 
set dose_amt = trim(dose_amt);

update standard_faers.standard_drug
set dose_amt = regexp_replace(dose_amt, '\t', '')
where dose_amt ~ '\t';

update standard_faers.standard_drug
set dose_amt = replace(dose_amt,',','')
where dose_amt ~ '^[0-9]+\,[0-9][0-9][0-9]' and dose_amt !~ '\/' and dose_amt !~ '\-';

update standard_faers.standard_drug
set dose_amt = cast(cast(regexp_replace(dose_amt, '[A-Za-z]+', '') as numeric) * 1000000 as varchar)
where dose_amt ~ 'MIL' and dose_amt !~ '\/' and dose_amt !~ '\-';

update standard_faers.standard_drug
set dose_amt = regexp_replace(dose_amt, '[A-Za-z]+', '')
where dose_amt ~ '^[0-9]+\.*[0-9]*\s*MG' and dose_amt !~ '\/' and dose_amt !~ '\-';

update standard_faers.standard_drug
set dose_amt = ('0' || dose_amt)
where dose_amt ~ '^\.[0-9]+\.*[0-9]*$';

update standard_faers.standard_drug
set dose_amt = replace(dose_amt,'.','')
where dose_amt ~ '\.$' and dose_amt !~ '\/' and dose_amt !~ '\-';

update standard_faers.standard_drug
set dose_amt = regexp_replace(dose_amt,'\.\.+','\.')
where dose_amt ~ '\.\.+' and dose_amt !~ '\/' and dose_amt !~ '\-';

drop index if exists drug_exposure_index;
create index drug_exposure_index on drug_exposure(drug_exposure_source_id);

alter table standard_faers.standard_drug
add column drug_exposure_id bigint;

update standard_faers.standard_drug
set drug_exposure_id = cast((primaryid || drug_seq) as bigint)

drop index if exists standard_faers.standard_drug_index;
create index standard_drug_index on standard_faers.standard_drug(drug_exposure_id);

--about 10min
update drug_exposure a
set effective_drug_dose = cast(b.dose_amt as numeric)
from standard_faers.standard_drug b
where (dose_amt ~ '^[0-9]+\.*[0-9]+$' or dose_amt ~ '^[0-9]+$') 
and dose_amt !~ '\/' and dose_amt !~ '\-'
and dose_amt is not null
and a.drug_exposure_source_id = b.drug_exposure_id;

--5.3.导入drug_type_concept_id(44787730,Patient Self-Reported Medication)
update drug_exposure
set drug_type_concept_id = '44787730';

--5.4.导入route_concept_id
alter table standard_faers.standard_drug
add column route_temp int;

update standard_faers.standard_drug a 
set route_temp = 
	case when a.route = 'Auricular (otic)' then 4023156
	when a.route = 'INTRA-AURAL' then 4023156
	when a.route = 'BUCCAL' then 4181897
	when a.route = 'Buccal' then 4181897
	when a.route = 'CUTANEOUS' then 4263689
	when a.route = 'Cutaneous' then 4263689
	when a.route = 'Dental' then 4163765
	when a.route = 'DENTAL' then 4163765
	when a.route = 'ENDOCERVICAL' then 4186831
	when a.route = 'Endocervical' then 4186831
	when a.route = 'Endotracheal' then 4186832
	when a.route = 'ENDOTRACHEAL' then 4186832
	when a.route = 'Epidural' then 4225555
	when a.route = 'EPIDURAL' then 4225555
	when a.route = 'EXTRA-AMNIOTIC' then 4186833
	when a.route = 'GASTROSTOMY TUBE' then 4186834
	when a.route = 'HEMODIALYSIS' then 4228125
	when a.route = 'Hemodialysis' then 4228125
	when a.route = 'INHALATION' then 4011083
	when a.route = 'Respiratory (inhalation)' then 4011083
	when a.route = 'Intra-amniotic' then 4163767
	when a.route = 'INTRA-AMNIOTIC' then 4163767
	when a.route = 'INTRA-ARTERIAL' then 4240824
	when a.route = 'Intra-arterial' then 4240824
	when a.route = 'INTRA-ARTICULAR' then 4006860
	when a.route = 'Intra-articular' then 4006860
	when a.route = 'INTRA-BURSAL' then 4163768
	when a.route = 'Intra-uterine' then 4269621
	when a.route = 'INTRAUTERINE' then 4269621
	when a.route = 'INTRACARDIAC' then 4156705
	when a.route = 'Intracardiac' then 4156705
	when a.route = 'INTRACAVERNOSA' then 4157757
	when a.route = 'Intracavernous' then 4157757
	when a.route = 'Intracervical' then 4186835
	when a.route = 'INTRA-CERVICAL' then 4186835
	when a.route = 'Intracoronary' then 4186836
	when a.route = 'INTRACORONARY' then 4186836
	when a.route = 'Intradermal' then 4156706
	when a.route = 'INTRADERMAL' then 4156706
	when a.route = 'INTRADISCAL' then 4163769
	when a.route = 'Intradiscal (intraspinal)' then 4163769
	when a.route = 'Intralesional' then 4157758
	when a.route = 'Intralymphatic' then 4157759
	when a.route = 'INTRALYMPHATIC' then 4157759
	when a.route = 'INTRAMUSCULAR' then 4302612
	when a.route = 'Intramuscular' then 4302612
	when a.route = 'INTRAOCULAR' then 4157760
	when a.route = 'Intraocular' then 4157760
	when a.route = 'Intraperitoneal' then 4243022
	when a.route = 'INTRAPERITONEAL' then 4243022
	when a.route = 'INTRAPLEURAL' then 4156707
	when a.route = 'Intrapleural' then 4156707
	when a.route = 'INTRATHECAL' then 4217202
	when a.route = 'Intrathecal' then 4217202
	when a.route = 'INTRAVENOUS' then 4112421
	when a.route = 'INTRAVENOUS DRIP' then 4112421
	when a.route = 'Intravenous drip' then 4112421
	when a.route = 'Intravenous bolus' then 4112421
	when a.route = 'INTRAVENOUS BOLUS' then 4112421
	when a.route = 'Intravenous (not otherwise specified)' then 4112421
	when a.route = 'INTRAVENTRICULAR' then 4222259
	when a.route = 'INTRAVESICAL' then 4186838
	when a.route = 'Intravesical' then 4186838
	when a.route = 'Iontophoresis' then 4302956
	when a.route = 'IONTOPHORESIS' then 4302956
	when a.route = 'NASAL' then 4128792
	when a.route = 'Nasal' then 4128792
	when a.route = 'ORAL' then 4128794
	when a.route = 'Oral' then 4128794
	when a.route = 'PARENTERAL' then 40491411
	when a.route = 'Parenteral' then 40491411
	when a.route = 'PERIARTICULAR' then 4156708
	when a.route = 'Periarticular' then 4156708
	when a.route = 'PERINEURAL' then 4157761
	when a.route = 'Perineural' then 4157761
	when a.route = 'RECTAL' then 4115462
	when a.route = 'Rectal' then 4115462
	when a.route = 'SUBCONJUNCTIVAL' then 4163770
	when a.route = 'Sunconjunctival' then 4163770
	when a.route = 'Subcutaneous' then 4139962
	when a.route = 'SUBCUTANEOUS' then 4139962
	when a.route = 'SUBLINGUAL' then 4292110
	when a.route = 'Sublingual' then 4292110
	when a.route = 'Topical' then 4231622
	when a.route = 'TOPICAL' then 4231622
	when a.route = 'Transdermal' then 4262099
	when a.route = 'TRANSDERMAL' then 4262099
	when a.route = 'URETHRAL' then 4233974
	when a.route = 'Urethral' then 4233974
	when a.route = 'VAGINAL' then 4057765
	when a.route = 'Vaginal' then 4057765
	else null
	end
where a.route is not null;

--10mins
update drug_exposure a
set route_concept_id = b.route_temp
from standard_faers.standard_drug b
where a.drug_exposure_source_id = b.drug_exposure_id
and b.route_temp is not null;

--5.5.导入dose_unit_concept_id
alter table standard_faers.standard_drug
add column unit_temp int;

update standard_faers.standard_drug 
set dose_unit = trim(dose_unit)
where dose_unit is not null

update standard_faers.standard_drug a 
set unit_temp = 
	case when a.dose_unit = 'G' then 8504
	when a.dose_unit = 'GM' then 8504
	when a.dose_unit = 'GRAM' then 8504
	when a.dose_unit = 'GRAMS' then 8504
	when a.dose_unit = 'HR' then 8505
	when a.dose_unit = 'UNITS' then 8510
	when a.dose_unit = 'U' then 8510
	when a.dose_unit = 'UNIT' then 8510
	when a.dose_unit = 'DAY' then 8512
	when a.dose_unit = 'L' then 8519
	when a.dose_unit = 'LITERS' then 8519
	when a.dose_unit = 'PCT' then 8554
	when a.dose_unit = 'PG' then 8564
	when a.dose_unit = 'MG' then 8576
	when a.dose_unit = 'MG.' then 8576
	when a.dose_unit = 'MGM' then 8576
	when a.dose_unit = 'MGS' then 8576
	when a.dose_unit = 'MG	' then 8576
	when a.dose_unit = 'ML' then 8587
	when a.dose_unit = 'ML (CC)' then 8587
	when a.dose_unit = 'ML;' then 8587
	when a.dose_unit = 'ML.' then 8587
	when a.dose_unit = 'M**2' then 8617
	when a.dose_unit = 'U/G' then 8629
	when a.dose_unit = 'G/L' then 8636
	when a.dose_unit = 'MG/D' then 8700
	when a.dose_unit = 'MG/DAY' then 8700
	when a.dose_unit = 'IU' then 8718
	when a.dose_unit = 'UG/G' then 8720
	when a.dose_unit = 'MG/G' then 8723
	when a.dose_unit = 'MG/G' then 8723
	when a.dose_unit = 'UG/L' then 8748
	when a.dose_unit = 'UMOL/L' then 8749
	when a.dose_unit = 'U/ML' then 8763
	when a.dose_unit = 'UNITS/ML' then 8763
	when a.dose_unit = 'MCG/MIN' then 8774
	when a.dose_unit = 'UG/MIN' then 8774
	when a.dose_unit = 'ML/MIN' then 8795
	when a.dose_unit = 'UG/MG' then 8838
	when a.dose_unit = 'NG/ML' then 8842
	when a.dose_unit = 'UG/ML' then 8859
	when a.dose_unit = 'MCG/ML' then 8859
	when a.dose_unit = 'MG/ML' then 8861
	when a.dose_unit = 'MG//ML' then 8861
	when a.dose_unit = 'MCG/DAY' then 8906
	when a.dose_unit = 'UG/DAY' then 8906
	when a.dose_unit = 'MCG/D' then 8906
	when a.dose_unit = 'IU/ML' then 8985
	when a.dose_unit = 'OTH' then 9177
	when a.dose_unit = 'GTT' then 9296
	when a.dose_unit = 'DROP' then 9296
	when a.dose_unit = 'DROPS' then 9296
	when a.dose_unit = 'IU/G' then 9333
	when a.dose_unit = 'IU/GM' then 9333
	when a.dose_unit = 'IU/KG' then 9335
	when a.dose_unit = 'OZ' then 9372
	when a.dose_unit = 'OUNCE' then 9372
	when a.dose_unit = 'OZ.' then 9372
	when a.dose_unit = 'PPM' then 9387
	when a.dose_unit = 'USP' then 9418
	when a.dose_unit = 'TABLET' then 9431
	when a.dose_unit = 'TAB' then 9431
	when a.dose_unit = 'TABS' then 9431
	when a.dose_unit = 'TABLETS' then 9431
	when a.dose_unit = 'MIU' then 9439
	when a.dose_unit = 'MILLION IU' then 9439
	when a.dose_unit = 'BQ' then 9469
	when a.dose_unit = 'CG' then 9479
	when a.dose_unit = 'CI' then 9480
	when a.dose_unit = 'DG' then 9485
	when a.dose_unit = 'G/KG' then 9512
	when a.dose_unit = 'GM/KG' then 9512
	when a.dose_unit = 'G/M2' then 9513
	when a.dose_unit = 'G/M^2' then 9513
	when a.dose_unit = 'G/M**2' then 9513
	when a.dose_unit = 'GM/M**2' then 9513
	when a.dose_unit = 'GM/M2' then 9513
	when a.dose_unit = 'GM/ML' then 9514
	when a.dose_unit = 'G/ML' then 9514
	when a.dose_unit = 'GY' then 9519
	when a.dose_unit = 'KG' then 9529
	when a.dose_unit = 'MEQ' then 9551
	when a.dose_unit = 'MEQ/L' then 9557
	when a.dose_unit = 'MEQ/ML' then 9559
	when a.dose_unit = 'MG /KG' then 9562
	when a.dose_unit = 'MG/KG' then 9562
	when a.dose_unit = 'MG/M**2' then 9563
	when a.dose_unit = 'MG/M2' then 9563
	when a.dose_unit = 'MG/M^2' then 9563
	when a.dose_unit = 'MG/MQ' then 9563
	when a.dose_unit = 'MG /M2' then 9563
	when a.dose_unit = 'MG PER M^2' then 9563
	when a.dose_unit = 'MG/.M2' then 9563
	when a.dose_unit = 'MG/M 2' then 9563
	when a.dose_unit = 'MG/M*2' then 9563
	when a.dose_unit = 'MG/M2**2' then 9563
	when a.dose_unit = 'MG/SQM' then 9563
	when a.dose_unit = 'MGM/M2' then 9563
	when a.dose_unit = 'MG/MG' then 9565
	when a.dose_unit = 'ML/KG' then 9571
	when a.dose_unit = 'MMOL' then 9573
	when a.dose_unit = 'MMOL/KG' then 9577
	when a.dose_unit = 'MOL' then 9584
	when a.dose_unit = 'NG' then 9600
	when a.dose_unit = 'NG/KG' then 9602
	when a.dose_unit = 'NL' then 9606
	when a.dose_unit = 'UG' then 9655
	when a.dose_unit = 'MCG' then 9655
	when a.dose_unit = 'MCGS' then 9655
	when a.dose_unit = 'MEG' then 9655
	when a.dose_unit = 'MICROGRAM' then 9655
	when a.dose_unit = 'UG/KG' then 9662
	when a.dose_unit = 'MCG/KG' then 9662
	when a.dose_unit = 'UG/M**2' then 9663
	when a.dose_unit = 'UG/M2' then 9663
	when a.dose_unit = 'MCG/M2' then 9663
	when a.dose_unit = 'UMOL' then 9667
	when a.dose_unit = 'IU/HR' then 9687
	when a.dose_unit = 'MU' then 9689
	when a.dose_unit = 'MCG/KG/HR' then 9690
	when a.dose_unit = 'MCG/KG/H' then 9690
	when a.dose_unit = 'UG/KG/H' then 9690
	when a.dose_unit = 'UG/KG/HR' then 9690
	when a.dose_unit = 'MG/KG/HR' then 9691
	when a.dose_unit = 'MG/KG/H' then 9691
	when a.dose_unit = 'CGY' then 4038192
	when a.dose_unit = 'UCI' then 4107008
	when a.dose_unit = 'NCI' then 4107009
	when a.dose_unit = 'PINT' then 4107012
	when a.dose_unit = 'PINTS' then 4107012
	when a.dose_unit = 'J/CM2' then 4117977
	when a.dose_unit = 'KIU' then 4118128
	when a.dose_unit = 'UL' then 4120719
	when a.dose_unit = 'MG/KG/D' then 4170258
	when a.dose_unit = 'MG/KG/DAY' then 4170258
	when a.dose_unit = 'CAP' then 4176621
	when a.dose_unit = 'CAPSULE' then 4176621
	when a.dose_unit = 'CAPSULES' then 4176621
	when a.dose_unit = 'CYC' then 4185742
	when a.dose_unit = 'IU/M2' then 4185926
	when a.dose_unit = 'IU/M**2' then 4185926
	when a.dose_unit = 'IU/M^2' then 4185926
	when a.dose_unit = 'IU//M**2' then 4185926
	when a.dose_unit = 'PUFFS' then 4187343
	when a.dose_unit = 'TSP' then 4212702
	when a.dose_unit = 'U/KG' then 4212721
	when a.dose_unit = 'NG/KG/MIN' then 4228325
	when a.dose_unit = 'NG/KG/HR' then 4228326
	when a.dose_unit = 'SPRAY' then 4304574
	when a.dose_unit = 'SPRAYS' then 4304574
	when a.dose_unit = 'PATCH' then 4306671
	when a.dose_unit = 'MG/HR' then 44777610
	when a.dose_unit = 'MG/H' then 44777610
	when a.dose_unit = 'ML/HR' then 44777613
	when a.dose_unit = 'ML/H' then 44777613
	when a.dose_unit = 'ML/SEC' then 44777614
	when a.dose_unit = 'UG/HR' then 44777645
	when a.dose_unit = 'MCG/HR' then 44777645
	when a.dose_unit = 'UG/H' then 44777645
	when a.dose_unit = 'MCG/H' then 44777645
	when a.dose_unit = 'MCG/HOUR' then 44777645
	when a.dose_unit = 'CC' then 44777662
	when a.dose_unit = 'MCI' then 44819154
	when a.dose_unit = 'BAU' then 45744810
	when a.dose_unit = 'PUMPS' then 45757637
	when a.dose_unit = 'MBQ' then 45891007
	when a.dose_unit = 'KBQ' then 45891008
	when a.dose_unit = 'GBQ' then 45891031
	when a.dose_unit = 'MBQ/ML' then 45891032
	when a.dose_unit = 'UG/KG/MIN' then 45949957
	when a.dose_unit = 'MCG/KG/MIN' then 45949957
	when a.dose_unit = 'PILL' then 4188359
	when a.dose_unit = 'PILLS' then 4188359
	when a.dose_unit = 'DF' then 44819066
	when a.dose_unit = 'DOSE' then 44819066
	when a.dose_unit = 'DOSES' then 44819066
	else null
	end
where a.dose_unit is not null;

--6 min
update drug_exposure a
set dose_unit_concept_id = b.unit_temp
from standard_faers.standard_drug b
where a.drug_exposure_source_id = b.drug_exposure_id
and b.unit_temp is not null;

--5.6.导入drug_exposure_start_date，drug_exposure_end_date
alter table standard_faers.standard_ther
add column drug_exposure_id bigint;

update standard_faers.standard_ther
set drug_exposure_id = cast((primaryid || dsg_drug_seq) as bigint);

drop index if exists standard_faers.standard_ther_index;
create index standard_ther_index on standard_faers.standard_ther(drug_exposure_id);

with cte1 as
(
	select drug_exposure_id, to_date(start_dt,'YYYYMMDD') as stdt, to_date(end_dt,'YYYYMMDD') as enddt, 
	row_number()over(partition by drug_exposure_id order by start_dt) as rn
	from standard_faers.standard_ther a where a.start_dt is not null or a.end_dt is not null
)
update drug_exposure a 
set drug_exposure_start_date = cte1.stdt,
    drug_exposure_end_date = cte1.enddt
from cte1
where cte1.drug_exposure_id = a.drug_exposure_source_id and cte1.rn = 1;

--建立临时表，drug_exposure_start_date，drug_exposure_end_date
drop table if exists drug_exposure_temp; 
create table drug_exposure_temp as 
(select * from public.drug_exposure limit 0);

alter table drug_exposure_temp add column rn bigint;
alter table drug_exposure_temp add column drug_exposure_source_id bigint;

alter table drug_exposure_temp alter lot_number type varchar;
alter table drug_exposure_temp alter drug_source_value type varchar;

truncate table drug_exposure_temp;
with cte1 as
(
	select drug_exposure_id, caseid, to_date(start_dt,'YYYYMMDD') as stdt, to_date(end_dt,'YYYYMMDD') as enddt, 
	row_number()over(partition by drug_exposure_id order by start_dt) as rn
	from standard_faers.standard_ther a where a.start_dt is not null or a.end_dt is not null
)
insert into drug_exposure_temp
(drug_exposure_source_id, rn, person_id, drug_exposure_start_date, drug_exposure_end_date)
(select cte1.drug_exposure_id,
 cte1.rn,
 cast(cte1.caseid as int),
 cte1.stdt,
 cte1.enddt
 from cte1
 where cte1.rn > 1);
 
drop index if exists drug_exposure_temp_index;
create index drug_exposure_temp_index on drug_exposure_temp(drug_exposure_source_id);

update drug_exposure_temp a
set drug_concept_id = b.drug_concept_id, 
    drug_type_concept_id = b.drug_type_concept_id,
    route_concept_id = b.route_concept_id, 
    dose_unit_concept_id = b.dose_unit_concept_id,  
    lot_number = b.lot_number, 
    drug_source_value = b.drug_source_value, 
    route_source_value = b.route_source_value, 
    dose_unit_source_value = b.dose_unit_source_value,
    effective_drug_dose = b.effective_drug_dose
from drug_exposure b
where a.drug_exposure_source_id = b.drug_exposure_source_id;

insert into drug_exposure
(drug_exposure_source_id, person_id, drug_concept_id, drug_exposure_start_date, drug_exposure_end_date,
drug_type_concept_id, route_concept_id, effective_drug_dose, dose_unit_concept_id, lot_number,
drug_source_value, route_source_value, dose_unit_source_value)
(select (drug_exposure_source_id * 100 + rn), person_id, drug_concept_id, drug_exposure_start_date, drug_exposure_end_date,
drug_type_concept_id, route_concept_id, effective_drug_dose, dose_unit_concept_id, lot_number,
drug_source_value, route_source_value, dose_unit_source_value from drug_exposure_temp);

--5.7导入days_supply
--drug_exposure_start_date, drug_exposure_end_date均非空，直接计算
update drug_exposure 
set days_supply = (drug_exposure_end_date - drug_exposure_start_date + 1)
where drug_exposure_start_date is not null and drug_exposure_end_date is not null

--drug_exposure_start_date, drug_exposure_end_date有空值，从standard_ther的dur和dur_cod导入
--规范化dur和dur_cod值
update standard_faers.standard_ther
set dur_cod = trim(dur_cod)
where dur_cod is not null;

update standard_faers.standard_ther
set dur_cod = 
	case when dur_cod ~ '^Y$' then 'YR'
	when dur_cod ~ '^YEAR' then 'YR'
	when dur_cod ~ '^YR' then 'YR'
	when dur_cod ~ '^MO' then 'MON'
	when dur_cod ~ '^WEEK' then 'WK'
	when dur_cod ~ '^WK' then 'WK'	
	when dur_cod ~ '^DA' then 'DAY'
	when dur_cod ~ '^D$' then 'DAY'
	when dur_cod ~ '^HR' then 'HR'
	when dur_cod ~ '^HOUR' then 'HR'
	when dur_cod ~ '^MIN' then 'MIN'
	when dur_cod ~ '^SEC' then 'SEC'
	else dur_cod
	end
where dur_cod is not null;

update standard_faers.standard_ther
set dur = 
	case when dur ~ '\>' then regexp_replace(dur, '\>', '')
	when dur ~'\<' then regexp_replace(dur, '\<', '')
	else dur
	end
where dur is not null and (dur ~ '\>' or dur ~ '\<');

update standard_faers.standard_ther
set dur = regexp_replace(dur, '\t', '')
where dur ~ '\t';

update standard_faers.standard_ther 
set dur = 
	case when dur ~ '^[0-9]\-[0-9]$' then to_char((to_number(dur,'9') + to_number(dur,'  9')) / 2, '999D99')
	when dur ~ '^[0-9]\-[0-9][0-9]$' then to_char((to_number(dur,'9') + to_number(dur,'  99')) / 2, '999D99')
	when dur ~ '^[0-9][0-9]\-[0-9][0-9]$' then to_char((to_number(dur,'99') + to_number(dur,'   99')) / 2, '999D99')
	when dur ~ '^[0-9]\.[0-9]\-[0-9]$' then to_char((to_number(dur,'9D9') + to_number(dur,'    9')) / 2, '999D99')
	when dur ~ '^[0-9]\-[0-9]\.[0-9]$' then to_char((to_number(dur,'9') + to_number(dur,'  9D9')) / 2, '999D99')
	else dur
	end
where dur ~ '\-';

update standard_faers.standard_ther
set dur = trim(dur)
where dur is not null;

update standard_faers.standard_ther
set days_supply = 
	case when dur_cod = 'YR' then cast(dur as numeric) * 365
	when dur_cod = 'MON' then cast(dur as numeric) * 30
	when dur_cod = 'WK' then cast(dur as numeric) * 7
	when dur_cod = 'HR' then cast(dur as numeric) / 24
	when dur_cod = 'MIN' then cast(dur as numeric) / 1440
	when dur_cod = 'SEC' then cast(dur as numeric) / 86400
	else null
	end
where dur is not null and (dur ~ '^[0-9]+$' or dur ~ '^[0-9]+\.[0-9]+$');

update drug_exposure a
set days_supply = b.days_supply
from standard_faers.standard_ther b
where a.drug_exposure_source_id = b.drug_exposure_id
and (a.drug_exposure_start_date is null or a.drug_exposure_end_date is null)
and b.days_supply is not null;

--把0天改为1天
update drug_exposure
set days_supply = 1
where days_supply = 0;

