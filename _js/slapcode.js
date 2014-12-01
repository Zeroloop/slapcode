var slapcode = {
	
	setup: function(options){
		
		if(!slapcode.initialised){
			slapcode.initialised=true

			// Register Editor 
			$('form.code').not('registered').each(function(){
				slapcode.registereditor($(this))
			}) 
			
			//	Bind menu
			$('div.navbar ul.nav').children('li').each(function(){
				var p = $(this).children('a').attr('href')
				$(this).children('ul').find('a').unbind().click(function(){
					var url = $(this).attr('href')
					return url.indexOf("#") == -1 || slapcode.click(p + url) 
				})
			})

			// Bind rename project
			$('.navbar .brand').dblclick(slapcode.project_rename)

			slapcode.bindkeys(document)
			slapcode.load()			
		}
	},
	
	submit:true,
	autosuggest:true,
	autosub:0,
	
	int: false,
	tab: {},
	project: {},
	tabs: [],
	files: [],
	
	client_id: 0,
	project_id: 0,
	user_id: 0,
	
	autosubmit: function(text){
		return
		clearTimeout(slapcode.autosub)
		slapcode.autosub = setTimeout(slapcode.submit,700)
	},

	autocompile: function(){
		clearTimeout(slapcode.autocomp)
		slapcode.autocomp = setTimeout(slapcode.compile,200)
	},

	load: function(after){
		slapcode.post({task:'load'},function(r){
			slapcode.process(r)		
			slapcode.project = r.project
			slapcode.projects = r.projects
			slapcode.files = r.files
			
			if(r.project.name){
				slapcode.setprojectname(r.project.name)
			}
			
			
			slapcode.registertabs(r.tabs)
			
			if(after) after(r)
			
		
		})
	},
	
	bindkeys: function(target){
		$(target).bind('keydown.meta_return',slapcode.submit)
		$(target).bind('keydown.ctrl_r',slapcode.file_rename)
		$(target).bind('keydown.ctrl_s',slapcode.file_save)
		$(target).bind('keydown.ctrl_n',slapcode.file_new)
		$(target).bind('keydown.ctrl_t',slapcode.file_new)
		$(target).bind('keydown.ctrl_w',slapcode.file_close)	
	},

	bindeditorkeys: function(editor){
		editor.commands.bindKey("cmd-return", slapcode.submit)
		editor.commands.bindKey("ctrl-r",slapcode.file_rename)
		editor.commands.bindKey("ctrl-s",slapcode.file_save)
		editor.commands.bindKey("ctrl-n",slapcode.file_new)
		editor.commands.bindKey("ctrl-w",slapcode.file_close)	
	},


	process: function(r){
		var output=$('div.output')
		var tab = slapcode.tab
		if(r.id) tab.id = r.id
		if(r.script) eval(r.script)
		if(r.result) { 
			output.find('div.result').html(r.result)
			dr = output.find('div.result')
			dr.addClass('pulse')	
			setTimeout(function(){dr.removeClass('pulse')},100)	
		}

		if(r.debug) output.find('div.debug').replaceWith(r.debug)
		
		tab.script = r.script 
		tab.result = r.result 
		tab.debug = r.debug 	
	},
	
	submit: function(focus){
		slapcode.post({task:'run'},slapcode.process)
		return false
	},

	compile: function(after){
		slapcode.post({task:'compile'},slapcode.process)
	},

	save: function(after){
		slapcode.post({task:'save'},function(r){
			if(after){
				after(r)			
			}else{
				slapcode.process(r)
				slapcode.refreshfiles()				
			} 
		})

	},

	saveproject: function(after){
		slapcode.post({task:'saveproject',project_name:slapcode.project.name},after)
	},

	loadproject: function(project_id,after){
		//	set project id
		slapcode.project.id = project_id
		
		//	load and hope for best
		slapcode.load(after)
	},
	
	setprojectname: function(name){
		var n = name 
		n.replace(/ /g,'')
		$('div.navbar a.brand').html(n.split('').join('').toUpperCase())
	},
	

	post: function(options,after){
		var post = {}
		var t = slapcode.tab
		
		post.id = t.id
		post.name = t.name
		post.code = t.code 
		
		post.client_id 	= slapcode.client_id
		post.project_id = slapcode.project.id
		post.user_id 	= slapcode.user_id
		
		//	Include options
		for(i in options){
			post[i] = options[i]
		}
		//console.log(["post",post])
		
		$.post('/slapcode/index.lasso',post,function(r){
			//console.log(["result",r])
			if(after) after(r)
		},"json")
	},



	getprojects: function(after){
		slapcode.post({task:'projects'},function(r){
			if(after) after(r)
		})		
	},

	getfiles: function(project_id,after){
		slapcode.post({task:'files',project_id: project_id || slapcode.project.id},function(r){
			if(after) after(r)
		})		
	},

	gettabs: function(project_id,after){
		slapcode.post({task:'tabs',project_id: project_id || slapcode.project.id},function(r){
			if(after) after(r.tabs)
		})		
	},

	refreshprojects: function(){
		slapcode.getprojects(function(r){
			//	Populate files
			if(r.projects) slapcode.projects = r.projects
		})
	},
	
	refreshfiles: function(){
		slapcode.getfiles(false,function(r){
			//	Populate files
			if(r.files) slapcode.files = r.files
			
		})
	},
	
	refreshtabs: function(){
		slapcode.gettabs(false,slapcode.registertabs)
	},
	
	registertabs: function(tabs){
		slapcode.tabs = []
		$('div.tabs ul.nav li').remove()
		for(i in tabs){
			slapcode.registertab(tabs[i])	
		}
		$('div.tabs ul.nav li:first a').click()	
		if(tabs.length==0) slapcode.createtab()
	},

	registertab: function(options){
		slapcode.createtab(options,true)
	},

	createtab: function(options,dontclick){

		var tab = options || {}
		tab.index = slapcode.tabs.length,
		tab.editor = slapcode.editor
		
		if(!tab.code) tab.code = "" 
		
		slapcode.tabs.push(tab)

		var n = tab.name || 'Slap '+(slapcode.tabs.length)
		var d = $('<li><a href="#tab2" data-toggle="tab"><span>'+n+'</span> <i class="icon-remove icon-white"></i></a></li>')[0]
		
		tab.name = n
		
		$(d).find('a').click(function(){
			slapcode.switchtab(tab)
		})

		$(d).find('a').dblclick(function(){
			slapcode.file_rename(tab)
		})

		$('div.tabs ul.nav').append($(d))
		
		if(!dontclick) $('div.tabs ul.nav li:last a').click()
		
		tab.element = $(d)
		
		$(d).find('i').click(function(){
			slapcode.closetab(tab)
		})
	
	},

	switchtab: function(tab){
		slapcode.tab = tab
		slapcode.editor.setValue(tab.code)
		slapcode.hideerror()
	},

	opentab: function(id){
		if(id) slapcode.post({task:'open',id:id},function(r){
			slapcode.createtab(r.tab)
		})	
	},

	closetab: function(tab){
		var i = tab.index 
		
		if(tab.id) slapcode.post({task:'close',id:tab.id})	
		
		tab.element.remove()
		slapcode.tabs.splice(i,1)
		
		var l = slapcode.tabs.length
		
		if(l == 0){
			slapcode.createtab()
		}else if(l>i){
			slapcode.switchtab(slapcode.tabs[i])
		}else if(l > i-1){
			slapcode.switchtab(slapcode.tabs[l-1])
		}
	},



	neweditor: function(textarea){
		$('div.openfile').show()			

		var editor = ace.edit(textarea)
	    editor.setTheme("ace/theme/monokai")
		editor.getSession().setMode("ace/mode/javascript")
		editor.getSession().setOption("useWorker", false)
		slapcode.bindeditorkeys(editor)

	    editor.on('change',function(obj,evt){
	    		slapcode.tab.code = editor.getValue()
				slapcode.autocompile()
				slapcode.autosubmit()
	    })

		editor.renderer.setScrollMargin(84,0,0,0)  

		/*
		CodeMirror.fromTextArea(textarea,{
					lineNumbers: true,
					lineWrapping: true,
					matchBrackets: true,

					extraKeys: {
					//	"'": function(cm) { CodeMirror.wrap(cm,"'","'") },
						"'['": function(cm) { CodeMirror.wrap(cm,'[',']') },
						"'('": function(cm) { CodeMirror.wrap(cm,'(',')') },
						"'{'": function(cm) { CodeMirror.wrap(cm,'{','}') }
					},

					onChange: function(){
						slapcode.tab.code = cm.getValue()
						slapcode.autocompile()
						slapcode.autosubmit()
					},
				  	onGutterClick: function(cm, n) {
						var info = cm.lineInfo(n);
						
						if (info.markerText){
						  	cm.clearMarker(n);
							// Remove break
							var i = cm.breaks.indexOf(n)
							if(i!=-1) cm.breaks.splice(i,1)							
						} else {
							cm.breaks.push(n)
						  	cm.setMarker(n, "<span style=\"color: #900\">●</span> %N%");
						}
					}
				})

		cm.breaks = []
		*/

				
		return editor
			
	},
	
	registereditor: function(element){
		if(!element.hasClass('registered')){
			$(element).addClass('registered')	
			
			slapcode.host = element
			slapcode.editor = slapcode.neweditor(element.find('.editor')[0])

	
			element.find('button:contains("Run")').unbind().click(function(){
				slapcode.submit(false)
				return false
			})

			slapcode.editor.focus()

			element.submit(slapcode.submit)
		}
	},
	
	showerror: function(line,char,msg,focus){
		
		var t=slapcode.tab
		var h=slapcode.host
		var e=t.editor
		
		p={line:line-1, ch:char-1};
		
		// Add / show floating error
		var pos = e.renderer.textToScreenCoordinates(p.line,p.ch)
		h.find('div.feedback').html(msg).css('left',pos.pageX + 'px').css('top',pos.pageY + 'px').show()

		e.getSession().setAnnotations([{
		  row:    p.line,
		  column: p.ch,
		  text:   msg,
		  type:   "error" // also warning and information
		}]);


		//e.setLineClass(4-1,'test1','test2')
	},

	hideerror: function(){
		slapcode.tab.editor.getSession().setAnnotations([])
		slapcode.host.find('div.feedback').hide()
	},

	click: function(key,e){
		var key = key.replace('#','').replace('#','_')
		var param = undefined
		
		if(key.indexOf('#')!='-1'){
			param = key.split('#')[1]
			key = key.split('#')[0]
		}
		
		if(slapcode[key]){
			slapcode[key](param)
		}

		if(e) e.preventDefault()
		
		return false	
	},

	prompt_with_input: function(title,value,placeholder,after){
		var dom = $('<p><input type="text" name="value" placeholder="Name"/></p>')
		var inp = dom.find('input')

		inp.attr('value',value).attr('placeholder',placeholder).unbind().bind('keyup.return',function(){
			if(after) after(inp.attr('value'))
			slapcode.closeprompt()
		})
		
		slapcode.prompt(title,after,dom)
	},

	prompt: function(title,after,dom){
		var m = $('div.modal')
				
		m.find('div.modal-body').html(dom)
		
		var inp = m.find('input')
		
		if(inp.length > 0){
			m.find('button:contains("Save")').show().unbind().click(function(){
				if(after) after(inp.attr('value'))
				m.modal('hide')
			})
		}else{
			m.find('button:contains("Save")').hide()
		}
		
		m.find('h3').html(title)
		m.find('button:contains("Cancel")').unbind().click(function(){
			m.modal('hide')
		})
		m.modal('show')
		inp.focus()
	},

	closeprompt:  function() {
		$('div.modal').modal('hide')
	},

	
	openprompt: function(showfiles){
		
		var dom = $('<div class="openprompt well"><ul class="nav nav-list"></ul></div>')
		var ul = dom.find('ul.nav')
	
		dom.show()

		// Rebuild menu
		ul.children().remove()
		ul.append('<li class="nav-header">Projects</li>')		
		
		for(i in slapcode.projects){
			var p=slapcode.projects[i]
			
			if(showfiles){
				ul.append(
					'<li><a href="#project#showfiles#'+p.id+'">'+p.name+'</a></li>'
				)			
			
			}else{
				ul.append(
					'<li><a href="#project#openthis#'+p.id+'">'+p.name+'</a></li>'
				)	

			}
			
		} 
		
		if(showfiles){
			ul.append('<li class="nav-header">Files</li>')		

			for(i in slapcode.files){
				var f=slapcode.files[i]
				ul.append(
					'<li><a href="#file#openthis#'+f.id+'">'+f.name+'</a></li>'
				)			
			} 
		}
		
		dom.find('a').unbind().click(function(){
			slapcode.click($(this).attr('href'))
			if($(this).attr('href').indexOf('showfiles')== -1) slapcode.closeprompt()
			return false			
		})
		
		slapcode.prompt('Open ',false,dom)
		
	},
	
	project_open: function(){
		slapcode.openprompt()
	},
	
	project_openthis: function(project_id){
		slapcode.loadproject(project_id)
	},

	project_showfiles: function(project_id){
		slapcode.loadproject(project_id,function(){
			slapcode.openprompt(true)		
		})
	},

	project_new: function(){		
		var n = 'Project '+(slapcode.projects.length + 1)
		var p = slapcode.project 
					
		slapcode.prompt_with_input('New project...',n,n,function(newname){
			p.name = newname
			slapcode.project.id = 0
			slapcode.saveproject(function(r){
				slapcode.project = r.project
				slapcode.load()
			})
		})
	},

	project_rename: function(){
		var p = slapcode.project 	
		var n = p.name				
		if(!p.id) return
		slapcode.prompt_with_input('Rename project...',n,n,function(newname){
			p.name = newname
			slapcode.saveproject(function(r){
				slapcode.project = r.project
				slapcode.setprojectname(newname)
				slapcode.refreshprojects()				
			})
		})
	},
	
	project_close: function(){
		slapcode.project = {}
		slapcode.load()
	},
	
	file_open: function(){
		slapcode.openprompt(true)
	},
	
	file_openthis: function(id){
		slapcode.opentab(id)
	},
	
	file_saveas: function(){
		var t = slapcode.tab 		
		slapcode.prompt_with_input('Save as...',t.name,t.name,function(newname){
			t.id=0
			t.name=newname
			t.element.find('a span').html(newname)
			
			slapcode.save()
		})
	},

	file_rename: function(){
		var t = slapcode.tab 		
		slapcode.prompt_with_input('Rename to...',t.name,t.name,function(newname){
			t.name=newname
			t.element.find('a span').html(newname)			
			slapcode.save()
		})
	},
	
	file_save: function(){
		var t = slapcode.tab 
		
		if(!t.id){
			slapcode.file_saveas()
		} else {
			slapcode.save()
		}
	},
	
	file_new: function(){
		slapcode.createtab()
	},

	file_close: function(){
		slapcode.closetab(slapcode.tab)
	}

}

$(document).ready(slapcode.setup)

