include "file.iol"
include "json_utils.iol"
include "console.iol"
//intefaccia del programma
include "interfaces/json_interface.iol"

inputPort JsonName {
	Location: "local"
	Interfaces: Json
}

execution{ sequential }

main
{
   getJson(path)(json_tree){
   		//println@Console( "Sono in getJson: "+path )();
   		/* Lettura del File Json */
		request.filename = path;
		readFile@File(request)(json_content);
		//println@Console( json_content )();

		getJsonValue@JsonUtils(json_content)(json_tree)
		/* Fine lettura Json */
   }
}

