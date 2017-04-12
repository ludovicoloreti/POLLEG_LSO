include "file.iol"
include "json_utils.iol"
include "../interfaces/json_interface.iol"
include "console.iol"


inputPort JsonName {
	Location: "local"
	Interfaces: Json
}

execution{ sequential }

main
{
   getJson(path)(json_tree){

   		exists@File(path)(responseExist);
   		isDirectory@File(path)(responsePath); //responsePath deve essere false

   		if(responseExist && !responsePath){
   			/* Lettura del File Json */
			request.filename = path;
			readFile@File(request)(json_content);
			//println@Console( json_content )();

			getJsonValue@JsonUtils(json_content)(json_tree)
			/* Fine lettura Json */
   		}else{
   			println@Console( "> Percorso Json " + path + " non valido" )();
   			json_tree = false
   		}
   }
}