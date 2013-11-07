<?lassoscript

define isjson => isajax && client_params >> 'asjson' //&& client_headers >> 'json' 
protect => {json_deserialize('init')}

define json_deserialize(data::string)::any => {	
	#data->removeLeading(bom_utf8->asstring);
	! #data ? return null
	
	local(
		c =#data->get(1) 
	)
	#data ? #data->remove(1,1)
	
	match(#c) => {
		case('[')
			return json_consume_array(#data)
		case('{')
			return json_consume_object(#data)	
		case('"')
			return json_consume_string(#data)
	}
}

define json_consume_array(data::string)::array => {

	local(
		out = array,
		cap, b
	)

		
	{	#cap = currentcapture

		#b = #data->get(1)
		#data->remove(1,1)
		
		// Skip white space
		#b=='\t'||#b=='\r'||#b=='\n'||#b==' '||#b==','
		? #data ? #cap->restart()

		match(#b) => {
			case('"')
				#out->insert(json_consume_string(#data))
			case('[')
				#out->insert(json_consume_array(#data))
			case('{')
				#out->insert(json_consume_object(#data))
			case(']')
				//	do nothing
			case
				#out->insert(json_consume_token(#data,#b))
		}
		
		#b != ']' && #data ? #cap->restart()

	}()

	return #out
}

define json_consume_token(data::string,out::string) => {

	! #data ? return

	local(
		b,
		cap
	)
	
	{	#cap = currentcapture
		#b = #data->get(1)
		#b!='}' ? #data->remove(1,1)
		if(#b!='\t' && #b!='\r' && #b!='\n' && #b!= ' ' && #b!=',' && #b != '}') => {
			#out += #b
			#data ? #cap->restart()
		}
	}()


	#out == 'true'	? return true
	#out == 'false'	? return false
	#out == 'null'	? return null
	
	#out->isalnum
	? return #out >> '.' ? decimal(#out) | integer(#out)
	
	return #out
}

define json_serialize(e::void)::string => ('null')
define json_serialize(e::xml_text)::string => json_serialize(#e->asstring)

define json_consume_string(data::string) => {
	
	local(
		out = '',
		b
	)
	
	
	{	
		#b = #data->get(1)
		#data->remove(1,1)
			
		if(#b == `\`) => {
			//	escape character
			#b = #data->get(1)
			
			if(#b == 'u') => {
				local(bytes = bytes)
				#bytes->import8bits(#data->get(1)->asbytes->export8bits)
				#bytes->import8bits(#data->get(2)->asbytes->export8bits)
				#bytes->import8bits(#data->get(3)->asbytes->export8bits)
				#bytes->import8bits(#data->get(4)->asbytes->export8bits)
				#out->append(#bytes)
				
				#data->remove(1,5)
				
			else
				match(#b) => {
					case(`"`)
						#out->append(`"`)		
					case(`\`)
						#out->append(`\`)		
					case(`/`)
						#out->append(`/`)		
					case(`b`)
						#out->append('\b')		
					case(`f`)
						#out->append('\f')		
					case(`n`)
						#out->append('\n')		
					case(`r`)
						#out->append('\r')		
					case(`t`)
						#out->append('\t')		
					case
						#out->append('\t')		
				}
				
				#data->remove(1,1)
			}

			if(#data) => {
				#b = #data->get(1)
				#data->remove(1,1)
			else
				#b = ''
			}

		}
		
		
		#b != `"` ? #out->append(#b) 
		#b != `"` && #data->size ? currentcapture->restart()
	}()
	
	if(#out->beginswith('<LassoNativeType>') && #out->endswith('</LassoNativeType>')) => {
		protect => {
			return serialization_reader(xml(#out - '<LassoNativeType>' - '</LassoNativeType>'))->read
		}
	else(#out->size == 10 && #out >> '-' && valid_date(#out, -Format='%QT%T'))
		return date(#out,-format='%QT%T')
	}

	return #out
	
}

/* Ultra Fast */
define json_decode_flat_map(json::string) => {
	local(m=map,n,v,temp)
	with pair in #json->split(', "') do {
		#pair = #pair->split('": ')
		#n = #pair->first
		#v = #pair->last
		#n->removeleading('{') & removeleading('"')
		if(#v->beginswith('"')) => {
			#v->removetrailing('}')
			& removetrailing('"')
			& removeleading('"')
		else(#v >> '.')
			#v = decimal(#v)
		else(#v)
			#v = integer(#v)
		else
			#v = null
		}
		#m->insert(#pair->first=#v)
	}
	return #m
}

define json_consume_object(data::string)::map => {
		local(
			m=map,
			b=0,
			i=0,
			key,
			val,
			cap
		)
		
		{	#cap=currentcapture
			
			!#data ? return #m
			
			#b = #data->get(1)
			#data->remove(1,1)
			
			// Skip white space
			#b=='\t'||#b=='\r'||#b=='\n'||#b==' '||#b==','
			?  #cap->restart()
			
			if(#key) => {
				match(#b) => {
					case(`"`)	
						#m->insert(#key = json_consume_string(#data))		// "
					case(`[`)	
						#m->insert(#key = json_consume_array(#data))		// [
					case(`{`)	
						#m->insert(#key = json_consume_object(#data))		// {
					case
						#m->insert(#key = json_consume_token(#data,#b))
				}
				
				#key = null
				
			
			else(#b != '}')
	
				#key = json_consume_string(#data);

				
				if(#data) => {
					{	//	skip white space 
						#b = #data->get(1)
						#data->remove(1,1)
						
						#b=='\t'||#b=='\r'||#b=='\n'||#b==' '||#b==','
						? #data ? currentcapture->restart()
					}()
				}
				

				
				#b == ':'  ? #cap->restart()
				
			}
			
			#b != '}' ? #cap->restart()

		
		}()
		

		return #m
}

?>