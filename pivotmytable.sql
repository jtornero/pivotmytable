/* pivotMyTable An improved crosstab function for PostgreSQL.
 
 Copyright 2014 Jorge Tornero Nunez http://imasdemase.com
 
 pivotMyTable is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 pivotMyTable is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with pivotMyTable.  If not, see <http://www.gnu.org/licenses/>.

FUNCTION DESCRIPTION
====================
pivotMyTablee is a PL/Python function for use in PostgreSQL servers. Its aim is
to get crosstab/pivoted tables in a more friendly way that PostgreSQL module
tablefunc does with its crosstab series functions and in fact it behaves in the
end as a proxy for tablefunc functions.

pivotMyTablee makes it possible in the same way that other available solutions,
automating the creation the queries that the tablefunc crosstab functions need to work.

Also, pivotMyTablee makes possible to directly get percentages,
as well as get rid of null values in the oputput tables.

FUNCTION PARAMETERS/OPTIONS
===========================
input_table (varchar):  Name of the table to get data to pivot.
output_table(varchar):  Name for the output table.
group_fields(varchar):  Name of the column(s) for categorizing the data. Unlike the
                        native tablefunc module functions crosstab, it accepts multiple
                        columns.
pivot_field(varchar):   Column to be pivoted, must be a single column.
value_field(varchar):   Data to aggregate for the pivot field. It is expected for
                        value_field to be a numeric (int, float, etc) field.
agg_func(varchar):      Aggregate function to apply to the data from value_field. It
                        must be specified without brackets.
                        It's user responsability to check for function/data type
                        compatibility and resulting data. So far it has been tested
                        with sum.
as_percentage(bool):    This option enables the output as percentage of each output
                        columns over its overall sum BY ROW. It defaults to FALSE, so                        to enable percentage calculation set it to TRUE.
sort_order(varchar):    This option enables sorting the resulting pivoted columns.
                        You can specify 'asc', 'desc'. It defaults to 'no_sorting'
drop_ex_tbl (boolean):  pivotMyTablee checks if the output table specified with the
                        parameter output_table exists before further processing.
                        Setting this option to TRUE makes possible to automatically
                        drop the existing table. By default, drop_ex_tbl is set to
                        FALSE so the function exists with a warning if output_table
                        already exists in the database.
output (boolean):       This option enables the output to a view instead of to a table.
                        To enable view output, set it to TRUE. Defaults to FALSE.
                        
*/

CREATE OR REPLACE FUNCTION pivotmytable (input_table varchar,
                                   output_table varchar,
                                   group_fields varchar,
                                   pivot_field varchar,
                                   value_field varchar,
                                   agg_func varchar,
                                   as_percentage bool default false,
                                   sort_order varchar default 'no_sorting',
                                   drop_ex_tbl boolean default false,
                                   as_view boolean default false)
  RETURNS varchar
  LANGUAGE plpythonu

