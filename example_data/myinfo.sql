-- Example data for pivotmytable, a PLPythonU
-- function to create easy crosstabs in PostgreSQL
-- This example is in the public domain

DROP TABLE IF EXISTS myinfo;
CREATE TABLE myinfo(
    player varchar(6),
    tool varchar(6),
    round varchar(3),
    hits int);
    
insert into myinfo values('Pepito','Hammer','Rd1',12);
insert into myinfo values('Pepito','Hammer','Rd2',13);
insert into myinfo values('Pepito','Hammer','Rd2',4);
insert into myinfo values('Pepito','Wrench','Rd5',1);
insert into myinfo values('Manu','Wrench','Rd1',12);
insert into myinfo values('Manu','Wrench','Rd1',16);
insert into myinfo values('Manu','Hammer','Rd2',3);
insert into myinfo values('Richal','Hammer','Rd3',42);
insert into myinfo values('Richal','Hammer','Rd1',17);
insert into myinfo values('Richal','Hammer','Rd4',22);
insert into myinfo values('Richal','Hammer','Rd2',15);
insert into myinfo values('Richal','Hammer','Rd1',17);