<?lassoscript

//------------------------------------------------------------------------
//
//	Slapcode handles
//
//------------------------------------------------------------------------

define slapcode => var(_slapcode) || $_slapcode := slapcode_type
define slapcode_editor => slapcode->current_editor
define slapcode_result => slapcode->current_result

define slap => debug => givenblock

define slap(p::any) => {
	debug(#p)
	return #p
}

//------------------------------------------------------------------------
//
//	Slapcode settings
//
//------------------------------------------------------------------------

define slapcode_host= (val::string) => { var(__slapcode_host) = #val } 
define slapcode_host => var(__slapcode_host) || ''

define slapcode_database= (val::string) => { var(__slapcode_database) = #val }
define slapcode_database => var(__slapcode_database) || 'slapcode'

define slapcode_username= (val::string) => { var(__slapcode_username) = #val }
define slapcode_username => var(__slapcode_username) || ''

define slapcode_password= (val::string) => { var(__slapcode_password) = #val }
define slapcode_password => var(__slapcode_password) || ''

//------------------------------------------------------------------------
//
//	Slapcode types
//
//------------------------------------------------------------------------

define slapcode_type => type {
	data 
		public database = 'slapcode',

		public client_id::integer=0,
		public project_id::integer=0,
		public user_id::integer=0,

		public compile::boolean=true,
		public debug::boolean = true,
		
		private compiled,
		private output=map,
		private ds
		

	public oncreate => {
		//	Start session
		.project_id = integer(client_postparam('project_id'))
		.client_id = integer(client_postparam('client_id'))
		.user_id = integer(client_postparam('user_id'))		
		
	}
	
	public ds => .'ds' || .'ds' := ds(
		-datasource	= 'mysqlds',
		-table 		= 'code',
		-database	= slapcode_database, 
		-host 		= slapcode_host, 
		-username 	= slapcode_username,
		-username 	= slapcode_password
	)
	
	public installed => .installation == 'installed'

	public installation => {
		var(__slapcode_install)->isnota(::null) ? return $__slapcode_install
		
		debug('Slapcode Installation') => {
		
			local(installed) = false
			
			protect => {
				handle => {
					
					debug(error_code ? 'Error' | 'OK')
					
					local(error) = error_msg
						
					match(true) => {
						case(#error >> 'Unknown database')
							return $__slapcode_install := 'No database'	
						case(#error >> 'doesn\'t exist')
							return $__slapcode_install := 'No tables'	
						
					}
				}
	
				// Create if not there
				.ds->sql('CREATE DATABASE IF NOT EXISTS `'+slapcode_database + '`')
	
				// Check for database
				.ds->sql('USE '+slapcode_database)
				
				// Create tables
				.createtables
				
				#installed = .ds->info->columns->size > 0
			}
		
		}
	
		return $__slapcode_install := (#installed ? true | false)
	}

	
	public asstring => {

		local(
			out = .output,

			id = integer(client_postparam('id')) || null,
			project_id = .project_id,
			client_id = .client_id,
			user_id = .user_id,

			name = client_postparam('name')->asstring,
			code = client_postparam('code')->asstring,
			task = web_request->param('task')->asstring,
			
			project_name = client_postparam('project_name')->asstring

		)
		
		debug('task'=#task)
					
		match(#task) => {
		
			case('load')
				if(#project_id)=>{
					#out->insert('project' = .load('projects',#project_id))
				else
					#out->insert('project' = .default_project)
				}
				#out->insert('projects' = .projects(#client_id,#user_id))
				#out->insert('files' = .files(#project_id))
				#out->insert('tabs' = .tabs(#project_id))

				return .current_result

			case('compile')
				.compile(#code)
				return .current_result

			case('open')
				.update('code',map('isopen'=0),#id)
				#out->insert(
					'tab' = .load('code',#id)
				)
				return .current_result

			case('close')
				.update('code',map('isopen'=0),#id)
				return .current_result
				
				
			case('saveproject')
				#project_id = .insert('projects',map('name'=#project_name),#project_id || null)
				
				#out->insert(
					'project' = .load('projects',#project_id)
				)
				return .current_result

			case('save')			
				.save(#id,#name,#code)
				return .current_result
			case('projects')
				#out->insert('projects'=.projects)
				return .current_result
			case('files')
				#out->insert('files'=.files)
				return .current_result
			case('tabs')
				#out->insert('tabs'=.tabs)
				return .current_result
			case('run')
				debug->activate	
				.run(#code)
				
				#out->insert(
					'id' = .save(#id,#name,#code)
				)
				
				return .current_result
			case
				debug->activate	
		}
		
		return include('_templates/host.htm')
	}
	
	public current_editor => {
		return include('_templates/editor.htm')
	}
	
	public current_result => {

		local(out = .output || map)
		
		#out->insert(
			'debug' = debug->ashtml
		)
		
//		content_body += #out
		
		if(client_headers >> 'json') => {
			content_type('application/json; charset=UTF-8')
			return json_serialize(#out)
		else
			return #out->values->join('')
		}

	}
	
	public createtables => {
	
		local(sql) = ''	
				
		#sql->append(
			'CREATE TABLE IF NOT EXISTS `clients` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT,
				`name` VARCHAR(128) NOT NULL DEFAULT "",
				PRIMARY KEY (`ID`)
			) AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;\n'
		)		
		#sql->append(
			'CREATE TABLE IF NOT EXISTS `users` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT,
				`hash` VARCHAR(128) NOT NULL DEFAULT "",
				`client_id` bigint(20) NOT NULL,
				PRIMARY KEY (`ID`)
			) AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;\n'
		)		
		
		#sql->append(
			'CREATE TABLE IF NOT EXISTS `projects` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT,
				`created` datetime NOT NULL,
				`modified` datetime NOT NULL,
				`user_id` bigint(20) NOT NULL,
				`client_id` bigint(20) NOT NULL,
				`name` VARCHAR(128) NOT NULL DEFAULT "",
				`code` text,
				PRIMARY KEY (`ID`)
			) AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;\n'
		)		
		
		#sql->append(
			'CREATE TABLE IF NOT EXISTS `code` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT,
				`created` datetime NOT NULL,
				`modified` datetime NOT NULL,
				`project_id` bigint(20) NOT NULL,
				`user_id` bigint(20) NOT NULL,
				`name` VARCHAR(64) NOT NULL,
				`isopen` tinyint(2) NOT NULL default 1,
			
				`code` text,
				PRIMARY KEY (`ID`),
				UNIQUE KEY `project_key` (`project_id`,`name`)
			) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;\n'
		)
		
		#sql->append(
			'CREATE TABLE IF NOT EXISTS `history` (
				`ID` bigint(20) NOT NULL AUTO_INCREMENT,
				`created` datetime NOT NULL,
				`project_id` bigint(20) NOT NULL,
				`key` VARCHAR(64) NOT NULL,
				`code` text,
				`result` text,
				`time` smallint(6) DEFAULT NULL,
				`error_code` mediumint(9) DEFAULT NULL,
				`error_msg` varchar(255) DEFAULT NULL,
				PRIMARY KEY (`ID`)
		
			) ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=utf8;\n'
		)
		
		.ds->sql(#sql)

	}
	
	public default_project => map(
				'id' 		= 0,
				'user_id' 	= 0,
				'client_id' = 0,
				'name' 		= 'S L A P C O D E'
			)

	public projects(client_id::integer=0,user_id::integer=0) => debug => {
		local(
			projects = array,
			where = array
		) 						
		#client_id
		? #where->insert(' client_id = '+#client_id)
		
		#where->insert(' user_id = '+#user_id)
		
		with row in .ds->sql(
			'SELECT * 
			FROM projects 
			WHERE '+#where->join(' OR ')+'
			ORDER BY name ASC'
		)->rows do {
			#row->find('id') != 0 
			? #projects->insert(
				map(
					'id' 		= #row(::id),
					'user_id' 	= #row(::user_id),
					'client_id' = #row(::client_id),
					'name' 		= #row(::name)
				)
			)	
		}
		
		return #projects
	}

	public files(project_id::integer=0) => debug => {
		local(files) = array 
		
		with row in .ds->sql(
			'SELECT id,name 
			FROM code 
			WHERE project_id = '+#project_id+'
			ORDER BY name ASC'
		)->rows do {
			#files->insert(
				map(
					'id' = #row(::id),
					'name' = #row(::name)
				)
			)
		}
		return #files
	}

	public tabs(project_id::integer=0) => debug => {
		local(tabs) = array 
		
		with row in .ds->sql(
			'SELECT id,name,code 
			FROM code 
			WHERE isopen = 1
			AND project_id = '+#project_id+'
			LIMIT 0,12'
		)->rows do {
			#tabs->insert(
				map(
					'id' = #row(::id),
					'name' = #row(::name),
					'code' = #row(::code)
				)
			)
		}
		
		return #tabs
	}

	public compile(code::string,name::string='slap',breakpoints::array=array,focus::boolean=false) => {
		protect => {
			handle => {
				if(error_code && error_msg !>> 'Premature end of file')=>{
					local(
						msg = error_msg,
						line = integer(#msg->split('line: ')->last->split(',')->first),
						col = integer(#msg->split('col: ')->last),
						msg = #msg->split('line:')->first->split('parsing.')->last
					)
					
					.output->insert(
						'script' = `slapcode.showerror(`+#line+`,`+#col+`,'`+#msg+`',`+#focus+`)`
					)
					
					error_reset
					return false
				else
					.output->insert(
						'script' = `slapcode.hideerror()`
					)
				}
				
				return true
			}
			
			//debug(string_replaceregexp(#x,-find=`=>\s\{`,-replace='=> debug => {'))
			
			//debug->activate;
			
			//debug(string_replaceregexp(#code,-find=`=>\s\{`,-replace='=> slap => {'))
			//debug(string_replaceregexp(#code,-find=`([\.\-\>\w]+\(.*?\))(?!>=)`,-replace=`slap(\1)`))
			
			// void

			//debug(#code)

			debug('Compiling code') => {
				.compiled = sourcefile(#code,'slapcode: '+#name,true,false)
			}			
		}
	}
	
	public run(code::string,name::string='slap',breakpoints::array=array) => {

		! .compile(#code,#name,#breakpoints,true)
		? return false

		debug->activate;
			
		local(
			start 		= integer,
			time 		= integer,
			error_code 	= 0,
			error_msg 	= string,
			out			= .output,
			result		= null 
		)
		
		protect => {
			handle => {
				
				#error_code = error_code;
				#error_msg 	= error_msg;
	
				if(#error_code) => {

					local(
						line,col,pos,
						detail = error_stack->split('\n')->first
					)
					
					if(#detail >> 'slapcode:') => {
						#detail = #detail->split(' ')
					 	#pos = #detail->get(1)->split(':')
					 	#line = #pos->first
					 	#col = #pos->last
					 	
						#detail->remove(1)
						#detail = #detail->join(' ')
						
						#out->insert(
							'script' = `slapcode.showerror(`+#line+`,`+#col+`,'`+#error_msg+`',true)`
						)
					else;
						#out->insert(
							'result' = '<b>Error ' + #error_code + '</b><br />' + #error_msg
						) 
					}
				else
					#out->insert(
						'script' = `slapcode.hideerror()`
					)

				}		
				
			}
			
			#start = micros
			
			debug('Executing code') => {
				#result = .compiled->invoke->asstring 
			}
			
			#out->insert(
				'result' = (#result || 'No output')
			)
			
			#time = (micros - #start)*0.000001
			
			//.log(#name,#code,#out,#time)

		}

	}
	
	public load(table::string,id::integer) => debug => {
		local(out=map)
		with row in .ds->sql('SELECT * FROM '+#table+' WHERE id = '+#id)->rows do {
			with col in #row->columns do {
				#out->insert(#col->lowercase& = #row->find(#col))
			}
		}
		
		return #out
	}

	public save(
		id::any,
		name::string,
		code::string
	) => {
		
		return
				
		local(
			row = activerow(.ds->table(::code)),
			out = .output,
			p_id = .project_id,
			u_id = !#p_id ? .user_id | 0,
			now = date->format('%q'),
			data =  map(
						'id'		= #id,
						'project_id'= #p_id,
						'user_id' 	= #u_id,
						'name' 		= #name,
						'code' 		= #code,
						'created' 	= #now,
						'modified' 	= #now,
						'isopen'	= 1
					)
		)
		#id ? #data->remove('created')
		
		#row->updatedata(#data) & save		
			
		//return .insert('code',#row,#id)
	}

	public insert(table::string,row::map,id::any) => {
		#row->insert('id'=#id)		
		.ds->insertinto(#table,#row,true) => {}	
	}
	
	public update(table::string,row::map,id::integer) => {
		ds->updaterowin(#table,#row,#id)
	}
	
	public log(
		name::string,
		code::string,
		result::string,
		time::decimal,
		error_code::integer,
		error_msg::string
	) => {
	
		.ds->insertinto('history',map(
			'name' 	= #name,
			'code' 	= #code,
			'result'= #result,
			'error_code'= #error_code,
			'error_msg'	= #error_msg
		))
	}
}

?>