AS $$
    """Function pivotMyTable"""
    
    import math
    
    
    # Time to check if input_table,group_fields, pivot_field and value_field parameters are OK
    
        
    tablesQuery = plpy.execute("select table_name from information_schema.tables")
    tableList = [tablename["table_name"] for tablename in tablesQuery]
    
    inputTableColumnsQuery = plpy.execute("select column_name from information_schema.columns where table_name='%s'" %input_table.replace(" ",""))
    inputTableColumnsList = [col["column_name"] for col in inputTableColumnsQuery]
    
    if input_table.replace(" ","") not in tableList:
        return "Your input table %s does not exist.  Please check and try again." %input_table
    
    for parameter in group_fields.split(','):
        if parameter.replace(" ", "") not in inputTableColumnsList:
            return ("The column %s specified in group_fields does not exist in the table %s. Please check and try again." %(parameter,input_table))
    
     
    if pivot_field.replace(" ","") not in inputTableColumnsList:
        return ("The column %s specified in group_field does not exist in the table %s. Please check and try again." %(pivot_field,input_table))
    if value_field.replace(" ","") not in inputTableColumnsList:
        return ("The column %s specified in value_field does not exist in the table %s. Please check and try again." %(value_field,input_table))
    
    # Checking for percentage and aggregate function compatibility
    
    if agg_func.replace(" ","") not in ('sum','count','avg'):
        return "Aggregate function %s is not compatible/tested. Aborting" %agg_func
    
    if as_percentage and (agg_func.replace(" ","")!='sum'):
            return "Percentage calculation and aggregate function %s are not compatible. Aborting" %agg_func
    
    
    # Checks if the output table name already exists in the database
    if as_view:
        table_type = 'view'
    else:
        table_type = 'table'
        
    if (output_table.replace(" ","") in tableList):
        if (drop_ex_tbl):
            plpy.execute("drop %s %s" %(table_type, output_table))
        else:
            return ("The %s %s already exists in the database.  Please check and try again." %(table_type, output_table))
        
        
    # Management of sort order parameter
    
    if sort_order.replace(" ","") == 'asc':
        ordering="(select %s, %s(%s) as ordervalue from %s group by %s order by 2 asc) as t2"%(pivot_field,agg_func,value_field,input_table,pivot_field)
    elif sort_order.replace(" ","") == 'desc':
        ordering="(select %s, %s(%s) as ordervalue from %s group by %s order by 2 desc) as t2"%(pivot_field,agg_func,value_field,input_table,pivot_field)
    elif sort_order.replace(" ","") == 'no_sorting':
        ordering="(select distinct %s from %s order by 1) as t2"%(pivot_field,input_table)
    else:
        return "Wrong sort parameter specification. It must be 'asc', 'desc' or no. Please check and try again."
        
    # GATHERING OF THE PIVOTED COLUMN NAMES AND THEIR DATA TYPES.
    
    # First we get the names of the destination fields, which are the values present in
    # the pivot_field column
    
    destColumns = plpy.execute("select %s as columns from %s " %(pivot_field, ordering))
    
    # We need this for the final field splitting
    destColumns2 = plpy.execute("select distinct %s as column from %s order by 1" %(pivot_field,input_table))
    
    # Now we get the column type. Because all the output pivoted columns
    # will have the same data type than input columns, its definition is
    # simple in the case of integer/double columns, but for numeric columns
    # we need to get both the precision (number of decimals) and the maximum
    # value of its aggregate, to prevent overflows when aggregating the data
    
    # First we make the query to information_schema.columns. 
    
    columnPropertiesQuery = plpy.execute("select data_type,numeric_scale from information_schema.columns where table_name = '%s' and column_name='%s'" %(input_table.replace(" ",""),value_field.replace(" ","")))
    
    # Due to the nature of the PLyResult object returned by plpy.execute,
    # getting the columns properties is a little tricky
    
    columnProperties = [property for property in columnPropertiesQuery]
    
    columnType = columnProperties[0]["data_type"]
    columnScale = columnProperties[0]["numeric_scale"]
        
    # Because the percentage values range from 0 to 1,
    # we need to make room for more decimal numbers for 
    # precision not be lost
    
    if as_percentage:
        fieldType = "numeric(6,5)"
    else:
        if columnType == 'numeric' or agg_func =='avg':
            if columnScale == None:
                columnScale = 8
            maxFieldValue = plpy.execute("select %s(%s) as agg_funcres from %s" %(agg_func, value_field,input_table))
            magnitudeOrder = math.log10(maxFieldValue[0]["agg_funcres"])
            numericFieldWidth = magnitudeOrder + columnScale + 1
            fieldType = ("numeric(%i, %i)" %(numericFieldWidth, columnScale))
            
        elif columnType in ('bigint','smallint','integer','real','double precision'):
            fieldType = columnType
        else:
            return "Your pivot column %s is not of a numeric type.  Please check and try again." %pivot_field
       
    flds = ['"%s" %s'%(destColumn["column"],fieldType) for destColumn in destColumns2]
    fields = ','.join(flds)
    
    gfields=group_fields.replace(" ","").split(',')
    groupingColumns=list()
    idx=1
    for field in gfields:
        columnType = plpy.execute("select data_type from information_schema.columns where table_name = '%s' and column_name='%s'" %(input_table.replace(" ",""),field.replace(" ","")))
        tc=[columna["data_type"] for columna in columnType]
        
        # We need this to recover the grouped fields after crosstab execution 
        
        nc = ("split_part(trim(joinedcols,'()'),',',%i)::%s as %s" %(idx,tc[0],field))
               
        groupingColumns.append (nc)
        idx += 1
    groupingColumns=','.join(groupingColumns)

    # Construction of the queries to be passed to crosstab function

    if as_percentage:
        # If we want percentages instead of absolute values, we need to
        # create a new table with the percentages, and the queries
        # that are passed to crosstab funcion are silightly different
        # Notice the use of row(), that makes possible to have crosstabs
        # grouped by more than one single field, but to this to be done,
        # we have had to do a lot of tricks before (see the use of
        # split_part above)
        
        groupbyclause=group_fields + ',' + value_field

        plpy.execute("""create temporary table intertable as
            (select %s,%s,%s/%s(%s::numeric) over (partition by %s) as percentages from %s group by %s,%s,%s order by %s)""" 
            %(group_fields,pivot_field,value_field,agg_func,value_field,group_fields,input_table,group_fields,pivot_field,value_field,group_fields))
        firstQuery=("""select distinct row(%s),%s,%s(percentages) from intertable
            group by %s,%s order by 1,2"""
            %(group_fields,pivot_field,agg_func,group_fields,pivot_field)) 
        secondQuery = ("select distinct %s from intertable order by 1" %(pivot_field))
        
    else:
        # For absolute values, the queries passed to crosstab are simpler
    
        aggrfun=("%s(%s)" %(agg_func,value_field))
        groupbyclause=group_fields
        firstQuery=("select distinct row(%s),%s,%s from %s group by %s,%s order by 1,2" %(group_fields,pivot_field,aggrfun,input_table,groupbyclause,pivot_field))
        secondQuery = ("select distinct %s from %s order by 1" %(pivot_field,input_table))
    
    # We create the sentence for output fields for crosstab
    crossTabQuery = ("joinedcols varchar,%s"%(fields))
    
    # This trick makes possible to get rid of the null values in the pivoted tables.
    # TODO: Consider to make it optional, with a parameter for it.
    
    replaceZeros = ['coalesce("{0}",0) as "{0}"'.format(destColumn["columns"]) for destColumn in destColumns]
    replaze0 = ','.join(replaceZeros)
    
    # And now, we put everything together and execute the query
    finalQuery = ("create %s %s as (select %s,%s from crosstab('%s','%s') as newtable(%s))" %(table_type,output_table,groupingColumns,replaze0,firstQuery,secondQuery,crossTabQuery))  
    plpy.execute(finalQuery)
    
    # A little cleanup may be necessary
    if as_percentage:
        pass
        plpy.execute("drop table intertable")

    return "Your pivoted %s %s has been created." %(table_type, output_table.replace(" ",""))
  
$$;