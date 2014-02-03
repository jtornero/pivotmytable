PivotMyTable
============

**PivotMyTablee is a PL/Python function** for use in PostgreSQL servers. Its aim is **to get crosstab/pivoted tables in a more friendly way** that PostgreSQL module *tablefunc* does with its *crosstab* series functions and in fact it behaves ,at last, as a proxy for tablefunc functions.

**PivotMyTablee makes it possible** in the same way that other available solutions, **automating the creation of the queries** that the *tablefunc* *crosstab* functions need to work.

Also, **PivotMyTablee makes possible to directly get percentages** in the pivoted tables, **as well as get rid of null values in the oputput** tables.

Copyright/License
=================

PivotMyTable has been developed by Jorge Tornero.

(C) 2014 Jorge Tornero, http://imasdemase.com

PivotMyTable is released under the terms of the

**GNU GENERAL PUBLIC LICENSE**

Version 3, 29 June 2007

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see:

**http://www.gnu.org/licenses**

Donations/Fees
==============

Of course, no donations or fees are required for using PivotMyTable in your databases/servers... but if you feel that PivotMyTable has improved you life in any way, you can make a small donation to a NGO/Charity of your choice.

Additionally, if you really feel in the mood of rewarding me, just feel free for asking me about my postal address and send me a postcard from where you live. I'll be proud of showing it to my kid. 


Installation and usage
======================

PivotMyTable requires the PostgreSQL extension tablefunc and the language PL/Python installed in the database to work.

- *Installation of tablefunc extension:* Please check PostgreSQL documentation pages for extensions installation in <a href="http://www.postgresql.org/docs/9.3/static/contrib.html" target="_blank">http://www.postgresql.org/docs/9.3/static/contrib.html</a>. Check for the correct manual page for your version of PostgreSQL.

- *Installation of PL/Python language:* Please check PostgreSQL documentation pages for the installation of PL/Python <a href="http://www.postgresql.org/docs/9.0/static/plpython.html" target="_blank">http://www.postgresql.org/docs/9.3/static/plpython.html</a>. Check for the correct manual page for your version of PostgreSQL.
        

The usage of PivotMyTable is simple: Providing that you have a table *myinfo* like:



|player|tool|round|hits|
|------|----|:-----:|:----:|
|Pepito|Hammer|Rd1|12|
|Pepito|Hammer|Rd2|13|
|Pepito|Hammer|Rd2|4|
|Pepito|Wrench|Rd5|1|
|Manu|Wrench|Rd1|12|
|Manu|Wrench|Rd1|16|
|Manu|Hammer|Rd2|3|
|Richal|Hammer|Rd3|42|
|Richal|Hammer|Rd1|17|
|Richal|Hammer|Rd4|22|
|Richal|Hammer|Rd2|15|
|Richal|Hammer|Rd1|17|

You can issue this query:

<pre><code>select * from pivotmytable('myinfo','pivotedinfo','player,tool','round','sum',sort_order:='asc');</code></pre>

To get a pivoted table like this:

|player|tool|Rd1|Rd2|Rd3|Rd4|Rd5|
|------|----|:---:|:---:|:---:|:---:|:---:|
|Pepito|Hammer|12|17|0|0|0|
|Pepito|Wrench|0|0|0|0|1|
|Manu|Hammer|0|3|0|0|0|
|Manu|Wrench|28|0|0|0|0|
|Richal|Hammer|34|15|42|22|0|


Function Parameters/Options
===========================

- **input_table (varchar):**
    Name of the table to get data to pivot.
- **output_table(varchar):**
    Name for the output table.
- **group_fields(varchar):**
    Name of the column(s) for categorizing the data. Unlike the native *tablefunc* module functions *crosstab*, it accepts multiple columns.
- **pivot_field(varchar):** 
    Column to be pivoted, must be a single column.
- **value_field(varchar):**
Data to aggregate for the pivot field. It is expected for value_field to be a numeric (int, float, etc) field.
- **agg_func(varchar):**
Aggregate function to apply to the data from value_field. It  must be specified without brackets. It's user responsability to check for function/data type compatibility and resulting data. So far it has been tested with sum().
- **as_percentage(bool):**
This option enables the output as percentage of each output columns over its overall sum BY ROW. It defaults to FALSE, so to enable percentage calculation set it to TRUE.
- **sort_order(varchar):**
This option enables sorting the resulting pivoted columns. You can specify 'asc', 'desc'. It defaults to 'no_sorting'.
- **drop_ex_tbl (boolean):**
pivotMyTablee checks if the output table specified with the parameter output_table exists before further processing. Setting this option to TRUE makes possible to automatically drop the existing table. By default, drop_ex_tbl is set to FALSE so the function exists with a warning if output_table already exists in the database.


