<?lassoscript

//
//stdoutnl(#root)

with path in (:
	'debug/debug.type.lasso',
	'ds/sequential.lasso',
	'ds/tables.lasso',
	'ds/activerow.lasso',
	'ds/ds.lasso',
	'ds/ds_row.lasso',
	'ds/ds_result.lasso',
	'ds/statement.lasso',
	'slapcode.type.lasso'
) do protect => {
	local(s) = micros
	handle => {
		stdoutnl(
			error_msg + ' (' + ((micros - #s) * 0.000001)->asstring(-precision=3) + ' seconds)'
		)
	}
	stdout('\t' + #path + ' - ')
	
	sourcefile(file_read(#root+#path)->asstring,#path,false,false)()
	//lassoapp_include(#path)
	//library(#path)
}
stdoutnl('\tdone')

?>