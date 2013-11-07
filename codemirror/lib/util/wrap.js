CodeMirror.wrap = function(cm,char,close){
	var pos = cm.getCursor();
	cm.replaceSelection(char+close)
	cm.setSelection({line: pos.line, ch: pos.ch + 1}, {line: pos.line, ch: pos.ch + 1});	
}