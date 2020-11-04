<?lasso

not ::ldebug->istype	? include('__library/debug/debug.type.lasso')	
not ::ds->istype		? include('__library/ds/_init.lasso')

if(not ::slapcode_type->istype)=> {
	include('__library/json.lasso')
	include('__definitions/slapcode.type.lasso')
}

// MySQL Connections only (local host recommeneded)

slapcode_host 		= sys_getenv('DS_HOST') || '127.0.0.1'
slapcode_database 	= 'slapcode'
slapcode_username 	= 'root'
slapcode_password 	= ''

slapcode

?>
